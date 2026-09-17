################################################################################
#
# man-pages
#
################################################################################

MAN_PAGES_VERSION = 6.19
MAN_PAGES_SOURCE = man-pages-$(MAN_PAGES_VERSION).tar.xz
MAN_PAGES_SITE = https://www.kernel.org/pub/linux/docs/man-pages
MAN_PAGES_LICENSE = Linux-man-pages-copyleft, GPL-2.0+, BSD-2-Clause, BSD-3-Clause, BSD-4-Clause-UC, LGPL-3.0+, MIT (per-page, see LICENSES/)
MAN_PAGES_LICENSE_FILES = LICENSES/Linux-man-pages-copyleft.txt

# The project's own GNUmakefile pulls in a lot of host tooling (sponge, ...)
# only to copy files around; the pages are plain roff sources, so copy them.
define MAN_PAGES_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/man
	cp -a $(@D)/man/man* $(TARGET_DIR)/usr/share/man/
endef

$(eval $(generic-package))
