# SPDX-License-Identifier: GPL-2.0-only
#
# NXP Wi-Fi DKMS driver

WIFI_NXP_NAME="wifi-nxp"
WIFI_NXP_VERSION="6.12.20-2.0.0"

WIFI_NXP_REPOSITORY="https://github.com/nxp-imx/mwifiex.git"
WIFI_NXP_BRANCH="lf-6.12.20_2.0.0"
WIFI_NXP_COMMIT="7a8beaa1605cb0870dc7ba3312c76df91cb0d6cf"

#
# Request matching kernel headers and fetch the pinned NXP source.
#
function extension_finish_config__wifi_nxp() {
	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		exit_with_error \
			"NXP Wi-Fi DKMS requires working kernel headers" \
			"kernel ${KERNEL_MAJOR_MINOR}-${BRANCH}-${LINUXFAMILY}"
	fi

	declare -g INSTALL_HEADERS="yes"

	display_alert \
		"Forcing INSTALL_HEADERS=yes" \
		"NXP Wi-Fi DKMS" \
		"debug"

	#
	# Fetch on the build host rather than from inside the target chroot.
	#
	local cache_dir="${SRC}/cache/sources/wifi-nxp"

	if [[ ! -d "${cache_dir}/.git" ]]; then
		display_alert \
			"Cloning NXP Wi-Fi driver" \
			"${WIFI_NXP_BRANCH}" \
			"info"

		rm -rf "${cache_dir}"
		mkdir -p "$(dirname "${cache_dir}")"

		run_host_command_logged \
			git clone \
			--branch "${WIFI_NXP_BRANCH}" \
			--single-branch \
			"${WIFI_NXP_REPOSITORY}" \
			"${cache_dir}"
	fi

	#
	# Always force the cached tree back to the exact BSP revision.
	#
	run_host_command_logged \
		git \
		-C "${cache_dir}" \
		fetch \
		origin \
		"${WIFI_NXP_COMMIT}"

	run_host_command_logged \
		git \
		-C "${cache_dir}" \
		checkout \
		--force \
		"${WIFI_NXP_COMMIT}"

	local actual_commit
	actual_commit="$(git -C "${cache_dir}" rev-parse HEAD)"

	if [[ "${actual_commit}" != "${WIFI_NXP_COMMIT}" ]]; then
		exit_with_error \
			"Unexpected NXP Wi-Fi source revision" \
			"${actual_commit}"
	fi
}


