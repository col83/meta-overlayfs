#!/system/bin/sh
############################################
# meta-overlayfs metauninstall.sh
# Module uninstallation hook for ext4 image cleanup
############################################

# Constants
IMG_FILE="/data/adb/metamodule/modules.img"
MNT_DIR="/data/adb/metamodule/mnt"

MODULE_ID="${MODULE_ID:-$1}"

if [ -z "$MODULE_ID" ]; then
    echo "! Error: MODULE_ID not provided"
    exit 1
fi

echo "- Cleaning up module content from image: $MODULE_ID"

MOUNTED_BY_US=0

if ! mountpoint -q "$MNT_DIR" 2>/dev/null; then
    if [ ! -f "$IMG_FILE" ]; then
        echo "! Warning: Image not found, skipping cleanup"
        exit 0
    fi

    mkdir -p "$MNT_DIR"
    chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null

    mount -t ext4 -o loop,rw,noatime "$IMG_FILE" "$MNT_DIR" || {
        echo "! Warning: Failed to mount modules image, skipping cleanup"
        exit 0
    }

    MOUNTED_BY_US=1
fi

MOD_IMG_DIR="$MNT_DIR/$MODULE_ID"

if [ -d "$MOD_IMG_DIR" ]; then
    echo "  Removing $MOD_IMG_DIR"
    rm -rf "$MOD_IMG_DIR" || {
        echo "! Warning: Failed to remove module content from image"
    }
    echo "- Module content removed from image"
else
    echo "- No module content found in image, skipping"
fi

if [ "$MOUNTED_BY_US" = "1" ]; then
    umount "$MNT_DIR"
fi

exit 0