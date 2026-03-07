
[ -f "$MODPATH/files/valinor/tools/arm64/tinymix" ] && alias tinymix="$MODPATH/files/valinor/tools/arm64/tinymix"
[ -f "/system/bin/tinymix" ] && mount -o bind "$MODPATH/files/valinor/tools/arm64/tinymix" "/system/bin/tinymix"; [ -f "/vendor/bin/tinymix" ] && mount -o bind "$MODPATH/files/valinor/tools/arm64/tinymix" "/vendor/bin/tinymix"
mount | grep -q "zyx_ainur_silmaril" && echo "SILMARIL initialized" || echo "SILMARIL isn't mounted"