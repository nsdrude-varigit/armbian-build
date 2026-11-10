# SPDX-License-Identifier: GPL-2.0-only
# Export rootfs and bootfs as tar archive
# This extension exports file systems rootfs and bootfs and provides them in
# the build directory.
# These files can be used by the installation to internal storage,
# but also when creating SWU files.
#
# Optional parameter: if $INCLUDE_VAR_INSTALL is set to yes:
# Include both rootfs and bootfs in /opt/images/Debian/
# Also provide install_debian.sh
# This script allows an installation from SD card to eMMC.
# The extension var-recover-image must be enabled to have the
# required tools installed for that.

function prepare_image_size__export_filesystems() {
    [[ "${INCLUDE_VAR_INSTALL:-no}" == "yes" ]] || return 0

    # When including VAR_INSTALL, a tar archive of the bootfs and
    # the rootfs are added to the final image.
    # These tar archives are not part of the original size
    # calculation so we need to reserve extra space for this
    # This adds rootfs_size again.
    # The exact size of the tar archives are not known at the time
    # when partitioning needs to be done.
    # As both bootfs and rootfs tar archives are compressed this
    # is certainly enough
    # Additional space will be free disk space on the SD card

    EXTRA_ROOTFS_MIB_SIZE=$((EXTRA_ROOTFS_MIB_SIZE + rootfs_size))
    display_alert \
        "Extension: ${EXTENSION}: Reserving extra $rootfs_size for installer archives" \
        "info"
}

function pre_umount_final_image__export_filesystems() {
    local root_output="${FINALDEST}/${version}-rootfs.tar.zst"
    local boot_output="${FINALDEST}/${version}-bootfs.tar.zst"
    local boot_mount

    # Determine where the FAT boot partition is mounted.
    if mountpoint -q "${MOUNT}/boot/firmware"; then
        boot_mount="${MOUNT}/boot/firmware"
    elif mountpoint -q "${MOUNT}/boot"; then
        boot_mount="${MOUNT}/boot"
    else
        exit_with_error "FAT boot partition is not mounted"
    fi

    # Verify that the detected boot partition is FAT.
    [[ "$(findmnt -rn -o FSTYPE --mountpoint "$boot_mount")" == "vfat" ]] ||
        exit_with_error "Expected FAT filesystem at $boot_mount"

    display_alert "Extension: ${EXTENSION}: Exporting file systems as tar archive" "info"

    # Export the root filesystem, excluding other mounted filesystems.
    tar --create --zstd \
        --file="$root_output" \
        --directory="$MOUNT" \
        --one-file-system \
        --numeric-owner \
        --acls \
        --xattrs \
        . || exit_with_error "Could not export rootfs"

    # Export the FAT boot partition.
    tar --create --zstd \
        --file="$boot_output" \
        --directory="$boot_mount" \
        --one-file-system \
        --numeric-owner \
        . || exit_with_error "Could not export bootfs"

    if [[ "$INCLUDE_VAR_INSTALL" = "yes" ]]; then
        display_alert "Extension: ${EXTENSION}: Including tar archives for installation to internal storage" "info"
        local var_tgt_dir="${MOUNT}/opt/images/Debian/"
        mkdir -p "${var_tgt_dir}"
        cp "$boot_output" "${var_tgt_dir}/bootfs.tar.zst"
        cp "$root_output" "${var_tgt_dir}/rootfs.tar.zst"

        # extract boot image to get the format that the installer demands
        mkdir -p "${var_tgt_dir}/boot"
        tar xf "${var_tgt_dir}/bootfs.tar.zst" -C "${var_tgt_dir}/boot"

        # copy install_debian script -> still relies on install_yocto.sh
        install -m 755 "${EXTENSION_DIR}/install_debian.sh" "${MOUNT}/usr/bin/install_debian.sh"
    fi
}

function post_family_tweaks__config_var_fwenv() {
    display_alert "Configuring fw_printenv and fw_setenv" "for ${BOARD}" "info"

    cat <<-'FW_ENV_CONFIG' > "${SDCARD}/etc/fw_env.config"
        # VAR-SOM-AM62P U-Boot environment
        # CONFIG_ENV_OFFSET=0x2B00000
        # CONFIG_ENV_SIZE=0x40000
        #
        # Device           Device offset  Env. size
        /dev/mmcblk1       0x2B00000      0x40000
FW_ENV_CONFIG

}

