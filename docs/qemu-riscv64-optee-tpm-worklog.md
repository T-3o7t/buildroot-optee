# QEMU riscv64 + OP-TEE + swtpm 環境 作業記録

- ブランチ: `qemu-optee-tpm-gcc`（ベース: `dev-optee-mpxy-v8`）
- リポジトリ: `git@github.com:T-3o7t/buildroot-optee.git`
- 期間: 2026-09-17 〜 2026-09-24
- ホスト: Ubuntu 24.04 (WSL2), 16 コア / RAM 約 7 GB, ホスト側 qemu 8.2 / swtpm 0.7.3

## 1. 目的

WSL 上に QEMU (riscv64) + swtpm (TPM 2.0) + OP-TEE の環境を作る。
Buildroot の設定は `~/github/keystone` の
`overlays/keystone/configs/riscv64_generic_defconfig` と
`board/qemu/generic/{uboot-tpm.config,extlinux.conf}` に合わせ、
そのままでは動かない部分を調整する。

ベースは既存の `qemu_riscv64_virt_optee_defconfig`
（RISE riscv-optee BSP: Linux 6.19 / OpenSBI / U-Boot SPL / OP-TEE）。

## 2. コミット一覧

| コミット | 内容 |
|---|---|
| `0e79bda942` | `configs: add qemu_riscv64_virt_optee_tpm (swtpm TPM 2.0 + native gcc)` |
| `d3c621396e` | `package/optee-selftest: add custom TA + host self-test app` |
| `47cf5bb055` | `docs: add qemu_riscv64_virt_optee_tpm work log; fix run-qemu.sh notes` |
| （今回） | OpenSBI: ドメイン切り替えで FPU レジスタを保存・復元（xtest 1006 修正、4.7 参照） |

### 追加・変更したファイル

```
configs/qemu_riscv64_virt_optee_tpm_defconfig
board/qemu/riscv64-virt-optee-tpm/
├── genimage_sdcard.cfg
├── linux-tpm.config            # TCG_TIS, IMA(sha256) などのカーネル設定
├── uboot-tpm.config            # U-Boot TPM / measured boot
├── patches/linux/0001-riscv-dts-qemu-virt-domain-add-TPM-TIS-on-platform-bus.patch
├── patches/uboot/0001-cmd-booti-let-measured-boot-actually-hash-the-kernel.patch
├── patches/opensbi/0001-lib-sbi-domain-context-save-and-restore-FP-registers.patch
├── post-build.sh               # man / 開発用ファイルの復元
├── rootfs_overlay/boot/extlinux/extlinux.conf
├── rootfs_overlay/etc/fstab
├── run-qemu.sh                 # swtpm + QEMU 起動
└── readme.txt
package/gcc-target/             # オンターゲット gcc/g++（新規）
package/mandoc/                 # man/apropos/whatis（新規、host 版あり）
package/man-pages/              # Linux man-pages（新規）
package/optee-selftest/         # 自作 TA + ホストアプリ（新規）
package/Config.in, package/Config.in.host
```

## 3. ビルドと起動

```sh
# WSL の PATH には空白入りの Windows パスが混ざり Buildroot が拒否するので先に整理
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

make qemu_riscv64_virt_optee_tpm_defconfig
make -j12
```

起動（swtpm と QEMU をまとめて起動）:

```sh
board/qemu/riscv64-virt-optee-tpm/run-qemu.sh               # コンソールはこの端末
board/qemu/riscv64-virt-optee-tpm/run-qemu.sh --tcp-serial  # RISE 方式
board/qemu/riscv64-virt-optee-tpm/run-qemu.sh --debug       # gdb スタブ tcp::4680 で停止状態から
```

- デフォルト: Linux コンソール（`-serial mon:stdio`）と OP-TEE のログ（semihosting）が同じ端末に出る
- `--tcp-serial`: Linux コンソールは別ターミナルで `nc 127.0.0.1 64320`
- 環境変数 `SSH_PORT` / `QEMU_MEM` / `QEMU_SMP` / `TPM_DIR` で変更可能
  （MEM と SMP は DTS / `CFG_TEE_CORE_NB_CORE` と一致させること）
