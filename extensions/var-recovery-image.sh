# SPDX-License-Identifier: GPL-2.0-only
# var-recovery-image extension:
#
# This turns any image into an image suitable as a SD Recovery Image
# A SD Recovery Image
#
# - has a certain set of tools installed for testing interfaces
# - sets default user accounts for root (root) and user (user)
# - sets a Variscite logo in /etc/issue(.net)
# - deactivates auto-login
#
# In order to generate an SD card for installation to internal storage,
# please also enable the extension variscite-fs-tar.

function extension_prepare_config__add_var_packages() {
	local -a VAR_PACKAGES=()

	# Install packages that are needed for Variscite Recovery, but are not
	# strictly necessary for other customer images
	VAR_PACKAGES+=("docker.io" "docker-cli")                          # for Docker tests
	VAR_PACKAGES+=("var-mii" "iperf3" "net-tools" "util-linux-extra") # for network tests
	VAR_PACKAGES+=("bluez")                                           # for BT tests
	VAR_PACKAGES+=("can-utils")                                       # for CAN tests
	VAR_PACKAGES+=("evtest")                                          # for touch / input tests
	VAR_PACKAGES+=("i2c-tools" "spi-tools")                           # for SPI / I2C tests
	VAR_PACKAGES+=("v4l-utils" "yavta" "libcamera-v4l2")
	VAR_PACKAGES+=("gstreamer1.0-libcamera")                          # for camera tests
	VAR_PACKAGES+=("udhcpd" "hostapd")                                # for WiFI AP tests
	VAR_PACKAGES+=("swupdate")                                        # swupdate
	VAR_PACKAGES+=("pv" "zstd")                                       # additional tools
	VAR_PACKAGES+=("img-powervr-sdk")                                 # GPU Test Application
	VAR_PACKAGES+=("optee-test-k3")                                   # xtest OP Tee Test suite
	VAR_PACKAGES+=("var-install-yocto")                               # installation to internal storage

	if [[ ${#VAR_PACKAGES[@]} -gt 0 ]] ; then
		add_packages_to_image "${VAR_PACKAGES[@]}"
	fi

	# don't remove HOME DIR during image creation
	INCLUDE_HOME_DIR=yes
}

function pre_customize_image__make_var_modifications() {
	# netplan will look for all Ethernet interfaces (end* and eth*)
	# The issue is that at some point eth* interfaces will be renamed to end*
	# and netplan will attempt to manage the non-existing eth* interfaces
	# Fix this by telling netplan to only handle end* interfaces
	local netplan="${SDCARD}/etc/netplan/10-dhcp-all-interfaces.yaml"

	if [[ -f "$netplan" ]]; then
		sed -Ei 's/^([[:space:]]*)name: "e\*"$/\1name: "end*"/' "$netplan"
	else
		display_alert "Netplan configuration not found" "${netplan}" "warn"
	fi

	# Set default users for Variscite Recovery SD Cards
	# root:root
	# user:user
	chroot_sdcard 'echo root:root | chpasswd'
	chroot_sdcard 'useradd -m -U -s /bin/bash user'
	chroot_sdcard 'echo user:user | chpasswd'

	rm -f "${SDCARD}/root/.not_logged_in_yet"

	# Modify /etc/issue to reflect Variscite changes
	local year
	local issue
	year="$(date +%Y)"

	for issue in issue issue.net; do
		cat >> "${SDCARD}/etc/${issue}" <<'EOF'
                  _          _
       __        (_)        (_) _
  __  / /_ _ _ __ _ ___  ___ _ | |_ __
  \\ \\/ / _` | '__| / __|/ __| |_  _/ _ \\
   \\/ / (_| | |  | \\__ \\ (__| || ||  __/
    \\/ \\__,_|_|  |_|___/\\___|_| \\__\\___|

EOF

		printf '          %s Variscite, Ltd.\n\n' "$year" >> "${SDCARD}/etc/${issue}"
	done
}

function post_family_config__var_recovery_console() {
	# In this extension we explicitly set passwords for 'root' and 'user'
	# Therefore don't use autologin
	CONSOLE_AUTOLOGIN=no
}
