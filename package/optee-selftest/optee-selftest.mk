################################################################################
#
# optee-selftest
#
# Custom OP-TEE Trusted Application + host client, built in-tree (source in
# this package's src/).  Models package/optee-examples: the TA is built with
# the OP-TEE TA dev kit ($(OPTEE_OS_SDK)) and the cross toolchain, the host
# client links optee-client's libteec.
#
################################################################################

OPTEE_SELFTEST_VERSION = 1.0
OPTEE_SELFTEST_SITE = $(OPTEE_SELFTEST_PKGDIR)/src
OPTEE_SELFTEST_SITE_METHOD = local
OPTEE_SELFTEST_LICENSE = BSD-2-Clause
OPTEE_SELFTEST_DEPENDENCIES = optee-client optee-os

OPTEE_SELFTEST_UUID = 5d6f971b-8fc2-4695-b3b9-1c58670463af

define OPTEE_SELFTEST_BUILD_CMDS
	# Trusted Application (secure world), built with the TA dev kit.
	$(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D)/ta \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		TA_DEV_KIT_DIR="$(OPTEE_OS_SDK)" \
		O=out
	# Host client (normal world), links libteec from staging.  CC is forced
	# on the command line: Buildroot exports CC=host-gcc into the make
	# environment, which the Makefile's "CC ?=" would otherwise keep,
	# producing "unsupported ABI" from the target glibc headers.
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/host \
		CC="$(TARGET_CROSS)gcc" \
		TEEC_EXPORT="$(STAGING_DIR)/usr"
endef

define OPTEE_SELFTEST_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0444 $(@D)/ta/out/$(OPTEE_SELFTEST_UUID).ta \
		$(TARGET_DIR)/lib/optee_armtz/$(OPTEE_SELFTEST_UUID).ta
	$(INSTALL) -D -m 0755 $(@D)/host/optee_selftest \
		$(TARGET_DIR)/usr/bin/optee_selftest
endef

$(eval $(generic-package))