- ログイン: `root` / `sifive`
- ssh: `ssh -p 2200 root@localhost`（udhcpc で約 10 秒かかるので少し待つ）
- swtpm の状態は `/tmp/emulated_tpm_optee`

## 4. 追加した機能

### 4.1 TPM 2.0 (swtpm)

- QEMU 8.x 以降の本家は riscv virt の platform bus (0x4000000) で
  `-device tpm-tis-device` をサポートしているので、keystone の
  qemu 7.2.1 用 TPM パッチは不要。
- ただし `-dtb` で DTB を渡すと QEMU は TPM ノードを追加しない。
  そのため OP-TEE ドメインの DTS に tpm_tis ノードを追加するパッチを
  `patches/linux/` に置いた。
- カーネル: `TCG_TIS` + IMA (sha256, `ima_policy=tcb`, PCR10)
- ユーザランド: tpm2-tss / tpm2-tools

### 4.2 U-Boot measured boot の PCR8 バグ修正（重要）

**症状**: extlinux → `booti` でブートすると、カーネルがハッシュされない。
`booti` が `os.image_start` / `os.image_len` を 0 のままにするので、
`bootm_measure()` はイベント文字列 `"linux\0"` しかハッシュしない。
結果 PCR8 はカーネルの内容に関係なく常に同じ値になる:

```
PCR8 = extend(sha256("linux\0")) = BE624459...
```

**keystone の U-Boot 2024.01 も同じ問題がある。** keystone で measured boot
を扱うときは、同じ booti パッチを当てないと PCR8 は意味を持たない。

**修正**:
- `patches/uboot/0001-cmd-booti-let-measured-boot-actually-hash-the-kernel.patch`
- `CONFIG_PREBOOT="setenv kernel_addr_r 0x86000000"`
  （ファイル末尾より後ろの領域がゼロである必要があるため再配置）

PCR の割り当て: PCR8 ← カーネル、PCR9 ← initrd（なしの場合 `"initrd\0"` のハッシュ）、
PCR1 ← bootargs、PCR0 ← セパレータ。

正しい PCR8 は Image をヘッダの `image_size` までゼロ埋めした SHA-256 を extend した値。
ホストで計算して確認できる:

```sh
python3 - <<'PY'
import hashlib, struct
img = open("output/images/Image", "rb").read()
_, image_size = struct.unpack_from("<QQ", img, 8)      # riscv Image header
h = hashlib.sha256(img + b"\0" * (image_size - len(img))).digest()
print(hashlib.sha256(b"\0" * 32 + h).hexdigest().upper())   # == pcr-sha256/8
PY
```

### 4.3 scp / sftp

Dropbear に SFTP サブシステムがなく、ホストの OpenSSH scp は `-O`（旧 rcp
プロトコル）を付けないと失敗していた。`BR2_PACKAGE_GESFTPSERVER` を追加し
（`/usr/libexec/sftp-server` にシンボリックリンク）、普通の scp / sftp が使えるようにした。

```sh
scp -P 2200 file root@localhost:/root/
sftp -P 2200 root@localhost
```

### 4.4 make / file / man

- `BR2_PACKAGE_MAKE`, `BR2_PACKAGE_FILE`
- `BR2_PACKAGE_MANDOC`（man / apropos / whatis, groff 不要）と
  `BR2_PACKAGE_MAN_PAGES` を新規パッケージとして追加
- mandoc の configure は機能テストを実行するためクロスコンパイルで壊れる
  → `mandoc.mk` で `configure.local` を事前に用意
- Buildroot は target-finalize で `/usr/share/man` を削除する
  → `post-build.sh` が `output/per-package/*/target` から復元し、
  host-mandoc の `makewhatis` で apropos 用の `mandoc.db` を作る

### 4.5 オンターゲット gcc / g++

Buildroot にはターゲット上で動くツールチェーンがないため、
`package/gcc-target` を新規作成。

