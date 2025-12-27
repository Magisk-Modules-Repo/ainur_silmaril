#!/system/bin/sh
AMLMODPATH=$MODPATH
MODPATH=$mod
[ -z "$NVBASE" ] && NVBASE=/data/adb
AML=true
VALI=$mod/files/valinor
exec 2>"$VALI"/silmaril_aml_install_log.txt; set -x

alias sed="$VALI/tools/arm64/sed"
alias tinymix="$VALI/tools/arm64/tinymix"
alias xmlstarlet="$VALI/tools/arm64/xmlstarlet"

MODID=<MODID>
PARTITIONS="/system /vendor /odm /my_product"

#ui_print() { :; } # Do not need to actually print during aml
abort() { :; } # Keep going

# MMT-Ex needed stuff
INFO=$mod/.$MODID-files
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
    install -D -m "$PERM" "$OFILE" "$FILE"
  done
}

. "$mod"/files/nauglamir.sh

MODPATH=$AMLMODPATH