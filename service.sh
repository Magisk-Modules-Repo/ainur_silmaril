
[ -f "$MODPATH/files/valinor/tools/arm64/tinymix" ] && alias tinymix="$MODPATH/files/valinor/tools/arm64/tinymix"
mount -o bind "$MODPATH/files/valinor/tools/arm64/tinymix" "/system/bin/tinymix"