- 内部ツールチェーンの gcc 13.3.0 を Canadian cross
  （build = x86_64, host = target = riscv64）
- `BINUTILS` + `BINUTILS_TARGET`（as/ld）と target の GMP / MPFR / MPC を select
- 主な configure: `--with-sysroot=/ --with-build-sysroot=$(STAGING_DIR)`
- ビルド対象: `all-gcc all-target-libgcc all-target-libstdc++-v3`
- target-finalize は post-build より前に `/usr/include` と全 `*.a` を消すので、
  `post-build.sh` で libc ヘッダと crt オブジェクト（staging から）、
  gcc の C++ ヘッダ・`libgcc.a`・`libstdc++.a`
  （`output/per-package/gcc-target/target` から）を復元
- gcc が約 200 MB あるので ext2 を 512M → **1500M** に拡大
- C / C++、動的 / 静的リンクすべてゲスト上で動作確認済み
- RAM 7 GB・`-j12` で OOM なし

### 4.6 OP-TEE セルフテスト TA (`package/optee-selftest`)

自作の Trusted Application と、それを呼ぶ normal world のクライアント。

- ソースはパッケージ内に同梱（`SITE_METHOD=local`, `package/optee-selftest/src/`）
- ビルド方法は optee-examples と同じ
  （`TA_DEV_KIT_DIR=$(STAGING_DIR)/lib/optee/export-ta_rv64`, ホスト側は libteec にリンク）
- TA UUID: `5d6f971b-8fc2-4695-b3b9-1c58670463af`
- インストール先: `/lib/optee_armtz/<uuid>.ta`, `/usr/bin/optee_selftest`

| コマンド | 内容 |
|---|---|
| INC / SUM | value パラメータの入出力 |
| SHA256 | memref パラメータ、GlobalPlatform crypto API で TEE 内ハッシュ（FIPS 180-4 "abc" ベクタと照合） |
| RANDOM | セキュアワールドの TRNG (`TEE_GenerateRandom`)、非ゼロかつ毎回異なることを確認 |

`optee_selftest` は各項目を `[PASS]` / `[FAIL]` で表示し、失敗があれば非ゼロで終了する。
ゲスト上で 4 項目すべて PASS を確認済み。

### 4.7 xtest regression_1006 の間欠的な失敗（OpenSBI の FPU レジスタ未保存）

**症状**: フル `xtest` を実行すると、ときどき 1 件だけ失敗する（あるゲストでは 3 回中 1 回程度）。

```
regression_1000.c:641: TEEC_InvokeCommand(&session, 5, &op, &ret_orig)
  → 0xffff0000 = TEEC_ERROR_GENERIC
112 test cases of which 1 failed
```

失敗したときの OP-TEE ログ（semihosting、QEMU の標準出力）:

```
E/TA:  test_float:698 Expression my_dcmpeq(test_float_f2d(VAL1), VAL1, FPREC) failed
```

**原因**: TA の浮動小数点レジスタが Linux 側に書き換えられていた。

- TA はハードウェア浮動小数点でビルドされる（`-march=rv64imafdc -mabi=lp64d`、`CFG_TA_FLOAT_SUPPORT=y`）
- optee_os の RISC-V ポートは FPU コンテキストを保存しない（`CFG_WITH_VFP` は
  `static_assert(!IS_ENABLED(CFG_WITH_VFP))` で未対応）
- Linux ⇔ OP-TEE のドメイン切り替えをする OpenSBI の
  `switch_to_next_domain_context()`（`lib/sbi/sbi_domain_context.c`）は、GPR と S-mode の CSR は
  入れ替えるが、**f0–f31 / fcsr は入れ替えない**
- そのため TA の実行中に割り込みで Linux に戻り、Linux で浮動小数点演算が走ると、TA の値が壊れる
  （逆方向の、Linux のユーザプロセスの FP 値が壊れることも起こりうる）

