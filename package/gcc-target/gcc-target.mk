################################################################################
#
# gcc-target
#
# A native gcc that runs ON the target: a Canadian cross of the same gcc
# sources used by the internal toolchain (build = host machine, host =
# target = $(GNU_TARGET_NAME)).  Buildroot dropped built-in on-target
# toolchain support long ago, so this is a self-contained target package.
#
################################################################################

# Track the toolchain's gcc version/source (dl/ already has the tarball).
GCC_TARGET_VERSION = $(call qstrip,$(BR2_GCC_VERSION))
GCC_TARGET_SITE = https://ftpmirror.gnu.org/gcc/gcc-$(GCC_TARGET_VERSION)
GCC_TARGET_SOURCE = gcc-$(GCC_TARGET_VERSION).tar.xz
GCC_TARGET_DL_SUBDIR = gcc
GCC_TARGET_LICENSE = GPL-3.0-with-GCC-exception
GCC_TARGET_LICENSE_FILES = COPYING.RUNTIME COPYING3

# as/ld (binutils-target) at runtime; gmp/mpfr/mpc (target) to link cc1;
# host-gcc-final is the cross compiler that builds these riscv binaries.
GCC_TARGET_DEPENDENCIES = host-gcc-final binutils gmp mpfr mpc

# gcc does not support in-tree builds.
GCC_TARGET_SUBDIR = build

# Native compiler: runtime sysroot is "/" (the target rootfs), but the libc
# headers/objects needed to build libgcc/libstdc++ live in $(STAGING_DIR),
# so point build-sysroot there.  arch/abi mirror host-gcc-final for this
# riscv64 config.
GCC_TARGET_CONF_OPTS = \
	--disable-multilib \
	--disable-bootstrap \
	--enable-languages=c,c++ \
	--with-sysroot=/ \
	--with-build-sysroot=$(STAGING_DIR) \
	--with-native-system-header-dir=/usr/include \
	--with-arch=rv64imafdc_zicsr_zifencei \
	--with-abi=lp64d \
	--with-gmp=$(STAGING_DIR)/usr \
	--with-mpfr=$(STAGING_DIR)/usr \
	--with-mpc=$(STAGING_DIR)/usr \
	--enable-__cxa_atexit \
	--with-gnu-ld \
	--enable-shared \
	--disable-libssp \
	--disable-libmpx \
	--disable-libsanitizer \
	--disable-decimal-float \
	--enable-threads \
	--enable-tls \
	--enable-lto \
	--without-isl \
	--without-cloog \
	--without-zstd \
	--with-pkgversion="Buildroot native $(BR2_VERSION_FULL)" \
	--disable-nls

# gcc's makeinfo check enables docs otherwise; force it off.
GCC_TARGET_CONF_ENV = MAKEINFO=missing

define GCC_TARGET_CONFIGURE_CMDS
	mkdir -p $(@D)/$(GCC_TARGET_SUBDIR)
	(cd $(@D)/$(GCC_TARGET_SUBDIR) && rm -rf config.cache; \
		$(TARGET_CONFIGURE_OPTS) \
		$(GCC_TARGET_CONF_ENV) \
		../configure \
		--prefix=/usr \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		$(GCC_TARGET_CONF_OPTS) \
	)
endef

define GCC_TARGET_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/$(GCC_TARGET_SUBDIR) \
		all-gcc all-target-libgcc all-target-libstdc++-v3
endef

define GCC_TARGET_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/$(GCC_TARGET_SUBDIR) DESTDIR=$(TARGET_DIR) \
		install-gcc install-target-libgcc install-target-libstdc++-v3
	# gcc installs the driver as $(target)-gcc; add the plain names.
	ln -sf $(GNU_TARGET_NAME)-gcc $(TARGET_DIR)/usr/bin/gcc
	ln -sf $(GNU_TARGET_NAME)-gcc $(TARGET_DIR)/usr/bin/cc
	ln -sf $(GNU_TARGET_NAME)-g++ $(TARGET_DIR)/usr/bin/g++
endef

$(eval $(generic-package))