#
# Install and build the driver once the kernel and kernel headers
# have been installed into the target rootfs.
#
function post_install_kernel_debs__wifi_nxp() {
	if [[ "${INSTALL_HEADERS}" != "yes" ]] ||
	   [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		exit_with_error \
			"NXP Wi-Fi DKMS cannot be installed" \
			"kernel headers unavailable"
	fi

	local target_kver
	target_kver="${IMAGE_INSTALLED_KERNEL_VERSION}-${BRANCH}-${LINUXFAMILY}"

	if [[ -z "${IMAGE_INSTALLED_KERNEL_VERSION}" ]]; then
		exit_with_error \
			"Cannot determine installed kernel version" \
			"NXP Wi-Fi DKMS"
	fi

	display_alert \
		"Installing NXP Wi-Fi DKMS driver" \
		"${WIFI_NXP_VERSION}" \
		"info"

	display_alert \
		"NXP Wi-Fi target kernel" \
		"${target_kver}" \
		"info"

	#
	# The kernel module directory itself should already exist.
	#
	if [[ ! -d "${SDCARD}/lib/modules/${target_kver}" ]]; then
		exit_with_error \
			"Target kernel module directory does not exist" \
			"/lib/modules/${target_kver}"
	fi

	#
	# Install DKMS.
	#
	# This is harmless if another package, such as the Rogue driver,
	# already pulled it into the image.
	#
	use_clean_environment="yes" \
		chroot_sdcard_apt_get_install "dkms"

	#
	# Verify the headers from inside the target rootfs.
	#
	# Do NOT test ${SDCARD}/lib/modules/.../build from the host side:
	# it is an absolute symlink to /usr/src/... and therefore resolves
	# against the host/container root instead of the target rootfs.
	#
	if ! use_clean_environment="yes" \
		chroot_sdcard \
		"test -d /lib/modules/${target_kver}/build"; then

		display_alert \
			"NXP Wi-Fi kernel header diagnostics" \
			"${target_kver}" \
			"warn"

		use_clean_environment="yes" \
			chroot_sdcard \
			"ls -la /lib/modules/${target_kver} || true"

		use_clean_environment="yes" \
			chroot_sdcard \
			"ls -la /usr/src || true"

		use_clean_environment="yes" \
			chroot_sdcard \
			"dpkg -l 'linux-headers*' || true"

		exit_with_error \
			"Kernel headers are not usable inside target rootfs" \
			"/lib/modules/${target_kver}/build"
	fi

	#
	# Useful short diagnostics before invoking DKMS.
	#
	echo
	echo "========== WIFI_NXP PRE-DKMS CHECK =========="

	use_clean_environment="yes" \
		chroot_sdcard \
		"ls -ld /lib/modules/${target_kver}/build"

	use_clean_environment="yes" \
		chroot_sdcard \
		"readlink -f /lib/modules/${target_kver}/build"

	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms status || true"

	echo "=============================================="
	echo

	#
	# Install NXP source under /usr/src.
	#
	local source_dir="/usr/src/${WIFI_NXP_NAME}-${WIFI_NXP_VERSION}"
	local host_source_dir="${SDCARD}${source_dir}"
	local cache_dir="${SRC}/cache/sources/wifi-nxp"

	rm -rf "${host_source_dir}"
	mkdir -p "${host_source_dir}"

	cp -a \
		"${cache_dir}/." \
		"${host_source_dir}/"

	#
	# Do not include Git metadata in the image.
	#
	rm -rf "${host_source_dir}/.git"

	#
	# Add the DKMS-specific files maintained alongside the extension.
	#
	cp \
		"${SRC}/extensions/wifi_nxp/dkms.conf" \
		"${host_source_dir}/dkms.conf"

	cp \
		"${SRC}/extensions/wifi_nxp/dkms-build.sh" \
		"${host_source_dir}/dkms-build.sh"

	chmod 0755 \
		"${host_source_dir}/dkms-build.sh"

	#
	# Remove any stale registration of this exact driver version.
	# This is mainly useful during repeated development builds.
	#
	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms remove \
			-m ${WIFI_NXP_NAME} \
			-v ${WIFI_NXP_VERSION} \
			--all >/dev/null 2>&1 || true"

	#
	# Register the source with DKMS.
	#
	display_alert \
		"Registering NXP Wi-Fi with DKMS" \
		"${WIFI_NXP_VERSION}" \
		"info"

	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms add \
			-m ${WIFI_NXP_NAME} \
			-v ${WIFI_NXP_VERSION}"

	#
	# Make Armbian show the DKMS build log when a failure occurs.
	#
	declare -ag if_error_find_files_sdcard=(
		"/var/lib/dkms/${WIFI_NXP_NAME}/${WIFI_NXP_VERSION}/build/make.log"
	)

	#
	# Build for the exact kernel installed in this image.
	#
	display_alert \
		"Building NXP Wi-Fi kernel modules" \
		"${target_kver}" \
		"info"

	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms build \
			-m ${WIFI_NXP_NAME} \
			-v ${WIFI_NXP_VERSION} \
			-k ${target_kver}"

	#
	# Install the built modules.
	#
	display_alert \
		"Installing NXP Wi-Fi kernel modules" \
		"${target_kver}" \
		"info"

	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms install \
			-m ${WIFI_NXP_NAME} \
			-v ${WIFI_NXP_VERSION} \
			-k ${target_kver}"

	#
	# Regenerate module dependency information.
	#
	use_clean_environment="yes" \
		chroot_sdcard \
		"depmod -a ${target_kver}"

	#
	# Final diagnostics.
	#
	echo
	echo "========== WIFI_NXP DKMS RESULT ============="

	use_clean_environment="yes" \
		chroot_sdcard \
		"dkms status \
			-m ${WIFI_NXP_NAME} \
			-v ${WIFI_NXP_VERSION} \
			-k ${target_kver}"

	use_clean_environment="yes" \
		chroot_sdcard \
		"find /lib/modules/${target_kver} \
			-type f \
			\\( -name 'mlan.ko*' -o -name 'moal.ko*' \\) \
			-print"

	echo "=============================================="
	echo

	display_alert \
		"NXP Wi-Fi DKMS driver installed" \
		"${target_kver}" \
		"info"
}
