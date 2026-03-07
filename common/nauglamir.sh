##########################################################################################
#
# Ainur Installation Script
#
##########################################################################################
soc_sku() {
  local val
  for prop in ro.vendor.qti.soc_name ro.boot.product.vendor.sku ro.product.board ro.board.platform; do
    val=$(getprop $prop); [ -n "$val" ] && echo "$val" && return
  done
}
soc_plat() {
  local val
  for prop in ro.soc.model ro.vendor.qti.soc_model; do
    val=$(getprop $prop); [ -n "$val" ] && echo "$val" && return
  done
}
soc() {
  local val
  for prop in ro.soc.manufacturer ro.soc.model ro.boot.hardware; do
    val=$(getprop $prop); [ -n "$val" ] && echo "$val" && return
  done
}
append() {
  for i in "$@"; do
    [[ "$i" == persist.* ]] && echo "$i" >> "$PERPROP" || echo "$i" >> "$SYSPROP"
  done
}
perf() {
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -w "$cpu/cpufreq/scaling_governor" ] && echo "performance" > "$cpu/cpufreq/scaling_governor"
  done
}
nerf() {
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -w "$cpu/cpufreq/scaling_governor" ] && echo "schedutil" > "$cpu/cpufreq/scaling_governor"
  done
}
rpath() {
  local mode="$1"; shift
  local exp=
  [ "$1" = "-x" ] && exp="$2" && shift 2
  case "$mode" in
    -f) awk -v parts="/vendor $PARTITIONS" -v excl="$exp" 'BEGIN{split(excl,e," ");for(i in e)ex[e[i]]=1;split(parts,p," ");for(i in p)if(!ex[p[i]])submap["^"p[i]]="/system"p[i]}{for(pat in submap)if(match($0,pat)){$0=gensub(pat,submap[pat],1);break}print}' ;;
    -n) awk -v parts="$PARTITIONS" -v excl="$exp" 'BEGIN{split(excl,e," ");for(i in e)ex[e[i]]=1;split(parts,p," ");for(i in p)if(!ex[p[i]])submap["^"p[i]]="/system"p[i]}{for(pat in submap)if(match($0,pat)){$0=gensub(pat,submap[pat],1);break}print}' ;;
  esac
}
format_file() {
    expand -t 2 "$1" > "$1.tmp" && mv -f "$1.tmp" "$1"
}
detect_root() {
  [ -n "$KSU" ] && [ -n "$KSU_NEXT" ] && ROOT_MODE=KSUN && return 0; [ -n "$KSU" ] && [ -z "$KSU_NEXT" ] && ROOT_MODE=KSU && return 0; [ -n "$(find /data/app/ -type f -name "libzako*.so")" ] && SUSFS=true && ROOT_MODE=KSU && return 0; [ -d /data/adb/magisk ] && { ROOT_MODE=MAG; [ "$(echo "$MAGISK_VER" | awk -F- '{print $NF}')" = "kitsune" ] && ROOT_MODE=MAG_K && return 0; [ "$(echo "$MAGISK_VER" | awk -F- '{print $NF}')" = "delta" ] && ROOT_MODE=MAG_D && return 0; }
}
nest() {
  OFILE="$1"; FILE="${MODPATH%/}$(echo "$OFILE" | rpath -f -x "/my_product")"
}
detect_root; perf; renice -n -15 -p $$; ionice -c 1 -n 0 -p $$; trap nerf EXIT
soc_ven() {
  local name print_name lib_patterns
  local vendors=$'MTK:Mediatek:vendor.mediatek*.so\nQCP:Qualcomm:vendor.qti*.so|com.qualcomm*.so\nEXY:Exynos:libExynos*.so\nTENZ:Tensor:gxp*.so|audio.primary.gs*.so|aoc_*.so'
  local IFS=$'\n'
  for vendor in $vendors; do
    name=$(echo "$vendor" | cut -d':' -f1); print_name=$(echo "$vendor" | cut -d':' -f2); lib_patterns=$(echo "$vendor" | cut -d':' -f3-); local pattern; local OLD_IFS=$IFS; IFS='|'
    for pattern in $lib_patterns; do
      if find /system/lib* /system_ext/lib* /vendor/lib* /odm/lib* /my_product/lib* -maxdepth 1 -type f -name "$pattern" 2>/dev/null | grep -q .; then
        eval "${name}='$print_name'"; break
      fi
    done
    IFS=$OLD_IFS
  done
}
process_uo() {
  if [ "$1" = "-u" ]; then
    tr -d '\r' < "$AUO" > "$AUO.tmp" && mv -f "$AUO.tmp" "$AUO"
  else
    . "$AUO"
  fi
  while IFS= read -r UO; do
    if [ "$1" = "-u" ]; then
      eval "$UO=$(grep_prop "$UO" "$AUO")"; sed -i "s|^$UO=.*|$UO=$(eval echo \$"$UO")|" "$MODPATH/silmaril_useroptions"; cp -f "$MODPATH/silmaril_useroptions" "$AUO"
    else
    case "$UO" in Q_*) [ -z "$QCP" ] && eval "$UO=" ;; M_*) [ -z "$MTK" ] && eval "$UO=" ;; T_*) [ -z "$TENZ" ] && eval "$UO=" ;; E_*) [ -z "$EXY" ] && eval "$UO=" ;; esac
    case "$UO" in
      U_VSTP | RQ | U_HL | U_SBA | U_APFF | U_MANUAL_KEEPFX | Q_AGA | Q_HDGA | Q_SDGA | Q_HDSPBW | Q_DSPOD | Q_FBUF | T_FBUF | E_CSMPL | M_IMP | M_GAIN)
        case "$(eval echo \$"$UO" | tr '[:upper:]' '[:lower:]')" in
          " "*) eval "$UO=" ;; *db) eval "$UO=\"$(eval echo \"\$$UO\" | awk '{gsub(/db/, \"Db\"); print}')\"" ;; *khz) eval "$UO=\"$(eval echo \"\$$UO\" | awk '{gsub(/khz/, \"kHz\"); print}')\"" ;;
        esac ;;
      Q_CSMPL | Q_BTCSMPL | Q_CBIT | Q_BTCBIT | T_CSMPL | T_CBTSMPL | T_CBIT | T_CBTBIT)
        case "$(eval echo \$"$UO" | tr '[:lower:]' '[:upper:]')" in
          " "*) eval "$UO=" ;;
        esac ;;
      *)
        case "$(eval echo \$"$UO" | tr '[:upper:]' '[:lower:]')" in
          "true" | "1") eval "$UO=true" ;; *) eval "$UO=" ;;
        esac ;;
    esac
    case "$UO" in
      U_VSTP)
        if [ -n "$U_VSTP" ]; then
          if [ "$U_VSTP" -gt 100 ]; then
            ui_print " "; ui_print "   ⨠U_VSTP error: $U_VSTP is beyond max 100 steps range!"; ui_print "     Setting volume slider steps to 100"
          else
            ui_print " "; ui_print "   >U_VSTP: Setting volume slider steps to $U_VSTP"
          fi
        fi
      ;;
      U_HL)
        if [ -n "$U_HL" ]; then
          ui_print " "; ui_print "   >U_HL: Half Length set to $U_HL"; [ "$U_HL" -ge 960 ] && ui_print "    $U_HL might be too high for some devices!"
        fi
      ;;
      U_SBA)
        if [ -n "$U_SBA" ]; then
          if [ "$U_SBA" -gt 144 ]; then
            ui_print " "; ui_print "   ⨠U_SBA: stopband attenuation can't go above 144dB!"; ui_print "    Setting attenuation to a maximum of 144dB"
          else
            ui_print " "; ui_print "   >U_SBA: Stopband attenuation set to $U_SBA"
          fi
        fi
      ;;
      U_ESTV)
        [ -n "$U_ESTV" ] && { ui_print " "; ui_print "   >U_ESTV: Setting equal stereo speaker volume"; }
      ;;
      U_APFF)
        if [ -n "$U_APFF" ]; then
          if [ "$U_APFF" == "add" ]; then
            ui_print " "; ui_print "   >U_APFF: Adding floating point format"
          elif [ "$U_APFF" == "force" ]; then
            ui_print " "; ui_print "   >U_APFF: Forcing floating point format"
          fi
        fi
      ;;
      U_APDBR)
        [ -n "$U_APDBR" ] && { ui_print " "; ui_print "   >U_APDBR: Removing deepbuffer output"; }
      ;;
      U_AAEM)
        [ -n "$U_AAEM" ] && { ui_print " "; ui_print "   >U_AAEM: Setting AAudio mode to exclusive"; }
      ;;
      U_BTDAO)
        [ -n "$U_BTDAO" ] && { ui_print " "; ui_print "   >U_BTDAO: Disabling bluetooth HW Offload"; }
      ;;
      U_BTDAV)
        [ -n "$U_BTDAV" ] && { ui_print " "; ui_print "   >U_BTDAV: Disabling bluetooth absolute volume"; }
      ;;
      U_SDRC)
        if [ -n "$U_SDRC" ]; then
          if strings "$APMD64" 2>/dev/null | grep -q 'speaker_drc_enabled' || strings "$APMD" 2>/dev/null | grep -q 'speaker_drc_enabled'; then
            ui_print " "; ui_print "   >U_SDRC: Disabling speaker DRC"; export U_SDRC_PROCEED=true
          else
            ui_print " "; ui_print "   ⨠U_SDRC error: Device doesn't support speaker DRC switch!"; export U_SDRC_PROCEED=
          fi
        fi
      ;;
      D_PROPS)
        [ -n "$D_PROPS" ] && { ui_print " "; ui_print "   [DEBUG MODE] SKIPPING PROPS"; }
      ;;
      D_MIXERS)
        [ -n "$D_MIXERS" ] && { ui_print " "; ui_print "   [DEBUG MODE] SKIPPING MIXERS"; }
      ;;
      D_LIBS)
        [ -n "$D_LIBS" ] && { ui_print " "; ui_print "   [DEBUG MODE] SKIPPING LIBS"; }
      ;;
    esac
    case "$SOCP" in
      Qualcomm)
        case "$UO" in 
          Q_CSMPL)
            if [ -z "$Q_CSMPL" ]; then
                export Q_CSMPL_PROCEED=
            else
              case "$Q_CSMPL" in KHZ_44P1|KHZ_48|KHZ_96|KHZ_88P2|KHZ_176P4|KHZ_192|KHZ_352P8|KHZ_384)
                ui_print " "; ui_print "   >Q_CSMPL: Setting codec samplerate to $Q_CSMPL"; export Q_CSMPL_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠Q_CSMPL error: Setting is incorrect !"; ui_print "    input value can't be $Q_CSMPL !"
              ;;
              esac
            fi
          ;;
          Q_CBIT)
            if [ -z "$Q_CBIT" ]; then
                export Q_CBIT_PROCEED=
            else
              case "$Q_CBIT" in S16_LE|S24_LE|S24_3LE|S32_LE)
                ui_print " "; ui_print "   >Q_CBIT: Setting codec format to $Q_CBIT"; export Q_CBIT_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠Q_CBIT error: Setting is incorrect !"; ui_print "    input value can't be $Q_CBIT !"
              ;;
              esac
            fi
          ;;
          Q_BTCSMPL)
            if [ -z "$Q_BTCSMPL" ]; then
                export Q_BTCSMPL_PROCEED=
            else
              case "$Q_BTCSMPL" in KHZ_44P1|KHZ_48|KHZ_96)
                ui_print " "; ui_print "   >Q_BTCSMPL: Setting codec BT samplerate to $Q_BTCSMPL"; export Q_BTCSMPL_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠Q_BTCSMPL error: Setting is incorrect !";  ui_print "    input value can't be $Q_BTCSMPL !"
              ;;
              esac
            fi
          ;;
          Q_AGA)
            if [ -z "$Q_AGA" ]; then
                export Q_AGA_PROCEED=
            else
              if [ "$Q_AGA" -gt "$MAXAG" ]; then
                ui_print " "; ui_print "   ⨠Q_AGA error: Setting is incorrect !"; ui_print "    input value can't exceed $MAXAG !"
              else
                ui_print " "; ui_print "   >Q_AGA: Setting codec analog gain to $Q_AGA"
              fi
            fi
          ;;
          Q_HDGA)
             if [ -z "$Q_HDGA" ]; then
                export Q_HDGA_PROCEED=
            else
              if [ "$Q_HDGA" -gt 124 ]; then
                ui_print " "; ui_print "   ⨠Q_HDGA error: Setting is incorrect !"; ui_print "    input value can't exceed 124 !"
              else
                ui_print " "; ui_print "   >Q_HDGA: Setting headphone digital gain to $Q_HDGA"
              fi
            fi
          ;;
          Q_SDGA)
            if [ -z "$Q_SDGA" ]; then
                export Q_SDGA_PROCEED=
            else
              if [ "$Q_SDGA" -gt 124 ]; then
                ui_print " "; ui_print "   ⨠Q_SDGA error: Setting is incorrect !"; ui_print "    input value can't exceed 124 !"
              else
                ui_print " "; ui_print "   >Q_SDGA: Setting headphone digital gain to $Q_SDGA"
              fi
            fi
          ;;
          Q_DSPOD)
            if [ -n "$Q_DSPOD" ]; then
              if [ "$Q_DSPOD" == "disable" ]; then
                ui_print " "; ui_print "   >Q_DSPOD: Force disabling DSP offload"
              elif [ "$Q_DSPOD" == "enable" ]; then
                ui_print " "; ui_print "   >Q_DSPOD: Force enabling DSP offload"
              fi
            fi
          ;;
          Q_FBUF)
            if [ -n "$Q_FBUF" ]; then
              if [ "$Q_FBUF" == "frames" ]; then
                ui_print " "; ui_print "   >Q_FBUF: Frame buffer set for higher frames"
              elif [ "$Q_FBUF" == "latency" ]; then
                ui_print " "; ui_print "   >Q_FBUF: Frame buffer set for lower latency"
              fi
            fi
          ;;
          Q_HDSPBW)
            [ -n "$Q_HDSPBW" ] && { ui_print " "; ui_print "   >Q_HDSPBW: DSP bitwidth set to $Q_HDSPBW"; ui_print "    Might be buggy/bootloop on some devices !"; }
          ;;
          Q_HCOMP)
            [ -n "$Q_HCOMP" ] && { ui_print " "; ui_print "   >Q_HCOMP: Disabling hph compander"; }
          ;;
          Q_SCOMP)
            [ -n "$Q_SCOMP" ] && { ui_print " "; ui_print "   >Q_SCOMP: Disabling spk compander"; }
          ;;
          Q_MBDRC)
            [ -n "$Q_MBDRC" ] && { ui_print " "; ui_print "   >Q_MBDRC: Disabling Multi-bandDRC"; }
          ;;
          Q_CPGD)
            if [ -n "$Q_CPGD" ];then
              if [ -n "$QDCCE" ]; then
                ui_print " "; ui_print "   >Q_CPGD: Disabling codec power gating"
              else
                ui_print " "; ui_print "   ⨠Q_CPGD error: this device doesn't support"; ui_print "    codec power gating !"
              fi
            fi
          ;;
          Q_LGHIM)
            if [ "$OEM" == "LG" ] && [ -n "$Q_LGHIM" ] ; then
              if [ -n "$QMFAM" ]; then
                ui_print " "; ui_print "   >Q_LGHIM: Setting ESS high impedance mode"
              else
                ui_print " "; ui_print "   ⨠Q_LGHIM error: this device doesn't support"; ui_print "    high impedance mode !"
              fi
            fi
          ;;
        esac
      ;;
      Tensor)
        case "$UO" in 
          T_CSMPL)
            if [ -z "$T_CSMPL" ]; then
                export T_CSMPL_PROCEED=
            else
              case "$T_CSMPL" in  SR_44P1K|SR_48K|SR_88P2K|SR_96K|SR_176P4K|SR_192K)
                ui_print " "; ui_print "   >T_CSMPL: Setting codec samplerate to $T_CSMPL"; export T_CSMPL_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠T_CSAMPL error: Setting is incorrect !"; ui_print "    input value can't be $T_CSMPL !"
              ;;
              esac
            fi
          ;;
          T_CBIT)
            if [ -z "$T_CBIT" ]; then
                export T_CBIT_PROCEED=
            else
              case "$T_CBIT" in S16_LE|S24_LE|S24_3LE|S32_LE)
                ui_print " "; ui_print "   >T_CBIT: Setting codec format to $T_CBIT"; export T_CBIT_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠T_CBIT error: Setting is incorrect !"; ui_print "    input value can't be $T_CBIT !"
              ;;
              esac
            fi
          ;;
          T_CBTSMPL)
            if [ -z "$T_CBTSMPL" ]; then
                export T_CBTSMPL_PROCEED=
            else
              case "$T_CBTSMPL" in SR_44P1K|SR_48K|SR_88P2K|SR_96K|SR_176P4K|SR_192K)
                ui_print " "; ui_print "   >T_CBTSMPL: Setting codec BT samplerate to $T_CBTSMPL"; export T_CBTSMPL_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠T_CBTSAMPL error: Setting is incorrect !"; ui_print "    input value can't be $T_CBTSMPL !"
              ;;
              esac
            fi
          ;;
          T_CBTBIT)
            if [ -z "$T_CBTBIT" ]; then
              export T_CBTBIT_PROCEED=
            else
              case "$T_CBTBIT" in S16_LE|S24_LE|S24_3LE|S32_LE)
                ui_print " "; ui_print "   >T_CBTBIT: Setting codec format to $T_CBTBIT"; export T_CBTBIT_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠T_CBTBIT error: Setting is incorrect !"; ui_print "    input value can't be $T_CBTBIT !"
              ;;
              esac
            fi
          ;;
          T_FBUF)
            if [ -n "$T_FBUF" ]; then
              if [ "$T_FBUF" == "frames" ]; then
                ui_print " "; ui_print "   >T_FBUF: Frame buffer set for higher frames"
              elif [ "$T_FBUF" == "latency" ]; then
                ui_print " "; ui_print "   >T_FBUF: Frame buffer set for lower latency"
              fi
            fi
          ;;
        esac
      ;;
      Mediatek)
        case "$UO" in 
          M_GAIN)
            if [ -z "$M_GAIN" ]; then
              export M_GAIN_PROCEED=
            else
              case "$M_GAIN" in -40Db|-10Db|-9Db|-8Db|-7Db|-6Db|-5Db|-4Db|-3Db|-2Db|-1Db|0Db|1Db|2Db|3Db|4Db|5Db|6Db|7Db|8Db)
                ui_print " "; ui_print "   >M_GAIN: Setting gain to $M_GAIN"; export M_GAIN_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠M_GAIN error: Setting is incorrect !"; ui_print "    input value can't be $M_GAIN !"
              ;;
              esac
            fi
          ;;
          M_COFF)
            [ -n "$M_COFF" ] && [ "$M_COFF" == "enable" ] && { ui_print " "; ui_print "   >M_COFF: Disabling coden USB offload"; }
          ;;
          M_DHPF)
            [ -n "$M_DHPF" ] && { ui_print " "; ui_print "   >M_DHPF: Disabling High-pass filter"; }
          ;;
          M_IMP)
            [ -n "$M_IMP" ] && { ui_print " "; ui_print "   >M_IMP: Setting codec impedance to $M_IMP"; }
          ;;
          M_DRC)
            [ -n "$M_DRC" ] && { ui_print " "; ui_print "   >M_DRC: Disabling SFX DRC"; }
          ;;
        esac
      ;;
      Exynos)
        case "$UO" in 
          E_CSMPL)
            if [ -z "$E_CSMPL" ]; then
              export E_CSMPL_PROCEED=
            else
              case "$E_CSMPL" in 44.1kHz|48kHz|88.2kHz|96kHz|176.4kHz|192kHz)
                ui_print " "; ui_print "   >E_CSMPL: Setting gain to $E_CSMPL"; export E_CSMPL_PROCEED=true
              ;;
              *)
                ui_print " "; ui_print "   ⨠E_CSMPL error: Setting is incorrect !"; ui_print "    input value can't be $E_CSMPL !"
              ;;
              esac
            fi
          ;;
        esac
      ;;
    esac
    fi
  done < <(awk -F= '/^[A-Z_]+=/ && !/^#/ && !/UVER/ {print $1}' "$AUO")
}
pfind() {
  local sdir="$1"; echo "/system/$sdir /vendor/$sdir $(echo "$PARTITIONS" | sed "s|\([^ ]*\)|\1/$sdir|g")"
}
patch_xml() {
  local NAME NAMEC VAL VALC SNP NP SN
  NAME="$(echo "$3" | awk -F'[@"]' '{print $(NF-1)}')"; NAMEC="$(echo "$3" | awk -F'[@=]' '{print $2}')"; VAL="$(echo "$4" | awk -F'=' '{print $NF}')"
  if echo "$4" | grep -q '='; then
    VALC="$(echo "$4" | awk -F'=' '{print $1}')"
  else
    VALC="value"
  fi
  case "$1" in
    "-d") xmlstarlet ed -L -d "$3" "$2" ;;
    "-u") xmlstarlet ed -L -u "$3/@$VALC" -v "$VAL" "$2" ;;
    "-s") 
      if [ "$(xmlstarlet sel -t -m "$3" -c . "$2")" ]; then
          xmlstarlet ed -L -u "$3/@$VALC" -v "$VAL" "$2"
      else
        SNP="$(echo "$3" | awk '{ sub(/\[@[^=]+="[^"]*"\]$/, "", $0); print }')"; NP="$(dirname "$SNP")"; SN="$(basename "$SNP")"; xmlstarlet ed -L -s "$NP" -t elem -n "$SN-$MODID" -i "$SNP-$MODID" -t attr -n "$NAMEC" -v "$NAME" -i "$SNP-$MODID" -t attr -n "$VALC" -v "$VAL" -r "$SNP-$MODID" -v "$SN" "$2"
      fi ;;
  esac
}
purge() { 
  unset FILE OFILE OFILES
}
[ -z "$AML" ] && AML=false; MODVER="$(grep_prop version "$MODPATH"/module.prop)"; SYSPROP="$MODPATH"/system.prop; PERPROP="$MODPATH"/persist.prop; mktouch "$PERPROP"; POSTFS="$MODPATH"/post-fs-data.sh; SERV="$MODPATH"/service.sh; BUILDS="$VALI/builds.txt"; mktouch "$BUILDS"; getprop 2>/dev/null | awk -F': ' '{gsub(/^\[|\]$/, "", $1); gsub(/^\[|\]$/, "", $2); print $1 "=" $2}' > "$BUILDS"; soc_ven; SOC_SKU="$(soc_sku)"; SOC_PLAT="$(soc_plat)"; CORC="$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1)"; [ "$CORC" -gt 8 ] && CORC=8
for entry in "Asus vendor.asus.*.so libasus*.so" "Google vendor.google.*.so libgoog_*.so libg3a_*.so" "LG vendor.lg.*.so liblg_*.so" "ZTE vendor.zte.*.so libzte*.so" "Xiaomi vendor.xiaomi.*.so libxiaomi*.so libcom.xiaomi*.so" "Oneplus vendor.oplus.*.so liboplus*.so" "Nothing libcam_nothing.so com.nothing.*.so" "Sony vendor.semc.*.so vendor.somc.*.so libsomc_*.so" "Motorola motorola.hardware.*.so com.motorola.*.so" "Samsung vendor.samsung*.so lib*.samsung.so"; do
  brand=${entry%% *}; lpatterns=${entry#* }
  for lpattern in $lpatterns; do
    if find /system/lib* /system_ext/lib* /vendor/lib* /odm/lib* /my_product/lib* -maxdepth 3 -type f -name "$lpattern" 2>/dev/null | head -n1 | grep -q .; then
      OEM=$brand; break 2
    fi
  done
done
[ -n "$TENZ" ] && OEM=Pixel; [ -z "$OEM" ] && OEM="$(getprop ro.product.odm.brand)"
for socprint in QCP MTK EXY TENZ; do
  eval "val=\${$socprint}"
  if [ -n "$val" ]; then
    SOCP="$val"; break
  fi
done
if [ -d "$NVBASE"/modules/ainur_sauron ]; then
  ui_print " "; ui_print "! AINUR SAURON detected!"; abort "! Uninstall Sauron first!"
elif [ -d "$NVBASE"/modules/ainur_narsil ]; then
  ui_print " "; ui_print "! AINUR NARSIL detected!"; abort "! Uninstall Narsil first!"
fi
V20="$(grep "ro.product.device=elsa" "$BUILDS")"; V30="$(grep "ro.product.device=joan" "$BUILDS")"; G6="$(grep "ro.product.device=lucye" "$BUILDS")"; G7="$(grep "ro.product.device=judyln" "$BUILDS")"; rog5="$(grep -E "ro.product.vendor.model=ASUS_I005.*" "$BUILDS")"; WAVL="$(pm list packages | grep "com.pittvandewitt.wavelet")"; AUO=/storage/emulated/0/silmaril_useroptions; VETC=/system/vendor/etc; CFGS="$(find $(pfind "etc") -maxdepth 3 -type f \( -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" \) ! -name "audio_effects_haptic.xml"  2>/dev/null)"; POLS="$(find $(pfind "etc") -maxdepth 3 -type f -name "*audio_*policy*.xml" ! -name "*volumes*" ! -name "*engine*" ! -name "*r_submix*" ! -name "*a2dp_in*" 2>/dev/null)"; MIXS="$(find $(pfind "etc") -maxdepth 3 -type f -name "mixer_paths*.xml" 2>/dev/null)"; MIXNUM="$(echo "$MIXS" | wc -w)"; APMD="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libaudiopolicymanagerdefault.so")"; APMD64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libaudiopolicymanagerdefault.so")"; APED="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libaudiopolicyenginedefault.so")"; APED64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libaudiopolicyenginedefault.so")"; AFLN="$(find /system/lib -maxdepth 1 -type f -name "libaudioflinger.so")"; AFLN64="$(find /system/lib64 -maxdepth 1 -type f -name "libaudioflinger.so")"
if ! $AML; then
  DVT="$(find $(pfind "etc") -maxdepth 3 -type f \( -name "default_volume_tables*.xml" -o -name "audio_policy_volumes*.xml" -o -name "audio_policy_engine_default_stream_volumes*.xml" -o -name "audio_policy_engine_stream_volumes*.xml" \) 2>/dev/null)"; ASERV="$(find /system/bin /vendor/bin -maxdepth 2 -type f \( -name "audioserver" -o -name "android.hardware.audio.service" -o -name "android.hardware.audio.service_64" -o -name "audiohalservice_qti" -o -name "android.hardware.audio.service-aidl.aoc" \) 2>/dev/null | sed 's|.*/||')"; ASERVRC="$(find $(pfind "etc/init") -type f \( -name "audioserver*.rc" -o -name "android.hardware.audio.service*.rc" -o -name "audiohalservice_qti.rc" -o -name "init.qcom.rc" \) 2>/dev/null)"; [ -n "$QCP" ] && [ -f "/vendor/bin/hw/audiohalservice.qti" ] && cat /proc/"$(pidof audiohalservice.qti)"/maps > "$VALI"/qhalservice.txt; cat /proc/"$(pidof audioserver)"/maps > "$VALI"/aserver.txt; A_PROCARCH="$(grep libaudioprocessing.so "$VALI"/aserver.txt | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; A_FLINARCH="$(grep libaudioflinger.so "$VALI"/aserver.txt | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; A_SPXARCH="$(grep libspeexresampler.so "$VALI"/aserver.txt | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"
  for serv in android.hardware.audio.service android.hardware.audio.service_64 android.hardware.audio.service-aidl.aoc; do
    if [ -f "/vendor/bin/hw/$serv" ]; then
      pid="$(pidof $serv)"; hwserv="$VALI/${serv}_${pid}.txt"; cat /proc/"$pid"/maps > "$hwserv"; A_SFX="$(grep soundfx "$hwserv" | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; A_FXL="$(grep libeffects.so "$hwserv" | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; A_ALSARCH="$(grep libalsautils.so "$hwserv" | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; [ -n "$QCP" ] && A_QVOLARCH="$(grep libvolumelistener.so "$hwserv" | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"; [ -n "$QCP" ] && A_QPHALARCH="$(grep "audio\.primary\..*\.so" "$hwserv" 2>/dev/null | head -n1 | awk '{ if ($6 ~ /lib64/) { print "64" } else if ($6 ~ /lib/) { print "32" } }')"
    fi
  done
  AUS="$(find /system/lib /vendor/lib -maxdepth 1 -type f \( -name "libalsautils.so" -o -name "libalsautilsv2.so" -o -name "libalsautils_sec.so" \))"; AUS64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f \( -name "libalsautils.so" -o -name "libalsautilsv2.so" -o -name "libalsautils_sec.so" \))"; ARS="$(find /system/lib -maxdepth 1 -type f -name "libaudio-resampler.so" -o -name "libaudioresampler.so")"; ARS64="$(find /system/lib64 -maxdepth 1 -type f -name "libaudio-resampler.so" -o -name "libaudioresampler.so")"; APS="$(find /system/lib -maxdepth 1 -type f -name "libaudioprocessing.so")"; APS64="$(find /system/lib64 -maxdepth 1 -type f -name "libaudioprocessing.so")"; SPX="$(find /system/lib* /vendor/lib* -maxdepth 1 -type f -name "libspeexresampler.so")"; APR="$(find /vendor/lib/soundfx -maxdepth 1 -type f -name "libaudiopreprocessing.so")"; APR64="$(find /vendor/lib64/soundfx -maxdepth 1 -type f -name "libaudiopreprocessing.so")"; AROUT="$(find /system/lib* /vendor/lib* /odm/lib* -maxdepth 1 -type f -name "libaudioroute*.so" 2>/dev/null)"; AHAENDK="$(find /system/lib64 -maxdepth 1 -type f -name "android.hardware.audio.effect-V.*-ndk.so")"; ACOSRV="$(find /system/lib64 /system_ext/lib64 /vendor/lib64 /odm/lib64 -maxdepth 1 -type f -name "com.android.media.audioserver-aconfig-cc.so")"; AMFC="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "aconfig_mediacodec_flags_c_lib.so")"; BTDEF="$(find /system/lib/hw /vendor/lib/hw -maxdepth 1 -type f -name "bluetooth.default.so")"; BTDEF64="$(find /system/lib64/hw /vendor/lib64/hw -maxdepth 1 -type f -name "bluetooth.default.so")"
  [ -n "$QCP" ] && {
    ACONF="$(find $(pfind "etc") -maxdepth 1 -type f -name "audio_configs*.xml" 2>/dev/null)"; RMA="$(find $(pfind "etc") -maxdepth 3 -type f -name "resourcemanager*.xml" 2>/dev/null)"; PWH="$(find $(pfind "etc") -maxdepth 1 -type f -name "powerhint*.xml" 2>/dev/null)"; APLIS="$(find $(pfind "etc") -maxdepth 1 -type f -name "audio_platform_info*.xml" 2>/dev/null)"; UKV="$(find $(pfind "etc") -maxdepth 3 -type f -name "usecaseKvManager*.xml" 2>/dev/null)"; KVH="$(find $(pfind "etc") -maxdepth 1 -type f -name "kvh2xml.xml" 2>/dev/null)"; BEC="$(find $(pfind "etc") -maxdepth 1 -type f -name "backend_conf*.xml" 2>/dev/null)"; AMCP="$(find $(pfind "etc") -maxdepth 3 -type f -name "audio_module_config_primary.xml" 2>/dev/null)"; VL="$(find /vendor/lib/soundfx -maxdepth 1 -type f -name "libvolumelistener.so")"; VL64="$(find /vendor/lib64/soundfx -maxdepth 1 -type f -name "libvolumelistener.so")"; AGMD="$(find /system/lib /system/lib64 /vendor/lib /vendor/lib64 /odm/lib /odm/lib64 -maxdepth 1 -type f -name "libagmdevice.so" 2>/dev/null)"; APAL="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libar-pal.so")"; APAL64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libar-pal.so")"; PHAL="$(find /vendor/lib/hw -maxdepth 1 -type f -name "audio.primary.*.so" ! -name "audio.primary.default.so")"; PHAL64="$(find /vendor/lib64/hw -maxdepth 1 -type f -name "audio.primary.*.so" ! -name "audio.primary.default.so")"; QHAL="$(find /vendor/lib64/hw -maxdepth 1 -type f -name "libaudiocorehal.qti.so")"; CMP64="$(find /system/lib64 -maxdepth 1 -type f -name "libcodec2_soft_mp3dec.so")"; FLA64="$(find /system/lib64 -maxdepth 1 -type f -name "libcodec2_soft_flacdec.so")"; SMP="$(find /vendor/lib -maxdepth 1 -type f -name "libstagefright_soft_mp3dec.so")"; PERFLO="$(find /system/lib64 /vendor/lib64 /odm/lib64 -maxdepth 1 -type f -name "libqti-perfd-client.so" 2>/dev/null)"; BTBUN="$(find /vendor/lib64 -maxdepth 1 -type f -name "lib_bt_bundle.so")"; QDCCE="$(find /sys/module -maxdepth 3 -name "*collapse_enable")"; QMFAM="$(find /sys/module -maxdepth 3 -name "*force_advanced_mode")"; QHPFM="$(find /sys/module -maxdepth 3 -name "*high_perf_mode")"; QSMAS="$(find /sys/module -maxdepth 3 -name "*maximum_substreams")"
  }
  [ -n "$TENZ" ] && {
    TPC="$(find $(pfind "etc")  -maxdepth 3 -type f -name "audio_platform_configuration.xml" 2>/dev/null)"; TCC="$(find $(pfind "etc")  -maxdepth 3 -type f -name "tuning_constraints_combination.xml" 2>/dev/null)"; TAOCF="$(find /vendor/lib64 -maxdepth 1 -type f -name "aoc_aconfig_flags_c_lib.so")"; TAFH3="$(find /vendor/lib64 -maxdepth 1 -type f -name "libAlgFx_HiFi3z.so")"
  }
  [ -n "$MTK" ] && {
    MIXA="$(find $(pfind "etc")  -maxdepth 3 -type f -name "*audio_device*.xml" 2>/dev/null)"; MPDRC="$(find $(pfind "etc")  -maxdepth 2 -type f -name "PlaybackDRC_AudioParam.xml" 2>/dev/null)"; MPLAT="$(find $(pfind "etc")  -maxdepth 1 -type f -name "audio_em.xml" 2>/dev/null)"; MAUP="$(find $(pfind "etc")  -maxdepth 2 -type f -name "AudioParamOptions*.xml" 2>/dev/null)"
  }
  [ -n "$EXY" ] && {
    SAPA="$(find $(pfind "etc")  -maxdepth 1 -type f -name "*sapa_feature*.xml" 2>/dev/null)"; MIXG="$(find $(pfind "etc")  -maxdepth 1 -type f -name "*mixer_gains*.xml" 2>/dev/null)"
  }
  [ "$OEM" == "Oneplus" ] && {
    OMD="$(find $(pfind "etc")  -maxdepth 2 -type f \( -name "Multimedia_Daemon_Ext*.xml" -o -name "Multimedia_Daemon_List*.xml" \) 2>/dev/null)"; OAF="$(find $(pfind "etc")  -maxdepth 2 -type f -name "oplus_audio_features.xml" 2>/dev/null)"
  }
  [ "$OEM" == "Xiaomi" ] && {
    MIR="$(find /vendor/lib -maxdepth 1 -type f -name "libresampler.so")"; MIR64="$(find /vendor/lib64 -maxdepth 1 -type f -name "libresampler.so")"
  }
  [ "$OEM" == "Sony" ] && {
    SDS="$(find /vendor/lib -maxdepth 1 -type f -name "libsonydseehxwrapper.so")"; SDS64="$(find /vendor/lib64 -maxdepth 1 -type f -name "libsonydseehxwrapper.so")"
  }
  [ "$OEM" == "Samsung" ] && {
    SSTP="$(find $(pfind "etc")  -maxdepth 1 -type f -name "stage_policy.conf" 2>/dev/null)"; SSB20="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "lib_SoundBooster_ver2060.so")"
  }  
  {
    SDAT="$(find /data/app -maxdepth 4 -type f \( -name "libumeng-spy.so" -o -name "libweibosdkcore.so" -o -name "libwind.so" \))"; FII="$(find /data/app -maxdepth 4 -type f -name "libhello-jni.so")"; FII2="$(find /data/app -maxdepth 4 -type f -name "libeqLib.so")"; UPP="$(find /data/app -maxdepth 4 -type f -name "libswresample-3.3.100.so")"; APPM="$(find /data/app -maxdepth 4 -type f -name "libicudata_sv_apple.so")"; POW="$(find /data/app -maxdepth 4 -type f -name "libffmpeg_neon.so")"; POW2="$(find /data/app -maxdepth 4 -type f -name "libpowerampcore.so")"; LUSB="$(find /data/app -maxdepth 4 -type f \( -name "libauusb.so" -o -name "libUsbAudio.so" -o -name "libusb.so" \))"
  }
  {
    HRDW="$(find /vendor/lib -maxdepth 1 -type f -name "libhardware*.so")"; HRDW64="$(find /vendor/lib64 -maxdepth 1 -type f -name "libhardware*.so")"; MEDU="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libmediautils*.so")"; MEDU64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libmediautils*.so")"; APM="$(find /system/lib -maxdepth 1 -type f -name "libaudiopolicymanager.so")"; APM64="$(find /system/lib64 -maxdepth 1 -type f -name "libaudiopolicymanager.so")"; APOLS="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libaudiopolicyservice.so")"; APOLS64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libaudiopolicyservice.so")"; AGM="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libagm.so")"; AGM64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libagm.so")"; BASQ="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libbluetooth_audio_session_qti_2_1.so")"; BASQ64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libbluetooth_audio_session_qti_2_1.so")"; BASAQ="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libbluetooth_audio_session_aidl_qti.so")"; BASAQ64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libbluetooth_audio_session_aidl_qti.so")"; BASA="$(find /system/lib /vendor/lib -maxdepth 1 -type f -name "libbluetooth_audio_session_aidl.so")"; BASA64="$(find /system/lib64 /vendor/lib64 -maxdepth 1 -type f -name "libbluetooth_audio_session_aidl.so")"
  }
  ! command -v xargs >/dev/null 2>&1 && CONFLCT="$(find "$NVBASE"/modules/* -mindepth 1 -maxdepth 4 -type f \( -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.xml" -o -name "mixer_paths*.xml" \) ! -path "$NVBASE/modules_update/$MODID/*" ! -path "$NVBASE/modules_update/*ainur_silmaril*" ! -path "$NVBASE/modules/$MODID/*" ! -path "$NVBASE/modules/*ainur_silmaril*" 2>/dev/null)" || CONFLCT="$(find "$NVBASE"/modules/ -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -P "$CORC" sh -c 'for dir; do find "$dir" -mindepth 1 -maxdepth 4 -type f \( -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_*policy*.xml" -o -name "mixer_paths*.xml" \) ! -path "$NVBASE/modules_update/$MODID/*" ! -path "$NVBASE/modules_update/*ainur_silmaril*" ! -path "$NVBASE/modules/$MODID/*" ! -path "$NVBASE/modules/*ainur_silmaril*"; done' sh)"
  if [ -n "$CONFLCT" ] && ! echo "$CONFLCT" | grep -q '/aml/'; then
    for CONFILE in $CONFLCT; do
      j="$(echo "$CONFILE" | awk -F / '{print $5}')"; echo "$cnfmod" | grep -qF "$j" || cnfmod="$j $cnfmod"
    done
    set -- $cnfmod; mprint=$([ "$#" -gt 1 ] && echo "mods" || echo "mod"); ui_print " "; ui_print "! Conflicting audio$mprint found: $cnfmod!"; ui_print "  Install AudioModificationLibrary (AML) if"; ui_print "  conflicting audio$mprint support it."; ui_print "  Note that AML provides compatibility for"; ui_print "  a limited amount of files. Some contents"; ui_print "  between conflicting $mprint & SILMARIL may"; ui_print "  overlap and persist in canceling each";  ui_print "  other out."; sleep 1
  fi
  curveout="$VALI/vc.xml"; mktouch "$curveout"; tar -xf "$MODPATH"/common/prep.tar.xz -C "$VALI" 2>/dev/null; tar -xf "$VALI"/tools.tar.xz -C "$VALI" 2>/dev/null; . "$VALI"/tools/install.sh; [ "$ROOT_MODE" == "KSUN" ] && mv -f "$VALI"/modulebg.png "$MODPATH" || rm -f "$VALI"/modulebg.png; TMD="$VALI/tmix.txt"; mktouch "$TMD"; tinymix dump 2>/dev/null >"$TMD"; SND="$(tinymix cname)"; [ -n "$QCP" ] && MAXAG="$(tinymix get 'HPHL Volume' 2>/dev/null | awk -F'[>)]' '{print $2}')" && sed -i "s/Range from 0 to XX/Range from 0 to $MAXAG/" "$MODPATH"/silmaril_useroptions
  [ -f "$AUO" ] && UVER=$(grep_prop UVER $AUO); ui_print " "; ui_print " - Reading UserOptions"
  if [ ! -f "$AUO" ]; then
    ui_print "   No silmaril_useroptions detected !"; ui_print "   Creating useroptions in internal storage..."; ui_print "   Using specified options:"; cp -f "$MODPATH"/silmaril_useroptions "$AUO"; sleep 0.5
  elif [ "$UVER" -lt "$(grep_prop UVER "$MODPATH"/silmaril_useroptions)" ]; then
    ui_print "   Older silmaril_useroptions version detected"; ui_print "   Updating silmaril_useroptions..."; ui_print "   Using specified options:"; process_uo -u; sleep 0.5
  else
    ui_print "   Up-to-date silmaril_useroptions detected"; ui_print "   Using specified options:"; sleep 0.5
  fi
  cat $AUO | sed 's/\r$//g' | tr '\r' '\n' >$AUO.tmp; mv -f $AUO.tmp $AUO; process_uo; sleep 0.5; set_perm_recursive "$MODPATH" 0 0 0755 0644; set_perm_recursive "$VALI"/tools/arm64 0 0 0755 0755; chmod +x "$VALI"/tools/arm64/*; ui_print " "; ui_print " "; ui_print "- Installing [$MODNAME $MODVER]"; [ -n "$SOC_PLAT" ] && { ui_print "  on SDK$API $SOCP/$SOC_PLAT $OEM device" || ui_print "  on SDK$API $SOCP $OEM device"; }; sleep 1
else
  set_perm_recursive "$VALI"/tools/arm64 0 0 0755 0755; chmod +x "$VALI"/tools/arm64/*; [ -f "$AUO" ] && UVER=$(grep_prop UVER $AUO); ui_print " "; ui_print " - Reading UserOptions"; process_uo; sleep 0.5; ui_print " "; ui_print " "; ui_print "- Installing [$MODNAME $MODVER] to AML"
fi
$AML && { . "$MODPATH"/files/helluin.sh; . "$MODPATH"/files/laurelin.sh; } || { . "$MODPATH"/common/helluin.sh; . "$MODPATH"/common/laurelin.sh; }
if ! $AML; then
  . "$MODPATH"/common/earendil.sh
  for OFILE in ${DVT}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"
    {
      set +x; p_start=-8888; p_end=-1100; curve=""; i=0; [ -n "$U_VSTP" ] && index=$U_VSTP || index=15
      while [ $i -lt "$index" ]; do
        percent=$(awk "BEGIN {print int(1 + $i * 99 / ($index - 1) + 0.5)}")
        if [ $i -eq 0 ]; then
          p_int=$p_start
        elif [ $i -eq $((index - 1)) ]; then
          p_int=$p_end
        else
          c_ind=$(awk "BEGIN {print $p_start + ($p_end - $p_start) * (log(1 + $percent / 10) / log(11))}"); p_int=$(awk "BEGIN {print int($c_ind + 0.5)}")
        fi
        [ -z "$curve" ] && curve="        <point>$percent,$p_int</point>" || curve="$curve\n        <point>$percent,$p_int</point>"; i=$((i + 1))
      done
      echo -e "        <!-- SILMARIL $index STEPS ATTENUATION CURVE -->\n$curve" > "$curveout"; set -x
    }
    case "$(basename "${FILE}")" in
      default_volume_tables.xml | audio_policy_engine_default_stream_volumes.xml)
        if ! grep -q '<point>\([1-9][0-9]\{2,\}\|10[1-9]\|1[1-9][0-9]\)</point>' "$FILE"; then
          format_file "$FILE"
          for name in "DEFAULT_MEDIA_VOLUME_CURVE" "DEFAULT_DEVICE_CATEGORY_HEADSET_VOLUME_CURVE" "DEFAULT_DEVICE_CATEGORY_EXT_MEDIA_VOLUME_CURVE" "DEFAULT_MEDIA_VOLUME_CURVE_A2DP"; do
            awk -v insert_file="$VALI/vc.xml" '/<reference name="'"$name"'">/ {print; in_block=1; while ((getline line < insert_file) > 0) print line; next} /<\/reference>/ {print; in_block=0; next} !in_block {print}' "$FILE" > tmp && mv tmp "$FILE"
          done
          if [ -n "$U_ESTV" ]; then
            for CAT in "DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE" "DEFAULT_DEVICE_CATEGORY_EARPIECE_VOLUME_CURVE"; do
              awk -v insert_file="$VALI/svc.xml" -v cat="$CAT" '/<reference name="'"$cat"'">/ {print; in_block=1; while ((getline line < insert_file) > 0) print line; next} /<\/reference>/ {print; in_block=0; next} !in_block {print}' "$FILE" > tmp && mv tmp "$FILE"
            done
          fi
        fi
      ;;
      audio_policy_volumes.xml)
        if ! grep -q '<point>\([1-9][0-9]\{2,\}\|10[1-9]\|1[1-9][0-9]\)</point>' "$FILE"; then
          format_file "$FILE"
          awk -v insert_file="$VALI/vc.xml" '/<reference name="HEADSET_SYSTEM_VOLUME_CURVE">/ {print; in_block=1; while ((getline line < insert_file) > 0) print line; next} /<\/reference>/ {print; in_block=0; next} !in_block {print}' "$FILE" >tmp && mv tmp "$FILE"
          names="$(grep -E -o 'DEVICE_CATEGORY_(A2DP|HEADSET|HEADSET_nonEU|USB_HEADSET|BLUETOOTH)' "$FILE" | sort -u)"
          for strm in "AUDIO_STREAM_SYSTEM" "AUDIO_STREAM_MUSIC" "AUDIO_STREAM_BLUETOOTH_SCO"; do
            for name in ${names}; do
              sed -i "/<volume stream=\"$strm\" deviceCategory=\"$name\">/,/<\/volume>/d; /<volumes>/a\  <volume stream=\"$strm\" deviceCategory=\"$name\" ref=\"DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE\"/>" "$FILE"
            done
          done
          unset names
          if [ -n "$U_ESTV" ]; then
            for strm in "AUDIO_STREAM_SYSTEM" "AUDIO_STREAM_MUSIC"; do
              for name in "DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE" "DEFAULT_DEVICE_CATEGORY_EARPIECE_VOLUME_CURVE"; do
                sed -i "/<volume stream=\"$strm\" deviceCategory=\"$name\">/,/<\/volume>/d; /<volumes>/a\  <volume stream=\"$strm\" deviceCategory=\"$name\" ref=\"DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE\"/>" "$FILE"
              done
            done
          fi
        fi
      ;;
      audio_policy_engine_stream_volumes.xml)
        if ! grep -q '<point>\([1-9][0-9]\{2,\}\|10[1-9]\|1[1-9][0-9]\)</point>' "$FILE"; then
          format_file "$FILE"
          [ -n "$U_VSTP" ] && sed -i -e "/<volumeGroup>/,/<\/volumeGroup>/ { /<name>music<\/name>/,/<\/volumeGroup>/ { /<indexMax>/ { s|<indexMax>[^<]*</indexMax>|<indexMax>$U_VSTP</indexMax>|; } } }" "$FILE"
          names="$(grep -E -o 'DEVICE_CATEGORY_(HEADSET|HEADSET_CE|HEADSET_SPATIALIZER|HEADSET_SPATIALIZER_CE|USB|USB_CE|USB_SPATIALIZER|USB_SPATIALIZER_CE|A2DP|A2DP_CE|A2DP_SPATIALIZER|A2DP_SPATIALIZER_CE)' "$FILE" | sort -u)"
          for name in ${names}; do
            sed -i -e "/<volumeGroup>/,/<\/volumeGroup>/ { /<name>music<\/name>/,/<\/volumeGroup>/ { /<volume deviceCategory=\"$name\">/,/<\/volume>/ { /<volume deviceCategory=\"$name\">/!d; s/<volume deviceCategory=\"$name\">/<volume deviceCategory=\"$name\" ref=\"DEFAULT_MEDIA_VOLUME_CURVE\"\/>/; } } }" "$FILE"
          done
          unset names
          if [ -n "$U_ESTV" ]; then
            for name in "DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE" "DEFAULT_DEVICE_CATEGORY_EARPIECE_VOLUME_CURVE"; do
              sed -i -e "/<volumeGroup>/,/<\/volumeGroup>/ { /<name>music<\/name>/,/<\/volumeGroup>/ { /<volume deviceCategory=\"$name\">/,/<\/volume>/ { /<volume deviceCategory=\"$name\">/!d; s/<volume deviceCategory=\"$name\">/<volume deviceCategory=\"$name\" ref=\"DEFAULT_DEVICE_CATEGORY_SPEAKER_VOLUME_CURVE\"\/>/; } } }" "$FILE"
            done
          fi
        fi
      ;;

    esac
  done
  purge
  if [ -n "$QCP" ]; then
    if [ -n "$APLIS" ]; then
      ui_print " "; ui_print " - Patching HAL platform interface"
      for OFILE in ${APLIS}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        awk -v insert_file="$VALI/db.xml" 'BEGIN { in_block = 0 } /<gain_db_to_level_mapping>/ { print; in_block = 1; while ((getline line < insert_file) > 0) print line; next } /<\/gain_db_to_level_mapping>/ { print; in_block = 0; next } !in_block { print }' "$FILE" >tmp && mv tmp "$FILE"
        case $Q_CSMPL in "KHZ_352P8") APLIS_SR=352800 ;; "KHZ_384") APLIS_SR=384000 ;; *) APLIS_SR=192000 ;; esac; case $Q_CBIT in "S16_LE") APLIS_FMT="16" ;; "S24_3LE"|"S24_LE") APLIS_FMT="24" ;; "S32_LE") APLIS_FMT=32 ;; *) APLIS_FMT=16 ;; esac
        for i in 69936 69937 69940 69941 69942 69943; do
          awk -v fmt="$APLIS_FMT" -v id="$i" -v rate="$APLIS_SR" 'BEGIN{in_section=0;found_app=0;found_apptypes=0}/<audio_platform_info>/{in_section=1}/<app_types>/{found_apptypes=1}in_section&&/<app uc_type="PCM_PLAYBACK" mode="default"/&&$0~"id=\""id"\""{found_app=1;sub(/bit_width="[^"]*"/,"bit_width=\""fmt"\"");sub(/max_rate="[^"]*"/,"max_rate=\""rate"\"")}in_section&&/<\/app_types>/&&!found_app&&found_apptypes{print"    <app uc_type=\"PCM_PLAYBACK\" mode=\"default\" bit_width=\""fmt"\" id=\""id"\" max_rate=\""rate"\" />"}in_section&&/<\/audio_platform_info>/&&!found_apptypes{print"  <app_types>";print"    <app uc_type=\"PCM_PLAYBACK\" mode=\"default\" bit_width=\""fmt"\" id=\""id"\" max_rate=\""rate"\" />";print"  </app_types>"}{print}/<\/audio_platform_info>/{in_section=0}' "$FILE" > tmpfile && mv tmpfile "$FILE"
        done
      done
      purge
      APLIS_NESTED="$(find "$MODPATH" -type f -name "audio_platform_info*.xml")"
      for FILE in ${APLIS_NESTED}; do
        case "$Q_DSPOD" in "disable"|"") grep -q "native_audio_mode" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="native_audio_mode"]' "multiple_mix_codec" ;; "enable") grep -q "native_audio_mode" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="native_audio_mode"]' "multiple_mix_dsp" ;; esac
        grep -q "true_32_bit" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="true_32_bit"]' "true"; grep -q "hifi_filter" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="hifi_filter"]' "false"
        grep -q "usb_sidetone_gain" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="usb_sidetone_gain"]' "0"; grep -q "enable_hp_impedance_match" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="enable_hp_impedance_match"]' "false"
        patch_xml -d "$FILE" '/audio_platform_info/config_params/param[@key="hp_impedance_match_threshold"]' ".*"; grep -q "oplus_power_analysis_enable" "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="oplus_power_analysis_enable"]' "disable"; patch_xml -s "$FILE" '/audio_platform_info/config_params/param[@key="audio.nat.codec.enabled"]' "true"; plval="14, 0x40400000, 0x1, 0x40C00000, 0x1, 0x41404100, 0x1, 0x41440100, 0xc, 0x4300C000, 0x5a, 0x43004000, 0xa, 0x41808000, 0xa"
        if grep -q 'perf_lock_opts' "$FILE"; then
          ! grep -q 'perf_lock_opts.*0x101.*' "$FILE" && patch_xml -u "$FILE" '/audio_platform_info/config_params/param[@key="perf_lock_opts"]' "$plval"
        elif { strings "$PHAL64" 2>/dev/null | grep -q 'perf_lock_opts' || [ -n "$PWH" ]; }; then
          patch_xml -s "$FILE" '/audio_platform_info/config_params/param[@key="perf_lock_opts"]' "$plval"
        fi
        ! grep -q 'snd_card_name' "$FILE" && patch_xml -s "$FILE" '/audio_platform_info/config_params/param[@key="snd_card_name"]' "$SND"
        if strings "$PHAL64" 2>/dev/null | grep -q 'hifi-playback' && ! grep -q 'USECASE_AUDIO_PLAYBACK_HIFI' "$FILE" && ! grep -q "type=\"out\" id=\"1\"" "$FILE"; then
          patch_xml -s "$FILE" "/pcm_ids/usecase[@name=\"USECASE_AUDIO_PLAYBACK_HIFI\"]" "type=out" "id=1"
        fi
        if [ -n "$Q_CBIT_PROCEED" ] || [ -n "$Q_HDSPBW" ]; then
          names="$(grep -E 'SND_DEVICE_OUT_(ANC_(FB_)?HEADSET|BUS_MEDIA|BT_A2DP(_AUDIO_PLAYBACK_EFFECT)?|HDMI|HEADPHONES(_AUDIO_PLAYBACK_(EFFECT|TMGP)|_AND_BT_A2DP|_DOLBY|_DSD|_HIFI_FILTER|_HIGH_IMP|_44_1)?|GAME_HEADPHONES|USB_(HEADSET|HEADPHONES)|LINE|SPEAKER_AND_(ANC_(FB_)?HEADSET|HEADPHONES(_EXTERNAL_[12]|_HIFI_FILTER)?|USB_HEADSET|LINE))|SND_DEVICE_LGE_OUT_(SPEAKER_AND_HEADPHONES(_DAC(_ADVANCED|_AUX)?|_ADVANCED|_AUX)|HEADPHONES(_(ADVANCED|AUX)(_44_1)?|_HIFI_DAC(_44_1(_ADVANCED)?|_ADVANCED|_AUX|_HIFI_DACDOP(_ADVANCED|_AUX)?)?)|HEADPHONE_24BIT(_ADVANCED|_AUX)?)' -o "$FILE" | grep -vE '[">]|name=' | sort -u)"
          case $Q_CBIT in "S16_LE") APLIS_FMT="16" ;; "S24_3LE"|"S24_LE") APLIS_FMT="24" ;; "S32_LE") APLIS_FMT=32 ;; *) APLIS_FMT=16 ;; esac
          for name in $names; do
            [ -n "$Q_HDSPBW" ] && patch_xml -s "$FILE" "/audio_platform_info/bit_width_configs/device[@name=\"$name\"]" "bit_width=$Q_HDSPBW" || patch_xml -s "$FILE" "/audio_platform_info/bit_width_configs/device[@name=\"$name\"]" "bit_width=$APLIS_FMT"
          done
          unset names
        fi
      done
      purge
    fi
    if [ -n "$ACONF" ]; then
      ui_print " "; ui_print " - Patching HAL audioconfig interface"
      for OFILE in ${ACONF}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        patch_xml -s "$FILE" '/configs/property[@name="vendor.audio.hal.output.suspend.supported"]' "true"; patch_xml -s "$FILE" '/configs/property[@name="vendor.audio.hal.dynamic.qos.config.supported"]' "true"
        confp="persist.vendor.audio.sva.conc.enabled persist.vendor.audio.va_concurrency_enabled vendor.audio.feature.hwdep_cal.enable vendor.audio.volume.headset.gain.depcal"
        [ -n "$U_APDBR" ] && confp="audio.deep_buffer.media use_deep_buffer_as_primary_output $confp"
        for name in $confp; do
          patch_xml -s "$FILE" "/configs/property[@name=\"$name\"]" "false"
        done
        for name in "hifi_audio_enabled" "kpi_optimize_enabled"; do
          patch_xml -s "$FILE" "/configs/flag[@name=\"$name\"]" "true"
        done
        conff="battery_listener_enabled fm_power_opt audiosphere_enabled extn_resampler ext_hw_plugin_enabled hwdep_cal_enabled"
        [ -n "$U_APDBR" ] && conff="keep_alive_enabled $conff"
        for name in $conff; do
          grep -q "$name" "$FILE" && patch_xml -u "$FILE" "/configs/flag[@name=\"$name\"]" "false"
        done
        [ -n "$U_BTDAO" ] && { grep -q "a2dp_offload_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="a2dp_offload_enabled"]' "false"; } || { grep -q "a2dp_offload_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="a2dp_offload_enabled"]' "true"; }
        if find $(pfind "lib*") -maxdepth 1 -type f -name "libdsmfeedback.so" -print -quit 2>/dev/null | grep -q .; then
          grep -q "dsm_feedback_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="dsm_feedback_enabled"]' "true"
        else
          grep -q "dsm_feedback_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="dsm_feedback_enabled"]' "false"
        fi
        if ind $(pfind "lib*") -maxdepth 1 -type f -name "libsndmonitor.so" -print -quit 2>/dev/null | grep -q . && [ "$Q_DSPOD" == "enable" ]; then
          grep -q "snd_monitor_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="snd_monitor_enabled"]' "true"
        else
          grep -q "snd_monitor_enabled" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="snd_monitor_enabled"]' "false"
        fi
        [ -n "$Q_HDSPBW" ] && patch_xml -s "$FILE" '/configs/property[@name="persist.vendor.audio_hal.dsp_bit_width_enforce_mode"]' "$Q_HDSPBW"
        [ -n "$Q_MBDRC" ] && patch_xml -s "$FILE" '/configs/property[@name="vendor.audio.vol_based_mbdrc.enabled"]' "false"
        if [ "$Q_DSPOD" == "disable" ]; then
          grep -q "audio.offload.disable" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="audio.offload.disable"]' "true"
          for name in "afe_proxy_enabled" "audio_extn_formats_enabled" "hdmi_passthrough_enabled" "ext_qdsp_enabled" "compress_metadata_needed" "aac_adts_offload_enabled" "alac_offload_enabled" "ape_offload_enabled" "qti_flac_decoder" "vorbis_offload_enabled" "wma_offload_enabled" "flac_offload_enabled" "pcm_offload_enabled_16" "pcm_offload_enabled_24" "usb_offload_enabled" "usb_offload_burst_mode"; do
            grep -q "$name" "$FILE" && patch_xml -u "$FILE" "/configs/flag[@name=\"$name\"]" "false"
          done
          for name in "vendor.audio.offload.track.enable" "vendor.audio.offload.multiple.enabled" "vendor.audio.av.streaming.offload.enable"; do
            grep -q "$name" "$FILE" && patch_xml -u "$FILE" "/configs/property[@name=\"$name\"]" "false"
          done
          patch_xml -s "$FILE" "/configs/property[@name=\"persist.vendor.audio.c2.dma.conc.enabled\"]" "true"
        elif [ "$Q_DSPOD" == "enable" ]; then
          grep -q "audio.offload.disable" "$FILE" && patch_xml -u "$FILE" '/configs/property[@name="audio.offload.disable"]' "false"
          for name in "afe_proxy_enabled" "audio_extn_formats_enabled" "hdmi_passthrough_enabled" "ext_qdsp_enabled" "compress_metadata_needed" "aac_adts_offload_enabled" "alac_offload_enabled" "ape_offload_enabled" "qti_flac_decoder" "vorbis_offload_enabled" "wma_offload_enabled" "flac_offload_enabled" "pcm_offload_enabled_16" "pcm_offload_enabled_24" "usb_offload_enabled" "usb_offload_burst_mode"; do
            grep -q "$name" "$FILE" && patch_xml -u "$FILE" "/configs/flag[@name=\"$name\"]" "true"
          done
          for name in "vendor.audio.offload.track.enable" "vendor.audio.offload.multiple.enabled" "vendor.audio.av.streaming.offload.enable"; do
            grep -q "$name" "$FILE" && patch_xml -u "$FILE" "/configs/property[@name=\"$name\"]" "true"
          done
          patch_xml -s "$FILE" "/configs/property[@name=\"persist.vendor.audio.c2.dma.conc.enabled\"]" "false"
        fi
      done
      purge
    fi
    if [ -n "$RMA" ]; then
      ui_print " "; ui_print " - Patching ARE APM interface"
      for OFILE in ${RMA}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        awk -v insert_file="$VALI/db.xml" 'BEGIN { in_block = 0 } /<gain_db_to_level_mapping>/ { print; in_block = 1; while ((getline line < insert_file) > 0) print line; next } /<\/gain_db_to_level_mapping>/ { print; in_block = 0; next } !in_block { print }' "$FILE" >tmp && mv tmp "$FILE"; plval="0x40400000, 0x1, 0x40C00000, 0x1, 0x41404100, 0x1, 0x41440100, 0xc, 0x4300C000, 0x5a, 0x43004000, 0xa, 0x41808000, 0xa"
        if grep -q '<perf_lock' "$FILE"; then
          awk -v pv="$plval" '/<perf_lock library="libqti-perfd-client.so"/{sub(/config="[^"]*"/,"config=\""pv"\"")}1' "$FILE" >tmp && mv tmp "$FILE"
        elif [ -n "$PERFLO" ]; then
          awk -v pv="$plval" '/<group_device_cfg>/{print "    <perf_lock library=\"libqti-perfd-client.so\" config=\""pv"\" />"}1' "$FILE" >tmp && mv tmp "$FILE"
        fi
        for s in "PAL_STREAM_COMPRESSED" "PAL_STREAM_PCM_OFFLOAD" "PAL_STREAM_RAW" "PAL_STREAM_GENERIC" "PAL_STREAM_DEEP_BUFFER"; do
          sed -ri "/<\/lpm_supported_streams>/i \            <lpm_supported_stream>$s</lpm_supported_stream>" "$FILE"
        done
        if [ -n "$Q_CSMPL_PROCEED" ]; then
          case $Q_CSMPL in "KHZ_44P1") RMA_RS=44100 ;; "KHZ_48") RMA_RS=48000 ;; "KHZ_88P2") RMA_RS=88200 ;; "KHZ_96") RMA_RS=96000 ;; "KHZ_176P4") RMA_RS=176400 ;; "KHZ_192") RMA_RS=192000 ;; "KHZ_352P8") RMA_RS=352800 ;; "KHZ_384") RMA_RS=384000 ;; esac
          for name in "PAL_DEVICE_OUT_WIRED_HEADPHONE" "PAL_DEVICE_OUT_WIRED_HEADSET" "PAL_DEVICE_OUT_USB_DEVICE" "PAL_DEVICE_OUT_USB_HEADSET" "PAL_DEVICE_OUT_LINE" "PAL_DEVICE_OUT_AUX_LINE"; do
            sed -ri "/<out-device>/,/<\/out-device>/ { /<id>$name<\/id>/,/<snd_device_name>.*<\/snd_device_name>/ { /<samplerate>/d; s/( *)(<snd_device_name>)/\1<samplerate>$RMA_RS<\/samplerate>\n\1\2/; } }" "$FILE"
            case "$Q_CSMPL" in
              "KHZ_44P1"|"KHZ_88P2"|"KHZ_176P4"|"KHZ_352P8") sed -ri "/<out-device>/,/<\/out-device>/ { /<id>$name<\/id>/,/<snd_device_name>.*<\/snd_device_name>/ { /<fractional_sr>/d; s/( *)(<snd_device_name>)/\1<fractional_sr>1<\/fractional_sr>\n\1\2/; } }" "$FILE" ;;
              *) sed -ri "/<out-device>/,/<\/out-device>/ { /<id>$name<\/id>/,/<snd_device_name>.*<\/snd_device_name>/ { /<fractional_sr>/d; s/( *)(<snd_device_name>)/\1<fractional_sr>0<\/fractional_sr>\n\1\2/; } }" "$FILE" ;;
            esac
          done
        fi
        if [ -n "$Q_CBIT_PROCEED" ]; then
          case $Q_CBIT in "S16_LE") RMA_BIT=16 RMA_FMT=PAL_AUDIO_FMT_PCM_S16_LE ;; "S24_LE") RMA_BIT=24 RMA_FMT=PAL_AUDIO_FMT_PCM_S24_LE ;; "S24_3LE") RMA_BIT=24 RMA_FMT=PAL_AUDIO_FMT_PCM_S24_3LE ;; "S32_LE") RMA_BIT=32 RMA_FMT=PAL_AUDIO_FMT_PCM_S32_LE ;; esac
          for name in "PAL_DEVICE_OUT_WIRED_HEADPHONE" "PAL_DEVICE_OUT_WIRED_HEADSET" "PAL_DEVICE_OUT_USB_DEVICE" "PAL_DEVICE_OUT_USB_HEADSET" "PAL_DEVICE_OUT_LINE" "PAL_DEVICE_OUT_AUX_LINE"; do
            sed -ri "/<out-device>/,/<\/out-device>/ { /<id>$name<\/id>/,/<snd_device_name>.*<\/snd_device_name>/ { /<bit_width>/d; s/( *)(<snd_device_name>)/\1<bit_width>$RMA_BIT<\/bit_width>\n\1<supported_bit_format>$RMA_FMT<\/supported_bit_format>\n\1\2/; } }" "$FILE"
          done
        fi
        if [ -n "$Q_BTCSMPL_PROCEED" ]; then
          case $Q_BTCSMPL in "KHZ_44P1") RMA_QBS=44100 ;; "KHZ_48") RMA_QBS=48000 ;; "KHZ_96") RMA_QBS=96000 ;; esac
          for name in "PAL_DEVICE_OUT_BLUETOOTH_A2DP" "PAL_DEVICE_OUT_BLUETOOTH_BLE" "PAL_DEVICE_OUT_BLUETOOTH_BLE_BROADCAST"; do
            sed -ri "/<out-device>/,/<\/out-device>/ { /<id>$name<\/id>/,/<snd_device_name>.*<\/snd_device_name>/ { /<samplerate>/d; s/( *)(<snd_device_name>)/\1<samplerate>$RMA_QBS<\/samplerate>\n\1\2/; } }" "$FILE"
          done
        fi
      done
      purge
      RMA_NESTED="$(find "$MODPATH" -type f -name "resourcemanager*.xml")"
      for FILE in ${RMA_NESTED}; do
        patch_xml -s "$FILE" '/resource_manager_info/config_params/param[@key="audio.nat.codec.enabled"]' "true"; patch_xml -s "$FILE" '/resource_manager_info/config_params/param[@key="UHQA"]' "true"
        case "$Q_DSPOD" in
          "disable"|"") grep -q "native_audio_mode" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="native_audio_mode"]' "multiple_mix_codec" ;; "enable") grep -q "native_audio_mode" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="native_audio_mode"]' "multiple_mix_dsp" ;;
        esac
        grep -q "hifi_filter" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="hifi_filter"]' "false"; grep -q "logging_level" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="logging_level"]' "0"; grep -q "upd_set_custom_gain" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="upd_set_custom_gain"]' "false"; grep -q "spkr_xmax_tmax_logging_enable" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="spkr_xmax_tmax_logging_enable"]' "false"; grep -q "oplus_ear_protection_enable" "$FILE" && patch_xml -u "$FILE" '/resource_manager_info/config_params/param[@key="oplus_ear_protection_enable"]' "false"
      done
      purge
    fi
    if [ -n "$UKV" ]; then
      if [ -n "$Q_CSMPL_PROCEED" ] || [ -n "$Q_CBIT_PROCEED" ] || [ -n "$U_APDBR" ] || [ -n "$Q_MBDRC" ]; then
        ui_print " "; ui_print " - Patching ARE AGM interface"
        for OFILE in ${UKV}; do
          nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
          if [ -n "$Q_CSMPL_PROCEED" ]; then
            case $Q_CSMPL in "KHZ_44P1") UKV_RS=0xac44 ;; "KHZ_48") UKV_RS=0xbb80 ;; "KHZ_96") UKV_RS=0x17700 ;; "KHZ_192") UKV_RS=0x2ee00 ;; "KHZ_384") UKV_RS=0x5dc00 ;; esac
            for ID in "PAL_DEVICE_OUT_AUX_DIGITAL,PAL_DEVICE_OUT_AUX_DIGITAL_1,PAL_DEVICE_OUT_HDMI" "PAL_DEVICE_OUT_WIRED_HEADSET,PAL_DEVICE_OUT_WIRED_HEADPHONE" "PAL_DEVICE_OUT_USB_HEADSET,PAL_DEVICE_OUT_USB_DEVICE"; do
              for STREAM in "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC" "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_RAW"; do
                awk -v id="$ID" -v stream="$STREAM" -v rs="$UKV_RS" 'BEGIN{d=0;k=0} /<devicepp id="[^"]*"/{if($0~"<devicepp id=\""id"\"")d=1} /<\/devicepp>/{if(d)d=0} /<keys_and_values StreamType="[^"]*"/{if(d&&$0~"StreamType=\""stream"\"")k=1} /<\/keys_and_values>/{if(d&&k){k=0;sub(/^[ \t]*/,"&    <graph_kv key=\"0xa5000000\" value=\""rs"\"/>\n&")}} {print}' "$FILE" >tmp && mv tmp "$FILE"
              done
            done
          fi
          if [ -n "$Q_CBIT_PROCEED" ]; then
            case $Q_CBIT in "S16_LE") UKV_BIT=0x10 ;; "S24_LE" | "S24_3LE") UKV_BIT=0x18 ;; "S32_LE") UKV_BIT=0x20 ;; esac
            for ID in "PAL_DEVICE_OUT_AUX_DIGITAL,PAL_DEVICE_OUT_AUX_DIGITAL_1,PAL_DEVICE_OUT_HDMI" "PAL_DEVICE_OUT_WIRED_HEADSET,PAL_DEVICE_OUT_WIRED_HEADPHONE" "PAL_DEVICE_OUT_USB_HEADSET,PAL_DEVICE_OUT_USB_DEVICE"; do
              for STREAM in "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC" "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_RAW"; do
                awk -v id="$ID" -v stream="$STREAM" -v bw="$UKV_BIT" 'BEGIN{d=0;k=0} /<devicepp id="[^"]*"/{if($0~"<devicepp id=\""id"\"")d=1} /<\/devicepp>/{if(d)d=0} /<keys_and_values StreamType="[^"]*"/{if(d&&$0~"StreamType=\""stream"\"")k=1} /<\/keys_and_values>/{if(d&&k){k=0;sub(/^[ \t]*/,"&    <graph_kv key=\"0xa6000000\" value=\""bw"\"/>\n&")}} {print}' "$FILE" >tmp && mv tmp "$FILE"
              done
            done
          fi
          [ -n "$U_APDBR" ] && sed -i '/<graph_kv key="0xA1000000" value=/s/0xA1000001/0xA100000E/g' "$FILE"
          if [ -n "$Q_MBDRC" ]; then
            for ID in "PAL_DEVICE_OUT_WIRED_HEADSET,PAL_DEVICE_OUT_WIRED_HEADPHONE" "PAL_DEVICE_OUT_USB_DEVICE,PAL_DEVICE_OUT_USB_HEADSET" "PAL_DEVICE_OUT_BLUETOOTH_SCO" "PAL_DEVICE_OUT_BLUETOOTH_BLE" "PAL_DEVICE_OUT_BLUETOOTH_A2DP"; do
              for STREAM in "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC" "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_COMPRESSED,PAL_STREAM_DEEP_BUFFER,PAL_STREAM_LOW_LATENCY,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_COMPRESSED,PAL_STREAM_DEEP_BUFFER,PAL_STREAM_LOW_LATENCY,PAL_STREAM_PCM_OFFLOAD"; do
                for VAL in "0xAC000002" "0xAC000009" "0xac000100"; do
                  awk -v id="$ID" -v stream="$STREAM" -v val="$VAL" 'BEGIN{inside_devicepp=0;inside_keys=0} /<devicepp id="[^"]*"/{if($0~"<devicepp id=\""id"\"")inside_devicepp=1} /<\/devicepp>/{inside_devicepp=0} /<keys_and_values StreamType="[^"]*"/{if(inside_devicepp && $0~"<keys_and_values StreamType=\""stream"\"")inside_keys=1} /<\/keys_and_values>/{inside_keys=0} (inside_devicepp && inside_keys && $0~"<graph_kv key=\"0xAC000000\" value=\""val"\"/") {next} {print}' "$FILE" > tmp && mv tmp "$FILE"
                done
              done
            done
            for ID in "PAL_DEVICE_OUT_SPEAKER" "PAL_DEVICE_OUT_HANDSET"; do
              for STREAM in "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_GENERIC,PAL_STREAM_LOW_LATENCY,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC" "PAL_STREAM_DEEP_BUFFER,PAL_STREAM_PCM_OFFLOAD,PAL_STREAM_COMPRESSED,PAL_STREAM_LOW_LATENCY,PAL_STREAM_GENERIC,PAL_STREAM_SPATIAL_AUDIO" "PAL_STREAM_LOW_LATENCY"; do
                for VAL in "0xAC000002" "0xAC000009"; do
                  awk -v id="$ID" -v stream="$STREAM" -v val="$VAL" 'BEGIN{inside_devicepp=0;inside_keys=0} /<devicepp id="[^"]*"/{if($0~"<devicepp id=\""id"\"")inside_devicepp=1} /<\/devicepp>/{inside_devicepp=0} /<keys_and_values StreamType="[^"]*"/{if(inside_devicepp && $0~"<keys_and_values StreamType=\""stream"\"")inside_keys=1} /<\/keys_and_values>/{inside_keys=0} (inside_devicepp && inside_keys && $0~"<graph_kv key=\"0xAC000000\" value=\""val"\"/") {next} {print}' "$FILE" > tmp && mv tmp "$FILE"
                done
              done
            done
          fi
        done
        purge
      fi
    fi
    if [ -n "$AMCP" ]; then
      if [ -n "$Q_CBIT_PROCEED" ] || [ -n "$U_APDBR" ] || [ -n "$Q_DSPOD" ]; then
        for OFILE in ${AMCP}; do
          nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
          if [ -n "$Q_CBIT_PROCEED" ]; then
            case $Q_CBIT in "S16_LE") AMCP_BIT=INT_16_BIT ;; "S24_LE") AMCP_BIT=FIXED_Q_8_24 ;; "S24_3LE") AMCP_BIT=INT_24_BIT ;; "S32_LE") AMCP_BIT=INT_32_BIT ;; esac
            for name in "low_latency_out" "raw_out" "mmap_no_irq_out"; do
              awk -v mname="$name" -v bit="$AMCP_BIT" 'BEGIN { inside_mixPort = 0 } /<mixPort name="/ { if ($0 ~ "name=\"" mname "\"") { inside_mixPort = 1 } } inside_mixPort { sub(/pcmType="INT_16_BIT"/, "pcmType=\"" bit "\"") } /<\/mixPort>/ { if (inside_mixPort) { inside_mixPort = 0 } } { print }' "$FILE" >tmp && mv tmp "$FILE"
            done
            for name in "wired_headset" "wired_headphones" "line_out" "hdmi_out" "usb_device_out" "usb_headset"; do
              awk -v name="$name" -v bit="$AMCP_BIT" 'BEGIN { inside_devicePort = 0 } /<devicePort tagName="/ { if ($0 ~ "tagName=\"" name "\"") { inside_devicePort = 1 } } inside_devicePort { sub(/pcmType="INT_16_BIT"/, "pcmType=\"" bit "\"") } /<\/devicePort>/ { if (inside_devicePort) { inside_devicePort = 0 } } { print }' "$FILE" >tmp && mv tmp "$FILE"
            done
          fi
          [ -n "$U_APDBR" ] && sed -i '/<routes>/,/<\/routes>/{/sink="earpiece"/b;/sink="speaker"/b;s/deep_buffer_out,//g;s/,$//}' "$FILE"; [ -n "$Q_DSPOD" ] && sed -i '/<routes>/,/<\/routes>/{/sink="earpiece"/b;/sink="speaker"/b;s/compress_offload_out,//g;s/,$//}' "$FILE"
        done
        purge
      fi
    fi
    if [ -n "$BEC" ]; then
      if [ -n "$Q_CBIT_PROCEED" ] || [ -n "$Q_CSMPL_PROCEED" ] || [ -n "$Q_CSMPL_PROCEED" ]; then
        ui_print " "; ui_print " - Patching ARE AGM device interface"
        for OFILE in ${BEC}; do
          nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
          case $Q_CBIT in "S32_LE") BEC_QB=32 BEC_FMT=PCM_FORMAT_S32_LE ;; "S24_3LE") BEC_QB=24 BEC_FMT=PCM_FORMAT_S24_3LE ;; "S24_LE") BEC_QB=24 BEC_FMT=PCM_FORMAT_S24_LE ;; "S16_LE") BEC_QB=16 BEC_FMT=PCM_FORMAT_S16_LE ;; esac
          case $Q_CSMPL in "KHZ_44P1") BEC_QS=44100 ;; "KHZ_48") BEC_QS=48000 ;; "KHZ_88P2") BEC_QS=88200 ;; "KHZ_96") BEC_QS=96000 ;; "KHZ_176P4") BEC_QS=176400 ;; "KHZ_192") BEC_QS=192000 ;; "KHZ_352P8") BEC_QS=352800 ;; "KHZ_384") BEC_QS=384000 ;; esac
          case $Q_BTCSMPL in "KHZ_44P1") BEC_QBS=44100 ;; "KHZ_48") BEC_QBS=48000 ;; "KHZ_96") BEC_QBS=96000 ;; esac
          if grep -q 'USB_AUDIO-RX' "$FILE"; then
            if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ]; then
              awk -v QS="$BEC_QS" -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="USB_AUDIO-RX"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\""); sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
            else
              if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_HDSPBW" ]; then
                awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="USB_AUDIO-RX"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
              else
                [ -n "$Q_HDSPBW" ] && awk -v QB="$BEC_QB" '$0 ~ /<device name="USB_AUDIO-RX"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"; [ -n "$Q_CBIT_PROCEED" ] && awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="USB_AUDIO-RX"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
              fi
              [ -n "$Q_CSMPL_PROCEED" ] && awk -v QS="$BEC_QS" '$0 ~ /<device name="USB_AUDIO-RX"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"
            fi
          else
            [ -n "$RMA" ] && [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ] && sed -i "/<config>/a \    <device name=\"USB_AUDIO-RX\" rate=\"$BEC_QS\" ch=\"2\" bits=\"$BEC_QB\" format=\"$BEC_FMT\"\/>" "$FILE"
          fi
          if [ -n "$RMA" ] && [ "$SOC_SKU" != "bengal" ] && [ "$SOC_SKU" != "monaco" ]; then
            if grep -q 'CODEC_DMA-LPAIF_RXTX-RX-0' "$FILE"; then
              if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ]; then
                awk -v QS="$BEC_QS" -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="CODEC_DMA-LPAIF_RXTX-RX-0"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\""); sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
              else
                if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_HDSPBW" ]; then
                  awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="CODEC_DMA-LPAIF_RXTX-RX-0"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
                else
                  [ -n "$Q_HDSPBW" ] && awk -v QB="$BEC_QB" '$0 ~ /<device name="CODEC_DMA-LPAIF_RXTX-RX-0"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"; [ -n "$Q_CBIT_PROCEED" ] && awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="CODEC_DMA-LPAIF_RXTX-RX-0"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
                fi
                [ -n "$Q_CSMPL_PROCEED" ] && awk -v QS="$BEC_QS" '$0 ~ /<device name="CODEC_DMA-LPAIF_RXTX-RX-0"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"
              fi
            else
              [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ] && sed -i "/<config>/a \    <device name=\"CODEC_DMA-LPAIF_RXTX-RX-0\" rate=\"$BEC_QS\" ch=\"2\" bits=\"$BEC_QB\" format=\"$BEC_FMT\"\/>" "$FILE"
            fi
          fi

          if [ -n "$RMA" ]; then
            if grep -q 'SLIM-DEV1-RX-6' "$FILE"; then
              if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ]; then
                awk -v QS="$BEC_QS" -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="SLIM-DEV1-RX-6"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\""); sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
              else
                if [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_HDSPBW" ]; then
                  awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="SLIM-DEV1-RX-6"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
                else
                  [ -n "$Q_HDSPBW" ] && awk -v QB="$BEC_QB" '$0 ~ /<device name="SLIM-DEV1-RX-6"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"; [ -n "$Q_CBIT_PROCEED" ] && awk -v QB="$BEC_QB" -v FMT="$BEC_FMT" '$0 ~ /<device name="SLIM-DEV1-RX-6"/ && $0 ~ /\/>/ { sub(/bits="[^"]*"/, "bits=\"" QB "\""); if ($0 ~ /format="[^"]*"/) { sub(/format="[^"]*"/, "format=\"" FMT "\"") } else { sub(/\/>$/, " format=\"" FMT "\" />") } } { print }' "$FILE" >tmp && mv tmp "$FILE"
                fi
                [ -n "$Q_CSMPL_PROCEED" ] && awk -v QS="$BEC_QS" '$0 ~ /<device name="SLIM-DEV1-RX-6"/ && $0 ~ /\/>/ { sub(/rate="[^"]*"/, "rate=\"" QS "\"") } { print }' "$FILE" >tmp && mv tmp "$FILE"
              fi
            else
              [ -n "$Q_CBIT_PROCEED" ] && [ -n "$Q_CSMPL_PROCEED" ] && sed -i "/<config>/a \    <device name=\"SLIM-DEV1-RX-6\" rate=\"$BEC_QS\" ch=\"2\" bits=\"$BEC_QB\" format=\"$BEC_FMT\"\/>" "$FILE"
            fi
            if [ -n "$Q_BTCSMPL_PROCEED" ]; then
              if grep -q 'SLIM-DEV1-RX-7' "$(echo "$RMA" | head -n 1)"; then
                sed -i "/<\/config>/i\  <device name=\"SLIM-DEV1-RX-7\" rate=\"$BEC_QBS\" ch=\"1\" />" "$FILE"
              elif grep -q 'SLIM-DEV2-RX-7' "$(echo "$RMA" | head -n 1)"; then
                sed -i "/<\/config>/i\  <device name=\"SLIM-DEV2-RX-7\" rate=\"$BEC_QBS\" ch=\"1\" />" "$FILE"
              fi
            fi
          fi
        done
        purge
      fi
    fi
    if [ -n "$KVH" ]; then
      ui_print " "; ui_print " - Patching ARE AGM KV interface"
      for OFILE in ${KVH}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        for name in "DataLogging" "Equalizer" "Asphere" "Virtualizer_Switch" "Reverb_Switch" "PBE_Switch" "BASS_BOOST_Switch" "MISOUND_HPH_EQ_ENABLE" "MISOUND_HPH_MUSICMODE_ENABLE" "MISOUND_HPH_MODULE_SWITCH" "MISOUND_HPH_SWITCH" "MISOUND_HPH_EARCOMP_ENABLE"; do
          sed -i -e "/<KEY name=\"$name\"/,/<\/KEY>/ s/<VALUE val=\"0x1\" name=\"On\"\/>/<VALUE val=\"0x0\" name=\"On\"\/>/" "$FILE"
        done
        if [ "$OEM" == "Xiaomi" ]; then
          for name in "MISOUND_HPH_EARCOMP_AGEMODE" "MISOUND_HPH_STEREO_ENHANCE"; do
            for v in 0x1 0x2 0x3; do
              sed -i -e "/<KEY name=\"$name\"/,/<\/KEY>/ s/<VALUE val=\"$v\" name=\"$v\"\/>/<VALUE val=\"0x0\" name=\"$v\"\/>/" "$FILE"
            done
          done
          if [ -z "$U_BT_KEEPFX" ] || [ -z "$U_OEM_KEEPFX" ]; then
            for name in "MISOUND_SPATIAL_MODULE_ENABLE" "MISOUND_SPATIAL_HEADTRACK_ENABLE" "MISOUND_SPATIAL_SURROUND_ENABLE"; do
              sed -i -e "/<KEY name=\"$name\"/,/<\/KEY>/ s/<VALUE val=\"0x1\" name=\"On\"\/>/<VALUE val=\"0x0\" name=\"On\"\/>/" "$FILE"
            done
          fi
        fi
      done
      purge
    fi
    [ -n "$QHPFM" ] && sed -i -e '$a find /sys/module -name "*high_perf_mode" -exec sh -c '\''echo 1 > "$0"'\'' {} \\;\n' "$POSTFS"; [ -n "$QSMAS" ] && sed -i -e '$a find /sys/module -name "*maximum_substreams" -exec sh -c '\''echo 16 > "$0"'\'' {} \\;\n' "$POSTFS"; [ -n "$Q_CPGD" ] && [ -n "$QDCCE" ] && { sed -i -e '$a find /sys/module -name "*collapse_enable" -exec sh -c '\''echo 0 > "$0"'\'' {} \\;\n' "$POSTFS"; sed -i -e '$a find /sys/module -name "*collapse_timer" -exec sh -c '\''echo 1 > "$0"'\'' {} \\;\n' "$POSTFS"; }; [ "$OEM" == "LG" ] && [ -n "$Q_LGHIM" ] && [ -n "$QMFAM" ] && sed -i -e '$a find /sys/module -name "*force_advanced_mode" -exec sh -c '\''echo 1 > "$0"'\'' {} \\;\n' "$POSTFS"
  fi
  if [ -n "$TENZ" ]; then
    if [ -n "$TCC" ] && [ -n "$U_APDBR" ]; then
      ui_print " "; ui_print " - Patching AOC tuning config"
      for OFILE in ${TCC}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        for name in "usecase_playback_usb_blackbird_headset" "usecase_playback_usb_others_headset" "usecase_playback_usb_dongle_4_pin_headset" "usecase_playback_usb_dongle_3_pin_headphone" "usecase_playback_a2dp"; do
          sed -i "/<usecase-node id=\"$name\" type=\"playback\"/,/<\/usecase-node>/ {/<mode-ref node=\"sound_deep_buffer\" \/>/d}" "$FILE"
        done
      done
      purge
    fi
    if find /vendor/etc/sensors/registry -maxdepth 1 -type f \( -name "komodo_*.reg" -o -name "caiman_*.reg" -o -name "tokay_*.reg" \) 2>/dev/null; then
      mv -f "$VALI"/_ "$MODPATH"/vendor/bin/hw/android.hardware.audio.service-aidl.aoc; T_AOC=1
    fi
    if [ -n "$TPC" ]; then
      for OFILE in ${TPC}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        case $T_CSMPL in "SR_176P4K") MIX_RS=176400 ;; "SR_192K") MIX_RS=192000 ;; *) MIX_RS=96000 ;; esac; sed -i "s/MaxSamplingRate=.*/MaxSamplingRate=$MIX_RS/" "$FILE"
      done
      purge
    fi
  fi
  if [ -n "$MTK" ]; then
    if [ -n "$MPLAT" ]; then
      ui_print " "; ui_print " - Patching HAL config"
      for OFILE in ${MPLAT}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        sed -i 's/<Option>0x99, 1<\/Option>/<Option>0x99, 0<\/Option>/g' "$FILE"
        for name in 0x90 0xae; do
          sed -i "/<SetAudioCommand>/,/<\/SetAudioCommand>/s/\(<SetAudioCommand>\)/\1\n        <Option>\"$name\", 1<\/Option>/" "$FILE"
        done
        sed -i '/<SetParameters>/,/<\/SetParameters>/s/<\/SetParameters>/\1\n        <Option>SetHiFiDACStatus=1<\/Option>/' "$FILE"; sed -i '/<GetParameters>/,/<\/GetParameters>/s/<\/GetParameters>/\1\n        <Option>GetHiFiDACStatus<\/Option>/' "$FILE"
      done
      purge
    fi
    if [ -n "$M_DRC" ]; then
      for OFILE in ${MPDRC}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        for name in DRC_Th DRC_Gn; do
          for id in 1 2 4 9; do
            sed -i "/<ParamUnit param_id=\"$id\">/,/<\/ParamUnit>/ s/<Param name=\"$name\" value=\"[^\"]*\"/<Param name=\"$name\" value=\"0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0\"/" "$FILE"
          done
        done
      done
      purge
    fi
    if [ -n "$U_BTDAO" ]; then
      for OFILE in ${MAUP}; do
        nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
        sed -i 's/<Param name="MTK_A2DP_OFFLOAD_SUPPORT" value=".*" \/>/<Param name="MTK_A2DP_OFFLOAD_SUPPORT" value="no" \/>/' "$FILE"
      done
      purge
    fi
  fi
  if [ -n "$EXY" ] && [ -n "$SAPA" ]; then
    ui_print " "; ui_print " - Patching config"
    for OFILE in ${SAPA}; do
      nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"; patch_xml -s "$FILE" '/feed/feature[@name="support_powersaving_mode"]' "false"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_48000"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_44100"]' "false"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_96000"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_192000"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_352000"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_samplerate_384000"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_low_latency"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_mid_latency"]' "false"; patch_xml -s "$FILE" '/feed/feature[@name="support_high_latency"]' "false"; patch_xml -s "$FILE" '/feed/feature[@name="support_playback_device"]' "true"; patch_xml -s "$FILE" '/feed/feature[@name="support_boost_mode"]' "true"
    done
    purge
  fi
  if [ -n "$OMD" ]; then
    for OFILE in ${OMD}; do
      nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
      sed -i '/<name>com.spotify.music<\/name>/,/<attribute>1<\/attribute>/d' "$FILE"; sed -i '/<name>com.soundcloud.android<\/name>/,/<attribute>1<\/attribute>/d' "$FILE"; sed -i '/<name>com.google.android.music<\/name>/,/<attribute>1<\/attribute>/d' "$FILE"; blocknames="dolby-surround-sound game-bt-delay"
      for BLOCK in $blocknames; do
        for PNAME in "com.qobuz.music" "com.google.android.apps.youtube.music" "com.aspiro.tidal" "com.extreamsd.usbaudioplayerpro" "com.neutroncode.mp" "com.hiby.music" "com.google.android.music" "com.soundcloud.android" "com.spotify.music" "com.maxmpz.audioplayer" "com.google.android.youtube" "com.fiio.music" "com.apple.android.music"; do
          awk -v block="$BLOCK" -v pname="$PNAME" '{print; if ($0 ~ "<" block ">") {print "    <name>" pname "</name>"; print "    <attribute>null</attribute>"; print ""}}' "$FILE" > tmp && mv tmp "$FILE"
        done
      done
      unset blocknames
      [ -n "$U_APDBR" ] && blocknames="audio-choppy-boost donot-force-deepbuffer forbid-effect-volume" || blocknames="audio-choppy-boost forbid-effect-volume"
      for BLOCK in $blocknames; do
        for PNAME in "com.qobuz.music" "com.google.android.apps.youtube.music" "com.aspiro.tidal" "com.extreamsd.usbaudioplayerpro" "com.neutroncode.mp" "com.hiby.music" "com.google.android.music" "com.soundcloud.android" "com.spotify.music" "com.maxmpz.audioplayer" "com.google.android.youtube" "com.fiio.music" "com.apple.android.music"; do
          awk -v block="$BLOCK" -v pname="$PNAME" '{print; if ($0 ~ "<" block ">") {print "    <name>" pname "</name>"; print "    <attribute>1</attribute>"; print ""}}' "$FILE" > tmp && mv tmp "$FILE"
        done
      done
    done
    purge
  fi
  if [ -n "$OAF" ]; then
    for OFILE in ${OAF}; do
      nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
      if [ -n "$QCP" ]; then
        case "$Q_FBUF" in
          "frames") sed -i '/<feature name="OPLUS_USB_PERIOD_US"/ s/config="16000"/config="30720"/' "$FILE" ;; "latency") sed -i '/<feature name="OPLUS_USB_PERIOD_US"/ s/config="16000"/config="8000"/' "$FILE" ;; *) sed -i '/<feature name="OPLUS_USB_PERIOD_US"/ s/config="16000"/config="20375"/' "$FILE" ;;
        esac
      else
        sed -i '/<feature name="OPLUS_USB_PERIOD_US"/ s/config="16000"/config="20375"/' "$FILE"
      fi
    done
    purge
  fi
  [ "$ROOT_MODE" == "MAG_K" ] && mkdir -p "$MODPATH"/root && for PART in $PARTITIONS; do mv -f "$MODPATH"/system"$PART" "$MODPATH"/root; done; echo 'resetprop -n --file $MODPATH/system.prop' >> "$SERV"; echo 'resetprop -p --file $MODPATH/persist.prop' >> "$SERV"; [ -n "$SDAT" ] && { sed -i -e '$a NOP="$(find /data/app -maxdepth 5 -type f \( -name "libumeng-spy.so" -o -name "libweibosdkcore.so" -o -name "libwind.so" \))"\nfor FILE in $NOP; do\n  [ ! -f "$FILE.nop" ] && mv -f "$FILE" "$FILE".nop\ndone\n' "$SERV"; }; awk -v services="$(echo "$ASERV" | tr '\n' ' ' | sed 's/ *$//')" '{print} END {print "(sleep 69\n  for service in " services "; do\n    for pid in $(pidof $service); do\n      renice -n -6 \"$pid\"; ionice -c 1 -n 3 -p \"$pid\"\n    done\n  done\n)&"}' "$SERV" > tmp && mv tmp "$SERV"
fi
[ -z "$D_MIXERS" ] && { $AML && . "$MODPATH"/files/telperion.sh || . "$MODPATH"/common/telperion.sh; }
if ! $AML; then
  sed -i "s/<MODID>/$MODID/" "$MODPATH"/.aml.sh
  for i in "earendil.sh"; do
    sed -i "/\. \"\$MODPATH\"\/common\/${i}/s/^/# /" "$MODPATH/common/nauglamir.sh"; rm -f "$MODPATH"/common/$i
  done
  for i in "nauglamir.sh" "helluin.sh" "laurelin.sh" "telperion.sh"; do
    cp -f "$MODPATH"/common/$i "$MODPATH"/files/$i
  done
  rm -f "$VALI"/vc.xml; rm -f "$VALI"/svc.xml; rm -f "$VALI"/db.xml; rm -f "$VALI"/_; rm -f "$VALI"/tools.tar.xz
fi
##########################################################################################