OP-TEE のログを遅い端末に出していると TA の実行時間が延び、割り込みが入りやすくなるので再現しやすい。
ログをファイルに出す場合は、Linux 側で FP 負荷（`awk` のループなど）をかけると再現した（15 回中 1 回）。

**修正**: `patches/opensbi/0001-lib-sbi-domain-context-save-and-restore-FP-registers.patch`。
ドメイン切り替えのたびに、現在のドメインの f0–f31 / fcsr を `hart_context` に保存し、切り替え先の値を読み込む。
修正後は FP 負荷下で 40 回中 0 回の失敗、フル xtest も通過。

再現・確認手順（ゲスト上）:

```sh
for c in 1 2; do (while :; do awk "BEGIN{x=0;for(i=0;i<3e6;i++)x+=i*1.5}"; done) & done
f=0; for i in $(seq 40); do xtest regression_1006 >/dev/null 2>&1 || f=$((f+1)); done; echo fail=$f/40
kill $(jobs -p); killall awk
```

## 5. ゲスト上での確認コマンド

```sh
# TPM
ls /dev/tpm0 /dev/tpmrm0
tpm2_pcrread sha256
cat /sys/kernel/security/ima/ascii_runtime_measurements

# OP-TEE
xtest
optee_selftest

# ツール
man 2 open ; apropos socket ; make --version

# ネイティブコンパイラ
echo 'int main(){return 0;}' > /tmp/t.c && gcc -O2 -o /tmp/t /tmp/t.c && /tmp/t
g++ --version
gcc -static hello.c -o hello
```

## 6. ハマりどころ・知見

### Buildroot 設定
- RISE カーネル 6.19 は Buildroot が知っている最新ヘッダ系列 (6.14) より新しい。
  `BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_14` を指定する必要がある
  （"latest" 以外は >= の緩いチェックにならない）。
- `post-build.sh` は **dash** で実行される。`read -d` などの bash 拡張は使えない
  （`cp --parents` や `find -exec` で代用）。

### OP-TEE / xtest
- `xtest` の失敗理由は、ゲストの xtest 出力ではなく **OP-TEE のログ**（`E/TA:` 行）に出る。
  `run-qemu.sh` のデフォルトでは Linux コンソールと同じ端末に混ざって表示される。
- os_test TA の `test_mem_access_right` などには、`EMSG` を出さずに `TEE_ERROR_GENERIC`
  を返す経路があるので、ログに理由が出ないこともある。
- 間欠的な失敗の調査には、`-serial file:...` で OP-TEE ログをファイルに出す 2台目の QEMU
  （ディスクイメージのコピー、別の ssh ポート・swtpm ディレクトリ）を起動すると、
  使用中の環境を止めずに調べられる。
- `make` を実行すると `output/images/sdcard.img` が再生成される。
  そのイメージで起動中の QEMU があるなら、先に止めること。

### WSL 環境
- `make` の前に必ず PATH を整理する（3章参照）。
- `pkill -f "<pattern>"` は禁止。Claude Code の Bash ツール自身のシェルも
  マッチして殺してしまう。`pkill -x make` / `pkill -x swtpm` /
  `pkill -x qemu-system-ris` か PID 指定で止める。
- `make -jN` が失敗したら `pgrep -xc make` が 0 になるまで待ってから再実行する。
  同じツリーで make が 2 つ走り host-libunistring が壊れたことがある。
- 途中で libc を変えた（uclibc → glibc）ら、`host-pkgconf` のラッパーにタプルが
  埋め込まれたまま残る（`BR2_PER_PACKAGE_DIRECTORIES` で各 per-package にハードリンク）。
  host-pkgconf と全 target パッケージを dirclean する。

### Git / GitHub
- `.github/workflows/` を含む履歴を push するには OAuth トークンに `workflow` スコープが必要。
  origin を SSH に切り替えて解決。

## 7. 参考

- 詳しい起動方法・QEMU コマンドライン: `board/qemu/riscv64-virt-optee-tpm/readme.txt`
- 各コミットの詳細: `git show 0e79bda942`, `git show d3c621396e`
