##########################################################################################
#
# MMT Extended Utility Functions
#
##########################################################################################

require_new_ksu() {
  ui_print "**********************************"
  ui_print " Please install KernelSU v0.6.6+! "
  ui_print "**********************************"
  exit 1
}

umount_mirrors() {
  [ -d "$ORIGDIR" ] || return 0
  for i in "$ORIGDIR"/*; do
    umount -l "$i" 2>/dev/null
  done
  rm -rf "$ORIGDIR" 2>/dev/null
  $KSU && mount -o ro,remount "$MAGISKTMP"
}

cleanup() {
  if $KSU || [ "$MAGISK_VER_CODE" -ge 27000 ]; then umount_mirrors; fi
  rm -rf "$MODPATH"/common "$MODPATH"/install.zip 2>/dev/null
}

abort() {
  ui_print "$1"
  rm -rf "$MODPATH" 2>/dev/null
  cleanup
  rm -rf "$TMPDIR" 2>/dev/null
  exit 1
}

! $IS64BIT && abort "32bit-only devices are not supported. Aborting!"
[ "$ABI" = "x86_64" ] && abort "x86_64 devices are not supported. Aborting!"
grep -q "id=nomount" /data/adb/modules/*/module.prop && abort "NoMount is currently unsupported. Aborting!"

device_check() {
  local opt type
  opt=$(getopt -o dm -- "$@")
  type=device
  eval set -- "$opt"
  while true; do
    case "$1" in
      -d) type=device; shift;;
      -m) type=manufacturer; shift;;
      --) shift; break;;
      *) abort "Invalid device_check argument $1! Aborting!";;
    esac
  done
  local prop
  prop=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for i in /system /vendor /odm /product; do
    if [ -f "$i/build.prop" ]; then
      for j in "ro.product.$type" "ro.build.$type" "ro.product.vendor.$type" "ro.vendor.product.$type"; do
        [ "$(sed -n "s/^$j=//p" "$i/build.prop" 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$prop" ] && return 0
      done
      [ "$type" == "device" ] && [ "$(sed -n "s/^ro.build.product=//p" "$i/build.prop" 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$prop" ] && return 0
    fi
  done
  return 1
}

cp_ch() {
  local opt BAK UBAK FOL
  opt=$(getopt -o nr -- "$@")
  BAK=true
  UBAK=true
  FOL=false
  eval set -- "$opt"
  while true; do
    case "$1" in
      -n) UBAK=false; shift;;
      -r) FOL=true; shift;;
      --) shift; break;;
      *) abort "Invalid cp_ch argument $1! Aborting!";;
    esac
  done
  local SRC DEST OFILES
  SRC="$1"
  DEST="$2"
  OFILES="$1"
  $FOL && OFILES=$(find "$SRC" -type f 2>/dev/null)
  [ -z "$3" ] && PERM=0644 || PERM=$3
  case "$DEST" in
    $TMPDIR/*|$MODULEROOT/*|$NVBASE/modules/$MODID/*) BAK=false;;
  esac
  for OFILE in ${OFILES}; do
    local FILE
    if $FOL; then
      if [ "$(basename "$SRC")" == "$(basename "$DEST")" ]; then
        FILE="${OFILE//$SRC/$DEST}"
      else
        FILE="${OFILE//|$SRC|$DEST/$(basename "$SRC")|/$DEST/$(basename "$SRC")}"
      fi
    else
      if [ -d "$DEST" ]; then
        FILE="$DEST/$(basename "$SRC")"
      else
        FILE="$DEST"
      fi
    fi
    if $BAK && $UBAK; then
      if ! grep -q "$FILE$" "$INFO"; then
        echo "$FILE" >> "$INFO"
      fi
      [ -f "$FILE" ] && [ ! -f "$FILE~" ] && { mv -f "$FILE" "$FILE"~; echo "$FILE~" >> "$INFO"; }
    elif $BAK; then
      if ! grep -q "$FILE$" "$INFO"; then
        echo "$FILE" >> "$INFO"
      fi
    fi
    install -D -m "$PERM" "$OFILE" "$FILE"; case "$OFILE" in *.xml|*.conf|*.so) install -D -m "$PERM" "$OFILE" "${FILE}.stock"; chcon "u:object_r:dump_file:s0" "${FILE}.stock"; chmod 000 "${FILE}.stock"; chown 0:0 "${FILE}.stock" ;; esac
  done
}

install_script() {
  local INPATH
  case "$1" in
    -b) shift
        if $KSU; then
          INPATH=$NVBASE/boot-completed.d
        else
          INPATH=$SERVICED
          sed -i -e '1i (\nwhile [ "$(getprop sys.boot_completed)" != "1" ]; do\n  sleep 1\ndone\nsleep 3\n' -e '$a)&' "$1"
        fi ;;
    -l) shift; INPATH=$SERVICED ;;
    -p) shift; INPATH=$POSTFSDATAD ;;
    *) INPATH=$SERVICED ;;
  esac
  grep -q "#!/system/bin/sh" "$1" || sed -i "1i #!/system/bin/sh" "$1"
  local i
  for i in "MODPATH" "LIBDIR" "MODID" "INFO" "MODDIR"; do
    case $i in
      "MODPATH") sed -i "1a $i=$NVBASE/modules/$MODID" "$1" ;;
      "MODDIR") sed -i "1a $i=\${0%/*}" "$1" ;;
      *) sed -i "1a $i=$(eval echo \$$i)" "$1" ;;
    esac
  done
  case $1 in
    "$MODPATH/post-fs-data.sh"|"$MODPATH/service.sh"|"$MODPATH/uninstall.sh") sed -i "s|^MODPATH=.*|MODPATH=\$MODDIR|" "$1";;
    "$MODPATH/boot-completed.sh") $KSU && sed -i "s|^MODPATH=.*|MODPATH=\$MODDIR|" "$1" || { cp_ch -n "$1" "$INPATH"/"$MODID"-"$(basename "$1")" 0755; rm -f "$MODPATH"/boot-completed.sh; };;
    *) cp_ch -n "$1" "$INPATH"/"$(basename "$1")" 0755;;
  esac
}

prop_process() {
  sed -i -e "/^#/d" -e "/^ *$/d" "$1"
  [ -f "$MODPATH"/system.prop ] || mktouch "$MODPATH"/system.prop
  while read -r LINE; do
    echo "$LINE" >> "$MODPATH"/system.prop
  done < "$1"
}

mount_mirrors() {
  $KSU && mount -o rw,remount "$MAGISKTMP"
  mkdir -p "$ORIGDIR"/system
  if $SYSTEM_ROOT; then
    mkdir -p "$ORIGDIR"/system_root
    mount -o ro / "$ORIGDIR"/system_root
    mount -o bind "$ORIGDIR"/system_root/system "$ORIGDIR"/system
  else
    mount -o ro /system "$ORIGDIR"/system
  fi
  for i in /vendor $PARTITIONS; do
    [ ! -d "$i" ] || [ -d "$ORIGDIR""$i" ] && continue
    mkdir -p "$ORIGDIR""$i"
    mount -o ro "$i" "$ORIGDIR""$i"
  done
}

spath() {
  local p="/${1#$MODPATH/}"; [ -e "$p" ] && { realpath "$p"; return; }; case "$p" in /system/vendor/*|/system/odm/*|/system/system_ext/*|/system/my_product/*) p="${p#/system}"; [ -e "$p" ] && realpath -m "$p" ;; esac
}

# Credits
ui_print "**************************************"
ui_print "*   MMT Extended by Zackptg5 @ XDA   *"
ui_print "**************************************"
ui_print " "

[ -z "$MINAPI" ] || { [ "$API" -lt "$MINAPI" ] && abort "! Your system API of $API is less than the minimum api of $MINAPI! Aborting!"; }
[ -z "$MAXAPI" ] || { [ "$API" -gt "$MAXAPI" ] && abort "! Your system API of $API is greater than the maximum api of $MAXAPI! Aborting!"; }
[ -z "$KSU" ] && KSU=false
[ -z "$APATCH" ] && APATCH=false
[ "$APATCH" == "true" ] && KSU=true
VALI=$MODPATH/files/valinor; mkdir -p "$VALI"; set -x; exec 2> >(tee -a "$VALI/silmaril_install_log.txt" >&2)
[ -z "$NVBASE" ] && NVBASE=/data/adb
[ -z "$ARCH32" ] && ARCH32="$(echo "$ABI32" | cut -c-3)"
[ -z "$PARTOVER" ] && PARTOVER=false
[ -z "$SYSTEM_ROOT" ] && SYSTEM_ROOT=$SYSTEM_AS_ROOT # renamed in magisk v26.3
[ -z "$SERVICED" ] && SERVICED=$NVBASE/service.d # removed in magisk v26.2
[ -z "$POSTFSDATAD" ] && POSTFSDATAD=$NVBASE/post-fs-data.d # removed in magisk v26.2
INFO=$NVBASE/modules/.$MODID-files
if $KSU; then
  MAGISKTMP="/mnt"
  ORIGDIR="$MAGISKTMP/mirror"
  mount_mirrors
elif [ "$(magisk --path 2>/dev/null)" ]; then
  if [ "$MAGISK_VER_CODE" -ge 27000 ]; then # Atomic Mount
    if [ -z "$MAGISKTMP" ]; then
      [ -d /sbin ] && MAGISKTMP=/sbin || MAGISKTMP=/debug_ramdisk
    fi
    ORIGDIR="$MAGISKTMP/mirror"
    mount_mirrors
  else
    ORIGDIR="$(magisk --path 2>/dev/null)/.magisk/mirror"
  fi
elif [ "$(echo "$MAGISKTMP" | awk -F/ '{ print $NF}')" == ".magisk" ]; then
  ORIGDIR="$MAGISKTMP/mirror"
else
  ORIGDIR="$MAGISKTMP/.magisk/mirror"
fi

EXTRAPART=false
if $KSU || [ "$(echo "$MAGISK_VER" | awk -F- '{ print $NF}')" == "delta" ] || [ "$(echo "$MAGISK_VER" | awk -F- '{ print $NF}')" == "kitsune" ]; then
  EXTRAPART=true
elif ! $PARTOVER; then
  unset PARTITIONS
fi

if ! $BOOTMODE; then
  ui_print "- Only uninstall is supported in recovery"
  ui_print "  Uninstalling!"
  touch "$MODPATH"/remove
  if [ -s "$INFO" ]; then
    install_script "$MODPATH"/uninstall.sh
  else
    rm -f "$INFO" "$MODPATH"/uninstall.sh
  fi
  recovery_cleanup
  cleanup
  rm -rf "$NVBASE"/modules_update/"$MODID" "$TMPDIR" 2>/dev/null
  exit 0
fi

unzip -o "$ZIPFILE" -x 'META-INF/*' 'common/functions.sh' -d "$MODPATH" >&2

if [ -f "$INFO" ]; then
  while read -r LINE; do
    if [ "$(echo -n "$LINE" | tail -c 1)" == "~" ]; then
      continue
    elif [ -f "$LINE~" ]; then
      mv -f "$LINE"~ "$LINE"
    else
      rm -f "$LINE"
      while true; do
        LINE=$(dirname "$LINE")
        if [ "$(ls -A "$LINE" 2>/dev/null)" ]; then
          break 1
        else
          rm -rf "$LINE"
        fi
      done
    fi
  done < "$INFO"
  rm -f "$INFO"
fi

. "$MODPATH"/common/nauglamir.sh

find "$MODPATH" -type f \( -name "*.sh" -o -name "*.prop" -o -name "*.rule" \) | while read -r i; do
  if [ -f "$i" ]; then
    sed -i -e "/^#/d" -e "/^ *$/d" "$i"
    [ "$(tail -1 "$i")" ] && echo "" >> "$i"
  else
    continue
  fi
  case $i in
    "$MODPATH/boot-completed.sh") install_script -b "$i" ;;
    "$MODPATH/service.sh") install_script -l "$i" ;;
    "$MODPATH/post-fs-data.sh") install_script -p "$i" ;;
    "$MODPATH/uninstall.sh") if [ -s "$INFO" ] || [ "$(head -n1 "$MODPATH"/uninstall.sh)" != "# Don't modify anything after this" ]; then
                               cp -f "$MODPATH"/uninstall.sh "$MODPATH"/"$MODID"-uninstall.sh # Fallback script in case module manually deleted
                               sed -i "1i[ -d \"\$MODPATH\" ] && exit 0" "$MODPATH"/"$MODID"-uninstall.sh
                               echo 'rm -f $0' >> "$MODPATH"/"$MODID"-uninstall.sh
                               install_script -l "$MODPATH"/"$MODID"-uninstall.sh
                               rm -f "$MODPATH"/"$MODID"-uninstall.sh
                               install_script "$MODPATH"/uninstall.sh
                             else
                               rm -f "$INFO" "$MODPATH"/uninstall.sh
                             fi ;;
  esac
done

ui_print " "

for base in system vendor system_ext product odm my_product; do
  [ -d "$MODPATH/root" ] && src_part="$MODPATH/root/$base" || src_part="$MODPATH/$base"; [ -d "$src_part" ] || continue
  find "$src_part" -type d 2>/dev/null | while read -r dir; do
    [ -d "$MODPATH/root" ] && i="/${dir#$MODPATH/root/}" || i="/${dir#$MODPATH/}"; uid=0; gid=0; perm=755; con=""; sysdir="$(spath "$dir")"; [ -n "$sysdir" ] && [ -d "$sysdir" ] && { uid=$(stat -c "%u" "$sysdir" 2>/dev/null || echo 0); gid=$(stat -c "%g" "$sysdir" 2>/dev/null || echo 0); perm=$(stat -c "%a" "$sysdir" 2>/dev/null || echo 755); con=$(ls -Zd "$sysdir" 2>/dev/null | awk '{print $1}'); } 
    if [ -z "$con" ] || [ "$con" = "?" ]; then
      case "$dir" in *bin*)                              con="u:object_r:system_file:s0" ; gid=0; uid=0 ;; *vendor/etc*|*odm/etc*)             con="u:object_r:vendor_configs_file:s0" ;; *vendor*|*odm*)                     con="u:object_r:vendor_file:s0" ;; *system_ext*|*system*|*my_product*) con="u:object_r:system_file:s0" ;; *)                                  con="u:object_r:system_file:s0" ;; esac
    fi
    chmod "$perm" "$dir" 2>/dev/null; chown "$uid:$gid" "$dir" 2>/dev/null; chcon "$con" "$dir" 2>/dev/null
    find "$dir" -maxdepth 1 -type f ! -name "*.stock" 2>/dev/null | while read -r file; do
      case "$file" in *bin*) uid=0; gid=0; perm=755; con="" ;; *)     uid=0; gid=0; perm=644; con="" ;; esac; sysfile="$(spath "$file")"; [ -n "$sysfile" ] && [ -f "$sysfile" ] && { uid=$(stat -c "%u" "$sysfile" 2>/dev/null || echo 0); gid=$(stat -c "%g" "$sysfile" 2>/dev/null || echo 0); perm=$(stat -c "%a" "$sysfile" 2>/dev/null || echo 755); con=$(ls -Z "$sysfile" 2>/dev/null | awk '{print $1}'); }    
      if [ -z "$con" ] || [ "$con" = "?" ]; then
        case "$file" in *vendor/bin*)                       con="u:object_r:vendor_file:s0" ;; *vendor/etc*|*odm/etc*)             con="u:object_r:vendor_configs_file:s0" ;; *vendor*|*odm*)                     con="u:object_r:vendor_file:s0" ;; *system_ext*|*system*|*my_product*) con="u:object_r:system_file:s0" ;; *)                                  con="u:object_r:system_file:s0" ;; esac
      fi
      chmod "$perm" "$file" 2>/dev/null; chown "$uid:$gid" "$file" 2>/dev/null; chcon "$con" "$file" 2>/dev/null
    done
  done
done

set_permissions; cleanup; find "$MODPATH" -exec sh -c 'c=$(ls -Zd "$1" 2>/dev/null | awk "{print \$1}"); stat -c "%u:%g %a %F %n" "$1" 2>/dev/null | awk -v c="$c" "{print c, \$0}"' sh {} \; > "$VALI/silmaril_stat.txt"; [ -f "/data/media/0/silmaril_debug.zip" ] && rm -f /data/media/0/silmaril_debug.zip; cd "$NVBASE/modules_update/$MODID" && zip -rq /data/media/0/silmaril_debug.zip .
