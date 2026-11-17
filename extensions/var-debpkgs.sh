# SPDX-License-Identifier: GPL-2.0-only
#
# Extension to add the Variscite Package Repository
#
# The Variscite Package repository is provided as a proof-of-concept
# and no guarantees are made about the suitability or updates of the packages
# provided in it.
function custom_apt_repo__install_var_packages() {
	display_alert "VAR repository hook" "CUSTOM_REPO_WHEN=${CUSTOM_REPO_WHEN}"

	local -a supported_releases=("trixie")

	if [[ ! " ${supported_releases[*]} " =~ " ${RELEASE} " ]]; then
		display_alert "${EXTENSION} does not support release ${RELEASE}. Supported releases: ${supported_releases[*]}" "warn"
		return 0
	fi

	cat > "${SDCARD}/etc/apt/sources.list.d/var.sources" <<- EOF
Types: deb
URIs: https://varigit.github.io/var-debpkgs/var
 https://varigit.github.io/var-debpkgs/var-ti
 https://varigit.github.io/var-debpkgs/${BOARD}
Suites: ${RELEASE}
Components: main
Trusted: yes
EOF

	display_alert "VAR repository" "created var.sources"
	run_host_command_logged "cat ${SDCARD}/etc/apt/sources.list.d/var.sources"
}
