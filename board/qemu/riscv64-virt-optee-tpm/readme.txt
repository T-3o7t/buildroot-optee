QEMU riscv64 virt + OP-TEE (RISE riscv-optee BSP) + swtpm TPM 2.0

Start a TPM 2.0 emulator first (the guest's tpm-tis-device is backed by it):

  mkdir -p /tmp/emulated_tpm_optee
  swtpm socket --tpmstate dir=/tmp/emulated_tpm_optee \
      --ctrl type=unixio,path=/tmp/emulated_tpm_optee/swtpm-sock --tpm2 --log level=20 &

Then run Linux in emulation with (or use board/qemu/riscv64-virt-optee-tpm/run-qemu.sh,
which does both; see below):

  qemu-system-riscv64 -M virt -cpu rv64,zkr=on -dtb qemu_rv64_virt_domain.dtb -m 4096 -smp 2 -semihosting-config enable=on,target=native -serial tcp:127.0.0.1:64320,server -bios u-boot-spl -device loader,file=u-boot.itb,addr=0x80200000 -device virtio-blk-device,drive=hd0 -drive format=raw,file=sdcard.img,id=hd0,if=none -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2200-:22 -chardev socket,id=chrtpm,path=/tmp/emulated_tpm_optee/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis-device,tpmdev=tpm0 -nographic # qemu_riscv64_virt_optee_tpm_defconfig

With the command above, OP-TEE core log goes to QEMU's stdout via semihosting and
the Linux console is on TCP port 64320 (connect with e.g. "nc 127.0.0.1 64320"
from another terminal).  output/images/start-qemu.sh is generated from it.

run-qemu.sh (run from anywhere; it cds into output/images and reuses or starts swtpm):
  run-qemu.sh               Linux console and OP-TEE log both on this terminal
                            (-serial mon:stdio)
  run-qemu.sh --tcp-serial  Linux console on tcp:127.0.0.1:64320, as above
  run-qemu.sh --debug       start halted with a gdb stub on tcp::4680
  Env overrides: SSH_PORT (2200), QEMU_MEM (4096), QEMU_SMP (2), TPM_DIR,
  IMAGES, QEMU.  QEMU_MEM/QEMU_SMP must match the DTS / CFG_TEE_CORE_NB_CORE.

Login: root / sifive. ssh: ssh -p 2200 root@localhost

Copying files in/out (scp/sftp):
  This build ships gesftpserver as /usr/libexec/sftp-server (BR2_PACKAGE_GESFTPSERVER),
  which Dropbear runs as its SFTP subsystem.  Modern OpenSSH scp uses the SFTP
  protocol by default, so from the WSL host a plain
      scp -P 2200 file root@localhost:/root/
  works without the legacy "-O" flag (which forces the old rcp protocol).
  sftp -P 2200 root@localhost also works.

Extra userspace tools:
  make (BR2_PACKAGE_MAKE), file (BR2_PACKAGE_FILE), and a full man/apropos/whatis
  via mandoc (BR2_PACKAGE_MANDOC) + Linux man-pages (BR2_PACKAGE_MAN_PAGES).
  Buildroot deletes /usr/share/man at target-finalize, so post-build.sh restores
  it from output/per-package/*/target and host-mandoc's makewhatis builds the
  apropos index (mandoc.db).  Try: man 2 open ; apropos socket ; make --version.

On-target native compiler (BR2_PACKAGE_GCC_TARGET):
  A native gcc/g++ 13.3.0 (Canadian cross of the toolchain's own gcc) runs on
  the guest, so you can compile C and C++ on the device.  It pulls in binutils
  (as/ld) on the target and target gmp/mpfr/mpc.  Because target-finalize wipes
  /usr/include and every *.a, post-build.sh restores the libc headers + startup
  objects (crt*.o) from staging and gcc's own dev files (C++ headers, libgcc.a,
  libstdc++.a) from output/per-package/gcc-target/target.  This is why the ext2
  size is 1500M.  Verify:
      echo 'int main(){return 0;}' > /tmp/t.c && gcc -O2 -o /tmp/t /tmp/t.c && /tmp/t
      g++ --version ; gcc -static hello.c -o hello   # static links work too

TPM check in the guest:
  ls /dev/tpm0 /dev/tpmrm0
  tpm2_pcrread sha256
  cat /sys/kernel/security/ima/ascii_runtime_measurements   # IMA (ima_policy=tcb), PCR10

U-Boot measured boot (uboot-tpm.config + patches/uboot/): PCR8 <- kernel,
PCR9 <- initrd (none: hash of "initrd\0"), PCR1 <- bootargs, PCR0 <- separators.
PCR8 is reproducible from output/images/Image; check it on the host with:

  python3 - <<'PY'
  import hashlib, struct
  img = open("output/images/Image", "rb").read()
  _, image_size = struct.unpack_from("<QQ", img, 8)      # riscv Image header
  h = hashlib.sha256(img + b"\0" * (image_size - len(img))).digest()
  print(hashlib.sha256(b"\0" * 32 + h).hexdigest().upper())   # == pcr-sha256/8
  PY

Note: without patches/uboot/0001-cmd-booti-*.patch (i.e. stock U-Boot, also
keystone's 2024.01) PCR8 is a constant BE624459... = extend(sha256("linux\0"))
because booti never tells bootm_measure() where the kernel is.

Debug:

  $ qemu-system-riscv ... -S -gdb tcp::4680

  Another terminal:

  $ ${CROSS_COMPILE}gdb -ex "target remote 127.0.0.1:4680"
