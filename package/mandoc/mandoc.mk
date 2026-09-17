################################################################################
#
# mandoc
#
################################################################################

MANDOC_VERSION = 1.14.6
MANDOC_SITE = https://mandoc.bsd.lv/snapshots
MANDOC_LICENSE = ISC
MANDOC_LICENSE_FILES = LICENSE
MANDOC_CPE_ID_VENDOR = mandoc
MANDOC_DEPENDENCIES = zlib

# mandoc's hand-written configure probes features by compiling *and running*
# test programs, which cannot work when cross-compiling: every probe would be
# reported as missing and the compat_*.c fallbacks used instead.  Pre-seed the
# answers for a glibc/uclibc/musl Linux target in configure.local (values
# taken from a native glibc run, minus host-only things such as less -T).
define MANDOC_CONFIGURE_CMDS
	( \
		echo 'CC="$(TARGET_CC)"'; \
		echo 'CFLAGS="$(TARGET_CFLAGS) -D_GNU_SOURCE"'; \
		echo 'LDFLAGS="$(TARGET_LDFLAGS)"'; \
		echo 'PREFIX="/usr"'; \
		echo 'MANDIR="/usr/share/man"'; \
		echo 'MANPATH_DEFAULT="/usr/share/man:/usr/local/share/man"'; \
		echo 'UTF8_LOCALE="C.UTF-8"'; \
		echo 'BINM_PAGER="less"'; \
		echo 'HAVE_LESS_T=0'; \
		echo 'HAVE_ATTRIBUTE=1'; \
		echo 'HAVE_CMSG=1'; \
		echo 'HAVE_DIRENT_NAMLEN=0'; \
		echo 'HAVE_EFTYPE=0'; \
		echo 'HAVE_ENDIAN=1'; \
		echo 'HAVE_ERR=1'; \
		echo 'HAVE_FTS=1'; \
		echo 'HAVE_FTS_COMPARE_CONST=0'; \
		echo 'HAVE_GETLINE=1'; \
		echo 'HAVE_GETSUBOPT=1'; \
		echo 'HAVE_ISBLANK=1'; \
		echo 'HAVE_MKDTEMP=1'; \
		echo 'HAVE_MKSTEMPS=1'; \
		echo 'HAVE_NANOSLEEP=1'; \
		echo 'HAVE_NTOHL=1'; \
		echo 'HAVE_O_DIRECTORY=1'; \
		echo 'HAVE_OHASH=0'; \
		echo 'HAVE_PATH_MAX=1'; \
		echo 'HAVE_PLEDGE=0'; \
		echo 'HAVE_PROGNAME=0'; \
		echo 'HAVE_REALLOCARRAY=$(if $(BR2_TOOLCHAIN_USES_GLIBC),1,0)'; \
		echo 'HAVE_RECALLOCARRAY=0'; \
		echo 'HAVE_RECVMSG=1'; \
		echo 'HAVE_REWB_BSD=0'; \
		echo 'HAVE_REWB_SYSV=1'; \
		echo 'HAVE_SANDBOX_INIT=0'; \
		echo 'HAVE_STRCASESTR=1'; \
		echo 'HAVE_STRINGLIST=0'; \
		echo 'HAVE_STRLCAT=$(if $(BR2_TOOLCHAIN_USES_GLIBC),1,0)'; \
		echo 'HAVE_STRLCPY=$(if $(BR2_TOOLCHAIN_USES_GLIBC),1,0)'; \
		echo 'HAVE_STRNDUP=1'; \
		echo 'HAVE_STRPTIME=1'; \
		echo 'HAVE_STRSEP=1'; \
		echo 'HAVE_STRTONUM=0'; \
		echo 'HAVE_SYS_ENDIAN=0'; \
		echo 'HAVE_VASPRINTF=1'; \
		echo 'HAVE_WCHAR=$(if $(BR2_USE_WCHAR),1,0)'; \
	) > $(@D)/configure.local
	cd $(@D) && $(TARGET_MAKE_ENV) ./configure
endef

define MANDOC_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

# base-install: mandoc, demandoc, soelim + man/apropos/whatis/makewhatis links
define MANDOC_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) base-install
endef

$(eval $(generic-package))

# Host build: configure's run-tests work natively, so only fix the paths.
# base-install puts makewhatis in $(HOST_DIR)/sbin.
HOST_MANDOC_DEPENDENCIES = host-zlib

define HOST_MANDOC_CONFIGURE_CMDS
	( \
		echo 'CC="$(HOSTCC)"'; \
		echo 'CFLAGS="$(HOST_CFLAGS)"'; \
		echo 'LDFLAGS="$(HOST_LDFLAGS)"'; \
		echo 'PREFIX="$(HOST_DIR)"'; \
		echo 'MANDIR="$(HOST_DIR)/share/man"'; \
		echo 'MANPATH_DEFAULT="/usr/share/man:/usr/local/share/man"'; \
	) > $(@D)/configure.local
	cd $(@D) && $(HOST_MAKE_ENV) ./configure
endef

define HOST_MANDOC_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D)
endef

define HOST_MANDOC_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D) base-install
endef

$(eval $(host-generic-package))
