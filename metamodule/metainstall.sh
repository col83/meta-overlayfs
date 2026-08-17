#!/system/bin/sh

############################################
# meta-overlayfs metainstall.sh
# Module installation hook for ext4 image support
############################################

# Constants
IMG_FILE="/data/adb/metamodule/modules.img"
MNT_DIR="/data/adb/metamodule/mnt"

# Ensure ext4 image is mounted
ensure_image_mounted() {

    if ! mountpoint -q "$MNT_DIR" 2>/dev/null; then

        ui_print "- Mounting modules image"

        mkdir -p "$MNT_DIR"
        chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null

        mount -t ext4 -o loop,rw,noatime "$IMG_FILE" "$MNT_DIR" || {
            abort "! Failed to mount modules image"
        }

        ui_print "- Image mounted successfully"

    else

        ui_print ""
        ui_print "- Image already mounted"

    fi

}

# Determine whether this module should be moved into the ext4 image.
# We only relocate payloads that expose system/ overlays and do not opt out via skip_mount.
module_requires_overlay_move() {

    if [ -f "$MODPATH/skip_mount" ]; then
        ui_print "- skip_mount flag detected; keeping files under /data/adb/modules"
        return 1
    fi

    for partition in system vendor product system_ext odm oem; do

        if [ -d "$MODPATH/$partition" ]; then
            return 0
        fi

    done

    ui_print "- No supported partition directory detected; keeping files under /data/adb/modules"
    return 1

}

# Copy SELinux contexts from src tree to destination by mirroring each entry.
copy_selinux_contexts() {

    command -v chcon >/dev/null 2>&1 || return 0

    SRC="$1"
    DST="$2"

    if [ -z "$SRC" ] || [ -z "$DST" ] || [ ! -e "$SRC" ] || [ ! -e "$DST" ]; then
        return 0
    fi

    CHCON_FLAG=""
    if [ -L "$SRC" ]; then
        CHCON_FLAG="-h"
    fi
    chcon $CHCON_FLAG --reference="$SRC" "$DST" 2>/dev/null || true

    find "$SRC" -print | while IFS= read -r PATH_SRC; do

        if [ "$PATH_SRC" = "$SRC" ]; then
            continue
        fi

        REL_PATH="${PATH_SRC#"${SRC}/"}"
        PATH_DST="$DST/$REL_PATH"
        if [ -e "$PATH_DST" ] || [ -L "$PATH_DST" ]; then

            CHCON_FLAG=""
            if [ -L "$PATH_SRC" ]; then
                CHCON_FLAG="-h"
            fi

            chcon $CHCON_FLAG --reference="$PATH_SRC" "$PATH_DST" 2>/dev/null || true

        fi

    done

}

# Copy partition payload to the modules image and remove it from the module directory.
post_install_to_image() {

    ui_print "- Copying module content to image"
    ui_print ""

    set_perm_recursive "$MNT_DIR" 0 0 0755 0644

    MOD_IMG_DIR="$MNT_DIR/$MODID"
    mkdir -p "$MOD_IMG_DIR"
    set_perm_recursive "$MOD_IMG_DIR" 0 0 0755 0644

    for partition in system vendor product system_ext odm oem; do

        if [ -d "$MODPATH/${partition:?}" ]; then

            ui_print "- Copying $partition"

            if cp -af "$MODPATH/$partition" "$MOD_IMG_DIR/"; then

                copy_selinux_contexts "$MODPATH/$partition" "$MOD_IMG_DIR/$partition"

                # Keep partition content only in the modules image.
                # The module directory is reserved for metadata and module state.
                # The meta-overlayfs binary reads payload from the modules image,
                # not from the KernelSU module directory.
                if ! rm -rf "$MODPATH/${partition:?}"; then
                    ui_print ""
                    abort "! Failed to remove original $partition"
                fi

            else

                ui_print ""
                abort "! Failed to copy $partition to modules image"

            fi

        fi

    done

}


# REPLACE
mark_replace() {
  replace_target="$1"
  mkdir -p "$replace_target"
  setfattr -n trusted.overlay.opaque -v y "$replace_target"
}

ui_print "- Using meta-overlayfs metainstall"

install_module

if module_requires_overlay_move; then
    ensure_image_mounted
    post_install_to_image
else
    ui_print "- Skipping move to modules image"
fi

ui_print ""
