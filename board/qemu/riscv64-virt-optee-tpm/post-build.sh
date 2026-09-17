#!/bin/sh
# Put manual pages back on the target.
#
# Buildroot's target-finalize unconditionally does
#   rm -rf $(TARGET_DIR)/usr/share/man
# *before* running post-build scripts, so everything the packages installed
# there (make, file, bash, dropbear, tpm2-tools, openssl, mandoc, man-pages, ...)
# is gone by the time we run.  With BR2_PER_PACKAGE_DIRECTORIES=y each
# package's own install tree still exists under output/per-package/<pkg>/target,
# so re-assemble /usr/share/man from the union of those.
set -e

PER_PACKAGE_DIR="${BASE_DIR}/per-package"
if [ ! -d "${PER_PACKAGE_DIR}" ]; then
	echo "$0: ${PER_PACKAGE_DIR} not found (BR2_PER_PACKAGE_DIRECTORIES off?); not restoring man pages" >&2
	exit 0
fi

mkdir -p "${TARGET_DIR}/usr/share/man"
for d in "${PER_PACKAGE_DIR}"/*/target/usr/share/man; do
	[ -d "$d" ] || continue
	rsync -a --ignore-existing "$d/" "${TARGET_DIR}/usr/share/man/"
done
echo "man pages restored: $(find "${TARGET_DIR}/usr/share/man" -type f | wc -l) files"

# Index for apropos/whatis and to silence "outdated mandoc.db" (host-mandoc).
if [ -x "${HOST_DIR}/sbin/makewhatis" ]; then
	"${HOST_DIR}/sbin/makewhatis" "${TARGET_DIR}/usr/share/man"
fi

# On-target gcc (BR2_PACKAGE_GCC_TARGET): a native compiler needs the libc
# headers and startup objects, which Buildroot keeps in staging (the sysroot)
# and never copies to the target.  If gcc was installed, put them in place.
if [ -e "${TARGET_DIR}/usr/bin/gcc" ] && [ -d "${STAGING_DIR}" ]; then
	echo "gcc-target: installing libc headers + startup objects from staging"
	mkdir -p "${TARGET_DIR}/usr/include" "${TARGET_DIR}/usr/lib"
	rsync -a "${STAGING_DIR}/usr/include/" "${TARGET_DIR}/usr/include/"
	# crt*.o startup objects, static archives, and .so linker scripts/dev symlinks
	for f in "${STAGING_DIR}"/usr/lib/*.o "${STAGING_DIR}"/usr/lib/*.a "${STAGING_DIR}"/usr/lib/*.so; do
		[ -e "$f" ] || continue
		cp -a "$f" "${TARGET_DIR}/usr/lib/"
	done
	# target-finalize strips every *.a from the target *before* this script
	# runs, which removes gcc's own static libs (libgcc.a, libstdc++.a, ...).
	# gcc needs at least libgcc.a to link, so restore them from gcc-target's
	# per-package install tree.
	# target-finalize also wipes /usr/include and strips every *.a *before*
	# this script runs.  The libc headers were restored from staging above,
	# but gcc's own dev files (the C++ stdlib headers under /usr/include/c++,
	# libgcc.a, libstdc++.a, ...) live only in gcc-target's per-package tree.
	# Restore them so g++ finds <iostream> and the linker finds libgcc.a.
	GCC_PP="${BASE_DIR}/per-package/gcc-target/target"
	if [ -d "${GCC_PP}" ]; then
		( cd "${GCC_PP}" && \
			find usr/lib -name '*.a' -exec cp -a --parents {} "${TARGET_DIR}/" \; )
		if [ -d "${GCC_PP}/usr/include/c++" ]; then
			mkdir -p "${TARGET_DIR}/usr/include/c++"
			cp -a "${GCC_PP}/usr/include/c++/." "${TARGET_DIR}/usr/include/c++/"
		fi
	fi
fi
