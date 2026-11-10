#!/bin/sh

die() {
    echo "$1" >&2
    exit 1
}

# First: Use standard installation from Yocto
install_yocto.sh "$@" || die "Installation failed"

# Next: Fix up /etc/fstab
BOOT_PART=/dev/mmcblk0p1
ROOT_PART=/dev/mmcblk0p2
DATA_PART=/dev/mmcblk0p4 # only exists when called with -u parameter

if ! ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART"); then
    die "ERROR: Cannot determine UUID of $ROOT_PART"
fi

if ! BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PART"); then
    die "ERROR: Cannot determine UUID of $BOOT_PART" >&2
fi

TMPDIR=$(mktemp -d)
mount "$ROOT_PART" "$TMPDIR" || die "Cannot mount new partition $ROOT_PART"

sed -i -E \
	-e "s|^UUID=[^[:space:]]+([[:space:]]+/[[:space:]]+)|UUID=${ROOT_UUID}\1|" \
	-e "s|^UUID=[^[:space:]]+([[:space:]]+/boot/firmware[[:space:]]+)|UUID=${BOOT_UUID}\1|" \
	"$TMPDIR/etc/fstab"

umount "$TMPDIR"
rmdir "$TMPDIR"
