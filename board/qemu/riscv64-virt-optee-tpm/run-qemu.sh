#!/bin/bash
# Boot the qemu_riscv64_virt_optee_tpm build: starts swtpm (TPM 2.0 emulator)
# and QEMU with the OP-TEE domain DTB and a tpm-tis-device wired to it.
#
# Modelled on keystone's `make run` (mkutils/plat/generic/run.mk), but with its own swtpm at
# /tmp/emulated_tpm_optee/swtpm-sock (keystone uses /tmp/emulated_tpm), ssh on localhost:${SSH_PORT}.
#
# Usage: run-qemu.sh [--tcp-serial] [--debug] [-- extra qemu args]
#   default       Linux console on this terminal (-serial mon:stdio),
#                 OP-TEE core log (semihosting) also on this terminal.
#   --tcp-serial  RISE-style: Linux console on tcp:127.0.0.1:64320 (server),
#                 connect with "nc 127.0.0.1 64320".
#   --debug       start halted with a gdb stub on tcp::4680
set -e

BOARD_DIR="$(cd "$(dirname "$0")" && pwd)"
BR_DIR="${BR_DIR:-$(cd "${BOARD_DIR}/../../.." && pwd)}"
IMAGES="${IMAGES:-${BR_DIR}/output/images}"
QEMU="${QEMU:-${BR_DIR}/output/host/bin/qemu-system-riscv64}"
[ -x "${QEMU}" ] || QEMU=qemu-system-riscv64

TPM_DIR="${TPM_DIR:-/tmp/emulated_tpm_optee}"
TPM_SOCK="${TPM_DIR}/swtpm-sock"
SSH_PORT="${SSH_PORT:-2200}"
QEMU_MEM="${QEMU_MEM:-4096}"   # must match memory@80000000 in qemu_rv64_virt_domain.dts
QEMU_SMP="${QEMU_SMP:-2}"      # must match CFG_TEE_CORE_NB_CORE / cpus in the DTS

serial_args="-serial mon:stdio"
extra=()
while [ $# -gt 0 ]; do
    case "$1" in
    --tcp-serial) serial_args="-serial tcp:127.0.0.1:64320,server"; shift ;;
    --debug)      extra+=(-S -gdb tcp::4680); shift ;;
    --)           shift; extra+=("$@"); break ;;
    *)            extra+=("$1"); shift ;;
    esac
done

# swtpm: reuse a running instance, otherwise start one for this session.
mkdir -p "${TPM_DIR}"
if ! [ -S "${TPM_SOCK}" ] || ! pgrep -f "swtpm socket.*${TPM_SOCK}" >/dev/null; then
    rm -f "${TPM_SOCK}"
    swtpm socket --tpmstate dir="${TPM_DIR}" \
        --ctrl type=unixio,path="${TPM_SOCK}" \
        --tpm2 --log level=20,file="${TPM_DIR}/swtpm.log" &
    SWTPM_PID=$!
    trap 'kill ${SWTPM_PID} 2>/dev/null' EXIT
    for _ in $(seq 50); do [ -S "${TPM_SOCK}" ] && break; sleep 0.1; done
fi

cd "${IMAGES}"
exec "${QEMU}" -M virt -cpu rv64,zkr=on -m "${QEMU_MEM}" -smp "${QEMU_SMP}" -nographic \
    -dtb qemu_rv64_virt_domain.dtb \
    -semihosting-config enable=on,target=native \
    ${serial_args} \
    -bios u-boot-spl \
    -device loader,file=u-boot.itb,addr=0x80200000 \
    -drive format=raw,file=sdcard.img,id=hd0,if=none \
    -device virtio-blk-device,drive=hd0 \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -chardev socket,id=chrtpm,path="${TPM_SOCK}" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis-device,tpmdev=tpm0 \
    "${extra[@]}"
