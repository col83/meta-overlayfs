#!/system/bin/sh

ui_print "- Checking device architecture..."

ABI=$(grep_get_prop ro.product.cpu.abi)
ui_print "- Detected ABI: $ABI"

case "$ABI" in
    arm64-v8a)
        ;;
    *)
        abort "! Unsupported architecture: $ABI"
        ;;
esac

if [ ! -f "$MODPATH/meta-overlayfs" ]; then
    abort "! Binary not found: meta-overlayfs"
fi

if ! chmod 755 "$MODPATH/meta-overlayfs"; then
    abort "! Failed to set permissions"
fi

ui_print "- meta-overlayfs binary installed successfully"

# Create ext4 image for module content storage
IMG_FILE="$MODPATH/modules.img"
IMG_SIZE_MB=2048
EXISTING_IMG="/data/adb/modules/$MODID/modules.img"

if [ -f "$EXISTING_IMG" ]; then

    ui_print "- Reusing modules image from previous install"

    "$MODPATH/meta-overlayfs" xcp "$EXISTING_IMG" "$IMG_FILE" || \
        abort "! Failed to copy existing modules image"

else

    ui_print "- Creating 2GB ext4 image for module storage"

    # Create sparse file (2GB logical size, 0 bytes actual)
    truncate -s "${IMG_SIZE_MB}M" "$IMG_FILE" || \
        abort "! Failed to create image file"

    # Remove journal to prevent creating jbd2 sysfs node
    /system/bin/mke2fs -t ext4 -O ^has_journal -F "$IMG_FILE" >/dev/null 2>&1 || \
        abort "! Failed to format ext4 image"

    ui_print "- Image created successfully (sparse file)"

fi

ui_print "- Installation complete"

