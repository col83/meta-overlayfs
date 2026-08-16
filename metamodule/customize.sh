#!/system/bin/sh

# KSU vars
KSU=true
DEBUG=0

MKE2FS_DEBUG=0

ABI=$(grep_get_prop ro.product.cpu.abi)
case "$ABI" in
    arm64-v8a)
        ;;
    *)
        ui_print ""
        ui_print "- ! Unsupported architecture: $ABI"
        abort
        ;;
esac


META_BIN="meta-overlayfs"

if [ ! -f "$MODPATH/${META_BIN}" ]; then
    ui_print ""
    abort "! Binary not found: ${META_BIN}"
fi

if ! chmod 755 "$MODPATH/${META_BIN}"; then
    ui_print ""
    abort "! Failed to set permissions"
fi

if [ ! -x "$MODPATH/${META_BIN}" ]; then
    ui_print ""
    abort "! Binary is not executable after chmod"
fi

# Create ext4 image for module content storage
IMG_FILE="$MODPATH/modules.img"
IMG_SIZE_MB=2048
EXISTING_IMG="/data/adb/modules/$MODID/modules.img"

if [ -f "$EXISTING_IMG" ]; then

    ui_print "- Reusing modules image from previous install"

    # if ! "$MODPATH/${META_BIN}" xcp "$EXISTING_IMG" "$IMG_FILE"; then
    if ! "$MODPATH/${META_BIN}" xcp --punch-hole "$EXISTING_IMG" "$IMG_FILE"; then
        ui_print ""
        abort "! Failed to copy existing modules image"
    fi

    if [ ! -f "$IMG_FILE" ]; then
        ui_print ""
        abort "! Modules image was not created"
    fi

else

    ui_print ""
    ui_print "- Creating 2GiB ext4 sparse image for modules storage"
    ui_print ""

    # Create sparse file (2 GiB logical size)
    if ! truncate -s "${IMG_SIZE_MB}M" "$IMG_FILE"; then
        ui_print ""
        abort "! Failed to create image file"
    fi

    # Create ext4 filesystem without a journal to avoid jbd2 sysfs node
    if [ "${MKE2FS_DEBUG:-0}" = "1" ]; then
        if ! /system/bin/mke2fs -t ext4 -O ^has_journal -F "$IMG_FILE"; then
            ui_print ""
            abort "! Failed to format ext4 image"
        fi
    else
        if ! /system/bin/mke2fs -t ext4 -O ^has_journal -F "$IMG_FILE" >/dev/null 2>&1; then
            ui_print ""
            abort "! Failed to format ext4 image"
        fi
    fi

fi
