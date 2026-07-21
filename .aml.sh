#!/system/bin/sh
AMLMODPATH=$MODPATH
MODPATH=$mod
AML=true
VALI=$mod/files/valinor
set -x; exec 2> >(tee -a "$VALI/silmaril_aml_install_log.txt" >&2)

alias sed="$VALI/tools/arm64/sed"
alias tinymix="$VALI/tools/arm64/tinymix"
alias xmlstarlet="$VALI/tools/arm64/xmlstarlet"

MODID=<MODID>
PARTITIONS="/system /vendor /odm /system_ext"

#ui_print() { :; } # Do not need to actually print during aml
abort() { :; } # Keep going

# MMT-Ex needed stuff
INFO=$mod/.$MODID-files

. "$mod"/files/nauglamir.sh

cp -f "$VALI"/silmaril_aml_install_log.txt /data/media/0/silmaril_aml_install_log.txt

MODPATH=$AMLMODPATH