##########################################################################################
if [ -n "$QCP" ]; then
  ! $AML && { ui_print " "; ui_print " - Patching mixers"; [ "$MIXNUM" -ge 5 ] && ui_print "   $MIXNUM found, be patient, patching might take a while"; }
  for OFILE in ${MIXS}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"
    full="$(grep -E -o 'headphones(-(and-haptics|generic|dsd|44\.1|advanced|aux|advanced-44\.1|aux-44\.1|ce|no-ce|44\.1-ce|hifi-filter))?|headphone(-(dsd|generic))?|anc-(off-)?headphones|asrc-mode|true-native-mode' "$FILE" | sort -u)"; grep -q "SLIM_0_RX XTLoggingDisable" "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="SLIM_0_RX XTLoggingDisable"]' "TRUE"; grep -q "HiFi Function" "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="HiFi Function"]' "On"; grep -q "HiFi Filter" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="HiFi Filter"]' "0"
    if grep -q "RX_FIR Filter" "$TMD"; then
      patch_xml -u "$FILE" '/mixer/ctl[@name="RX_FIR Filter"]' "OFF"
      for panam in ${full}; do
        patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX_FIR Filter\"]" "OFF"
      done
      unset full
    fi
    grep -q "AUX_HPF Enable" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="AUX_HPF Enable"]' "Off"; grep -q "RX_HPH HD2 MODE" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="RX_HPH HD2 MODE"]' "ON"; [ "$Q_DSPOD" == "enable" ] && grep -q "Compress Gapless Playback" "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="Compress Gapless Playback"]' "On"
    if grep -q "MultiMedia5_RX QOS Vote" "$TMD"; then
      if grep -q "MultiMedia5_RX QOS Vote" "$FILE"; then
        patch_xml -u "$FILE" '/mixer/ctl[@name="MultiMedia5_RX QOS Vote"]' "Enable"; patch_xml -u "$FILE" '/mixer/path[@name="low-latency-playback resume"]/ctl[@name="MultiMedia5_RX QOS Vote"]' "Enable"
      else
        patch_xml -s "$FILE" '/mixer/ctl[@name="MultiMedia5_RX QOS Vote"]' "Enable"; grep -q "low-latency-playback resume" "$FILE" && patch_xml -s "$FILE" '/mixer/path[@name="low-latency-playback resume"]/ctl[@name="MultiMedia5_RX QOS Vote"]' "Enable"
      fi
    fi
    if grep -q "PM_QOS Vote" "$TMD"; then
      if grep -q "PM_QOS Vote" "$FILE"; then
        patch_xml -u "$FILE" '/mixer/ctl[@name="PM_QOS Vote"]' "Enable"; patch_xml -u "$FILE" '/mixer/path[@name="PM_QOS Vote"]/ctl[@name="PM_QOS Vote"]' "Enable"
      else
        patch_xml -s "$FILE" '/mixer/ctl[@name="PM_QOS Vote"]' "Enable"; patch_xml -s "$FILE" '/mixer/path[@name="PM_QOS Vote"]/ctl[@name="PM_QOS Vote"]' "Enable"
      fi
    fi
    grep -q "VOTE Against Sleep" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="VOTE Against Sleep"]' "Enable"; grep -q "VOTE Against Sleep" "$TMD" && ! grep -q "VOTE Against Sleep" "$FILE" && patch_xml -s "$FILE" '/mixer/ctl[@name="VOTE Against Sleep"]' "Enable"
    if grep -q "DSD_L IF MUX" "$FILE" || grep -q "DSD_L Switch" "$FILE"; then
      names="$(grep -E -o 'headphone[^ ]*-dsd' "$FILE" | sort -u)"
      for panam in ${names}; do
        grep -q 'SLIM_2_RX SetCalMode' "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"SLIM_2_RX SetCalMode\"]" "CAL_MODE_NONE"; grep -q 'SLIM_2_RX Format' "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"SLIM_2_RX Format\"]" "UNPACKED"; grep -q 'RX_CDC_DMA_5 RX Format' "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX_CDC_DMA_5 RX Format\"]" "UNPACKED"
      done
      unset names
    fi
  done
  purge
  MIXS_NESTED="$(find "$MODPATH" -type f -name "mixer_paths*.xml")"
  for FILE in ${MIXS_NESTED}; do
    if grep -q 'LINEOUT1 Volume' "$TMD"; then
      MLGA="$(tinymix get 'LINEOUT1 Volume' 2>/dev/null | awk -F'[>)]' '{print $2}')"
      if [ -n "$MLGA" ]; then
        while IFS= read -r ctl; do
          patch_xml -u "$FILE" "/mixer/ctl[@name=\"$ctl\"]" "$((MLGA - 1))"
        done < <(grep -E -o "LINEOUT[0-7] Volume" "$FILE" | sort -u)
      fi
      unset ctl
    fi
    if [ -n "$Q_AGA_PROCEED" ]; then
      names="$(grep -E -o 'headphone(s(-generic)?|(-generic)?)' "$FILE" | sort -u)"; AGVAL="$Q_AGA"; [ "$Q_AGA" -gt "$MAXAG" ] && AGVAL="$MAXAG"
      for panam in ${names}; do
        for chph in "HPHL" "HPHR"; do
          patch_xml -u "$FILE" "/mixer/ctl[@name=\"$chph Volume\"]" "$AGVAL"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$chph Volume\"]" "$AGVAL"
        done
      done
      unset names
    fi
  done
  purge
  if [ -n "$Q_HDGA_PROCEED" ]; then
    for FILE in ${MIXS_NESTED}; do
      full="$(grep -E -o 'headphones(-(and-haptics|generic|dsd|44\.1|advanced|aux|advanced-44\.1|aux-44\.1|ce|no-ce|44\.1-ce|hifi-filter))?|headphone(-(dsd|generic))?|anc-(off-)?headphones|asrc-mode|true-native-mode' "$FILE" | sort -u)"
      for panam in ${full}; do
        while IFS= read -r ctl; do
            patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$ctl\"]" "$Q_HDGA"
        done < <(grep -E -o 'RX[0-4] (Digital Volume|Mix Digital Volume)|RX_RX[0-4] (Digital Volume|Mix Digital Volume)' "$TMD" | sort -u)
      done
      unset ctl
      while IFS= read -r ctl; do
        patch_xml -s "$FILE" "/mixer/path[@name=\"bt-a2dp\"]/ctl[@name=\"$ctl\"]" "$Q_HDGA"
      done < <(grep -E -o 'RX[0-4] (Digital Volume|Mix Digital Volume)|RX_RX[0-4] (Digital Volume|Mix Digital Volume)' "$TMD" | sort -u)
      unset ctl
      if strings "$PHAL64" 2>/dev/null | grep -q 'RX_RX0 Digital Volume' && ! grep -q 'RX_RX0 Digital Volume' "$TMD" && ! grep -q 'RX_RX0 Digital Volume' "$FILE"; then
        for panam in ${full}; do
          for crx in "RX_RX0" "RX_RX1"; do
            patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$crx Digital Volume\"]" "$Q_HDGA"
          done
        done
      fi
      unset full
    done
    purge
  fi
  if [ "$Q_DSPOD" == "disable" ] && grep -q "Compress Playback \(8\|15\|28\|29\|30\|31\|32\|41\) Volume" "$TMD"; then
    for FILE in ${MIXS_NESTED}; do
      full="$(grep -E -o 'headphones(-(and-haptics|generic|dsd|44\.1|advanced|aux|advanced-44\.1|aux-44\.1|ce|no-ce|44\.1-ce|hifi-filter))?|headphone(-(dsd|generic))?|anc-(off-)?headphones|asrc-mode|true-native-mode' "$FILE" | sort -u)"
      for panam in ${full}; do
        for v in {8,15,28,29,30,31,32,41}; do
          grep -q "Compress Playback $v Volume" "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"Compress Playback $v Volume\"]" "0 0"
        done
      done
      unset full
    done
    purge
  fi

  if [ -n "$Q_HCOMP" ]; then
    for FILE in ${MIXS_NESTED}; do
      full="$(grep -E -o 'headphones(-(and-haptics|generic|dsd|44\.1|advanced|aux|advanced-44\.1|aux-44\.1|ce|no-ce|44\.1-ce|hifi-filter))?|headphone(-(dsd|generic))?|anc-(off-)?headphones|asrc-mode|true-native-mode' "$FILE" | sort -u)"
      for panam in ${full}; do
        while IFS= read -r ctl; do
          patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$ctl\"]" "0"
        done < <(grep -E -o 'COMP[0-6] (Switch|RX[1-2])|COMP[0-4]|RX_COMP[0-4] Switch|HPH[LR]_COMP Switch|HPH[LR] Compander' "$TMD" | sort -u)
      done
      unset full ctl
    done
    purge
  fi
  if [ -n "$Q_SDGA_PROCEED" ]; then
    for FILE in ${MIXS_NESTED}; do
      names="$(grep -E -o 'speaker|speaker(-mono|-mono-2|-top|-bottom|-left|-right)' "$FILE" | sort -u)"
      for panam in ${names}; do
        while IFS= read -r ctl; do
          patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$ctl\"]" "$Q_SDGA"
        done < <(grep -E -o 'WSA_RX[0-1] Digital Volume|RX_RX[0-1] Digital Volume|RX0 Digital Volume|RX1 Digital Volume|RX7 Digital Volume|RX8 Digital Volume' "$TMD" | sort -u)
      done
      unset ctl
      if [ "$Q_SDGA" -ge 95 ]; then
        if grep -q 'SPKR Left Boost Max State' "$FILE" || grep -q 'SPKR Right Boost Max State' "$FILE"; then
          spk1="$(grep -E -o 'speaker|speaker(-mono|-top|-left)' "$FILE" | sort -u)"
          for sname in ${spk1}; do
            patch_xml -s "$FILE" "/mixer/path[@name=\"$sname\"]/ctl[@name=\"SPKR Left Boost Max State\"]" "NO_MAX_STATE"
          done
          unset spk1
          spk2="$(grep -E -o 'speaker|speaker(-mono-2|-bottom|-right)' "$FILE" | sort -u)"
          for sname2 in ${spk2}; do
            patch_xml -s "$FILE" "/mixer/path[@name=\"$sname2\"]/ctl[@name=\"SPKR Right Boost Max State\"]" "NO_MAX_STATE"
          done
          unset spk2
        fi
      fi
      unset names
    done
    purge
  fi
  if [ -n "$Q_SCOMP" ]; then
    for FILE in ${MIXS_NESTED}; do
      names="$(grep -E -o 'speaker|speaker(-mono|-mono-2|-top|-bottom|-left|-right)' "$FILE" | sort -u)"
      for panam in ${names}; do
        while IFS= read -r ctl; do
          patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$ctl\"]" "0"
        done < <(grep -E -o 'WSA_COMP[1-2] Switch|Spkr(Left|Right|Top|Bottom) COMP Switch|COMP[7-8] Switch' "$FILE" | sort -u)
      done
      unset names ctl
    done
    purge
  fi
  if [ -n "$Q_BTCSMPL_PROCEED" ]; then
    for FILE in ${MIXS_NESTED}; do
      for panam in ${names}; do
        patch_xml -u "$FILE" "/mixer/ctl[@name=\"$panam\"]" "$Q_BTCSMPL"; patch_xml -s "$FILE" "/mixer/path[@name=\"bt-a2dp\"]/ctl[@name=\"$panam\"]" "$Q_BTCSMPL"
      done < <(grep -E -o 'BT SampleRate(RX|TX)' "$TMD"| sort -u)
      unset names
      for CTL in "SLIM7_RX ADM Channels" "AFE Input Channels" "TWS Channel Mode"; do
        grep -q "$CTL" "$FILE" && patch_xml -s "$FILE" "/mixer/path[@name=\"bt-a2dp\"]/ctl[@name=\"$CTL\"]" "Two"
      done
      grep -q 'HFP_SLIM7_UL_HL Switch' "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="HFP_SLIM7_UL_HL Switch"]' "0"
    done
    purge
  fi
  if [ -n "$Q_CBIT_PROCEED" ] || [ -n "$Q_HDSPBW" ]; then
    for FILE in ${MIXS_NESTED}; do
      [ -n "$Q_HDSPBW" ] && Q_BW="$Q_HDSPBW" || { case "$Q_CBIT" in "S16_LE") Q_BW="16" ;; "S24_3LE"|"S24_LE") Q_BW="24" ;; "S32_LE") Q_BW="32" ;; esac; }; [ -n "$Q_BW" ] && grep -q 'ASM Bit Width' "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="ASM Bit Width"]' "$Q_BW"
      for CTL in "RX_CDC_DMA_RX_0" "WSA_CDC_DMA_RX_0" "SEC_MI2S_RX" "INT0_MI2S_RX" "MI2S_RX" "SLIM_0_RX" "SLIM_5_RX" "SLIM_6_RX" "USB_AUDIO_RX"; do
        grep -q "$CTL Format" "$TMD" && patch_xml -s "$FILE" "/mixer/ctl[@name=\"$CTL Format\"]" "$Q_CBIT"
      done
      [ "$OEM" != "LG" ] && grep -q 'QUAT_MI2S_RX' "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="QUAT_MI2S_RX Format"]' "$Q_CBIT"; [ -n "$V30" ] || [ -n "$G7" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="TERT_MI2S_RX Format"]' "$Q_CBIT"; [ -n "$rog5" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="PRI_MI2S_RX Format"]' "$Q_CBIT"
    done
    purge
  fi
  if [ -n "$Q_CSMPL_PROCEED" ]; then
    for FILE in ${MIXS_NESTED}; do
      for CTL in "RX_CDC_DMA_RX_0" "WSA_CDC_DMA_RX_0" "SEC_MI2S_RX" "INT0_MI2S_RX" "MI2S_RX" "SLIM_0_RX" "SLIM_5_RX" "SLIM_6_RX" "USB_AUDIO_RX"; do
        grep -q "$CTL SampleRate" "$TMD" && patch_xml -s "$FILE" "/mixer/ctl[@name=\"$CTL SampleRate\"]" "$Q_CSMPL"
      done
      grep -q "SLIM_2_RX SampleRate" "$TMD" && { case "$Q_CSMPL" in "KHZ_176P4"|"KHZ_192"|"KHZ_352P8"|"KHZ_384") patch_xml -s "$FILE" "/mixer/ctl[@name=\"SLIM_2_RX SampleRate\"]" "$Q_CSMPL";; esac; }; [ "$OEM" != "LG" ] && grep -q 'QUAT_MI2S_RX SampleRate' "$TMD" && patch_xml -s "$FILE" '/mixer/ctl[@name="QUAT_MI2S_RX SampleRate"]' "$Q_CSMPL"; [ -n "$V30" ] || [ -n "$G7" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="TERT_MI2S_RX SampleRate"]' "$Q_CSMPL"; [ -n "$rog5" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="PRI_MI2S_RX SampleRate"]' "$Q_CSMPL"
    done
    purge
  fi
  for FILE in ${MIXS_NESTED}; do
    if [ "$FILE" != "mixer_paths_overlay_dynamic.xml" ] && [ "$FILE" != "mixer_paths_overlay_static.xml" ]; then
      if [ -n "$Q_CSMPL_PROCEED" ]; then
        case "$Q_CSMPL" in "KHZ_44P1"|"KHZ_88P2"|"KHZ_176P4"|"KHZ_352P8") mode=FRAC ;; *) mode=INT ;; esac
        grep -q 'ASRC0 Output Mode' "$FILE" && grep -q "asrc-mode" "$FILE" && { patch_xml -u "$FILE" '/mixer/path[@name="asrc-mode"]/ctl[@name="ASRC0 Output Mode"]' "$mode"; patch_xml -u "$FILE" '/mixer/path[@name="asrc-mode"]/ctl[@name="ASRC1 Output Mode"]' "$mode"; }
      fi
      grep -q 'RX INT3_2 NATIVE MUX' "$FILE" && grep -q 'RX INT4_2 NATIVE MUX' "$TMD" && grep -q "asrc-mode" "$FILE" && { patch_xml -d "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT1_2 NATIVE MUX\"]" "ON"; patch_xml -d "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT2_2 NATIVE MUX\"]" "ON"; patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT3_2 NATIVE MUX\"]" "ON"; patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT4_2 NATIVE MUX\"]" "ON"; }; grep -q 'ASRC0 MUX' "$FILE" && grep -q 'RX INT1 SEC MIX HPHL Switch' "$FILE" && grep -q 'RX INT3 SEC MIX LO1 Switch' "$TMD" && grep -q "asrc-mode" "$FILE" && { patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"ASRC0 MUX\"]" "ASRC_IN_LO1"; patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"ASRC1 MUX\"]" "ASRC_IN_LO2"; patch_xml -d "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT1 SEC MIX HPHL Switch\"]" "1"; patch_xml -d "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT2 SEC MIX HPHR Switch\"]" "1"; patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT3 SEC MIX LO1 Switch\"]" "1"; patch_xml -s "$FILE" "/mixer/path[@name=\"asrc-mode\"]/ctl[@name=\"RX INT4 SEC MIX LO2 Switch\"]" "1"; }
    fi
  done
  purge
  if grep -q 'RX HPH Mode' "$TMD"; then
    for FILE in ${MIXS_NESTED}; do
      if grep -q 'RX_HPH_PWR_MODE' "$FILE"; then
        patch_xml -u "$FILE" '/mixer/ctl[@name="RX_HPH_PWR_MODE"]' "LOHIFI"; names="$(grep -E -o 'hph-[^ ]*-mode' "$FILE" | sort -u)"
        for panam in ${names}; do
          patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX_HPH_PWR_MODE\"]" "LOHIFI"
        done
        unset names
      fi
      names="$(grep -E -o 'asrc-mode|headphones(-(generic|dsd|44\.1|advanced|aux|advanced-44\.1|aux-44\.1|ce|no-ce|44\.1-ce|hifi-filter))?|headphone(-(dsd|generic))?|true-native-mode|hph-[^ ]*-mode' "$FILE" | sort -u)"; hph="$(tinymix get 'RX HPH Mode' 2>/dev/null | sed 's/> //g' | sed 's/,//g')"
      if [ -n "$hph" ]; then
        if echo "$hph" | grep -q 'CLS_AB_HIFI'; then hphmode="CLS_AB_HIFI"; elif echo "$hph" | grep -q 'CLS_AB'; then hphmode="CLS_AB"; elif echo "$hph" | grep -q 'CLS_H_HIFI'; then hphmode="CLS_H_HIFI"; fi
        if [ -n "$hphmode" ]; then
          for panam in ${names}; do
            patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX HPH Mode\"]" "$hphmode"
          done
          patch_xml -u "$FILE" '/mixer/ctl[@name="RX HPH Mode"]' "$hphmode"
        fi
      fi
      unset names hph
    done
    purge
  fi
  for FILE in ${MIXS_NESTED}; do
    if [ "$FILE" != "mixer_paths_overlay_dynamic.xml" ] && [ "$FILE" != "mixer_paths_overlay_static.xml" ]; then
      if grep -q 'RX INT3 SEC MIX LO1 Switch' "$TMD" && grep -q 'RX INT4 SEC MIX LO2 Switch' "$TMD" && grep -q 'RX INT3_2 MUX' "$TMD" && grep -q 'RX INT4_2 MUX' "$TMD"; then
        names="$(grep -E -o 'headphone(s(-generic)?|(-generic)?)' "$FILE" | sort -u)"
        for panam in ${names}; do
          rx_values="$(awk -v name="$panam" '$0 ~ "<path name=\"" name "\">" , $0 ~ "</path>" { if ($0 ~ /SLIM RX[0-9] MUX/) { match($0, /RX[0-9]/); if (RLENGTH > 0) { print substr($0, RSTART, RLENGTH) } } }' "$FILE")"; rx1="$(echo "$rx_values" | awk 'NR==1')"; rx2="$(echo "$rx_values" | awk 'NR==2')"
          if [ -n "$rx1" ] && [ -n "$rx2" ]; then
            patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_2 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_2 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3 SEC MIX LO1 Switch\"]" "1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4 SEC MIX LO2 Switch\"]" "1"; [ -n "$Q_HCOMP" ] && grep -q 'COMP3 Switch' "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"COMP3 Switch\"]" "0"; [ -n "$Q_HCOMP" ] && grep -q 'COMP4 Switch' "$TMD" && patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"COMP4 Switch\"]" "0"
          fi
        done
        [ -n "$rx1" ] && [ -n "$rx2" ] && LO=1
        unset names rx_values rx1 rx2
      fi
    fi
  done
  purge
  if [ -n "$Q_BIQHPF" ]; then
    for FILE in ${MIXS_NESTED}; do
      if [ "$FILE" != "mixer_paths_overlay_dynamic.xml" ] && [ "$FILE" != "mixer_paths_overlay_static.xml" ]; then
        names="$(grep -E -o 'headphone(s(-generic)?|(-generic)?)' "$FILE" | sort -u)"
        if grep -q 'SLIM RX[0-9] MUX' "$FILE"; then
          grep -q 'IIR0.* INP' "$TMD" && grep -q 'IIR1.* INP' "$TMD" && IIR="IIR0" IIR2="IIR1" || grep -q 'IIR1.* INP' "$TMD" && grep -q 'IIR2.* INP' "$TMD" && IIR="IIR1" IIR2="IIR2"
          for panam in $names; do
            rx_values=$(awk -v name="$panam" '$0 ~ "<path name=\"" name "\">" , $0 ~ "</path>" { if ($0 ~ /SLIM RX[0-9] MUX/) { match($0, /RX[0-9]/); if (RLENGTH > 0) print substr($0, RSTART, RLENGTH) } }' "$FILE"); rx1=$(echo "$rx_values" | awk 'NR==1'); rx2=$(echo "$rx_values" | awk 'NR==2')
            eval "$(awk -v panam="$panam" '/<path name="'"$panam"'">/,/<\/path>/ { if (/<ctl name="RX INT0_2 MUX".*\/>/) { print "MIX=INT0_1\nMIX2=INT1_1\nMUX=INT0_2\nMUX2=INT1_2"; next } if (/<ctl name="RX INT0_1 MIX1 INP0".*\/>/) { print "MIX=INT0_1\nMIX2=INT1_1\nMUX=INT1_2\nMUX2=INT2_2"; next } if (/<ctl name="RX INT2_2 MUX".*\/>/) { print "MIX=INT1_1\nMIX2=INT2_1\nMUX=INT1_2\nMUX2=INT2_2"; next } if (/<ctl name="RX INT2_1 MIX1 INP0".*\/>/) { print "MIX=INT1_1\nMIX2=INT2_1\nMUX=INT1_2\nMUX2=INT2_2"; next } }' "$FILE")"
            if [ -n "$rx1" ] && [ -n "$rx2" ] && [ -n "$IIR" ] && [ -n "$IIR2" ] && [ -n "$MIX" ] && [ -n "$MIX2" ] && [ -n "$MUX" ] && [ -n "$MUX2" ]; then
              for iirnum in "IIR" "IIR2"; do for num in 1 2 3 4 5; do patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"${iirnum} Enable Band${num}\"]" "1"; done; done
              patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MUX MUX\"]" "ZERO"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MUX2 MUX\"]" "ZERO"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP0 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP0 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP0\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP0\"]" "$IIR2"
              grep -q "RX $MIX INTERP" "$TMD" && grep -q "RX $MIX2 INTERP" "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX INTERP\"]" "RX $MIX MIX1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 INTERP\"]" "RX $MIX2 MIX1"; }
              grep -q 'RX INT3_2 MUX' "$TMD" && grep -q 'RX INT4_2 MUX' "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_2 MUX\"]" "ZERO"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_2 MUX\"]" "ZERO"; }
              grep -q 'RX INT3_1 MIX1 INP0' "$TMD" && grep -q 'RX INT4_1 MIX1 INP0' "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_1 MIX1 INP0\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_1 MIX1 INP0\"]" "$IIR2"; }
              grep -q "RX INT3_1 INTERP" "$TMD" && grep -q "RX INT4_1 INTERP" "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_1 INTERP\"]" "RX INT3_1 MIX1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_1 INTERP\"]" "RX INT4_1 MIX1"; }
              IIRVOL=$( [ -n "$Q_HDGA_PROCEED" ] && echo "$Q_HDGA" || echo 84 ); patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP0 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP0 Volume\"]" "$IIRVOL"
              grep -q "$IIR INP1 MUX" "$TMD" && {
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP1 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP1 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP1\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP1\"]" "$IIR2"
                (grep -q 'RX INT3_1 MIX1 INP1' "$TMD" && grep -q 'RX INT4_1 MIX1 INP1' "$TMD" && [ -n "$LO" ]) && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_1 MIX1 INP1\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_1 MIX1 INP1\"]" "$IIR2"; }
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP1 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP1 Volume\"]" "$IIRVOL"
              }
              grep -q "$IIR INP2 MUX" "$TMD" && {
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP2 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP2 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP2\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP2\"]" "$IIR2"
                (grep -q 'RX INT3_1 MIX1 INP2' "$TMD" && grep -q 'RX INT4_1 MIX1 INP2' "$TMD" && [ -n "$LO" ]) && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_1 MIX1 INP2\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_1 MIX1 INP2\"]" "$IIR2"; }
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP2 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP2 Volume\"]" "$IIRVOL"
              }
              grep -q "$IIR INP3 MUX" "$TMD" && {
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP3 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP3 MUX\"]" "$rx2"
                (grep -q 'RX INT3_1 MIX1 INP3' "$TMD" && grep -q 'RX INT4_1 MIX1 INP3' "$TMD" && [ -n "$LO" ]) && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT3_1 MIX1 INP3\"]" "$IIR"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX INT4_1 MIX1 INP3\"]" "$IIR2"; }
                patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR INP3 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$IIR2 INP3 Volume\"]" "$IIRVOL"
              }
              SLIM_H=1
            fi
          done
          [ -n "$SLIM_H" ] && awk -v iir="$IIR" -v iir2="$IIR2" 'BEGIN{indent1="  ";indent2="    ";block=indent1"<path name=\"silmaril\">";for(b=1;b<=5;b++)for(i=0;i<=4;i++){value=(i==0)?"268435456":"0";block=block"\n"indent2"<ctl name=\""iir" Band"b"\" id=\""i"\" value=\""value"\"/>\n"indent2"<ctl name=\""iir2" Band"b"\" id=\""i"\" value=\""value"\"/>"}block=block"\n"indent1"</path>"}$0~/<path name="sidetone-iir">/{print block"\n"$0;next}{print}' "$FILE" > tmp && mv tmp "$FILE"
        fi
        if grep -q 'RX_MACRO RX[0-9] MUX' "$FILE"; then
          for panam in ${names}; do
            rx_values="$(awk -v name="$panam" '$0 ~ "<path name=\"" name "\">" , $0 ~ "</path>" { if ($0 ~ /RX_MACRO RX[0-9] MUX/) { match($0, /RX[0-9]/); if (RLENGTH > 0) { print substr($0, RSTART, RLENGTH) } } }' "$FILE")"; rx1="$(echo "$rx_values" | awk 'NR==1')"; rx2="$(echo "$rx_values" | awk 'NR==2')"
            eval "$(awk -v panam="$panam" '/<path name="'"$panam"'">/,/<\/path>/ { if (/<ctl name="RX INT0_2 MUX".*\/>/) { print "MIX=INT0_1\nMIX2=INT1_1\nMUX=INT0_2\nMUX2=INT1_2"; next } if (/<ctl name="RX INT0_1 MIX1 INP0".*\/>/) { print "MIX=INT0_1\nMIX2=INT1_1\nMUX=INT1_2\nMUX2=INT2_2"; next } if (/<ctl name="RX INT2_2 MUX".*\/>/) { print "MIX=INT1_1\nMIX2=INT2_1\nMUX=INT1_2\nMUX2=INT2_2"; next } if (/<ctl name="RX INT2_1 MIX1 INP0".*\/>/) { print "MIX=INT1_1\nMIX2=INT2_1\nMUX=INT1_2\nMUX2=INT2_2"; next } }' "$FILE")"
            if { [ -n "$rx1" ] && [ -n "$rx2" ]; } && { [ -n "$MIX" ] && [ -n "$MIX2" ]; } && { [ -n "$MUX" ] && [ -n "$MUX2" ]; }; then
              IIRVOL=$( [ -n "$Q_HDGA_PROCEED" ] && echo "$Q_HDGA" || echo 84 )
              for iirnum in IIR0 IIR1; do for num in 1 2 3 4 5; do patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"$iirnum Enable Band$num\"]" "1"; done; done
              patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP0 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP0 MUX\"]" "$rx2"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MUX MUX\"]" "ZERO"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MUX2 MUX\"]" "ZERO"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP0\"]" "IIR0"; patch_xml -u "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP0\"]" "IIR1"
              grep -q "RX $MIX INTERP" "$TMD" && grep -q "RX $MIX2 INTERP" "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX INTERP\"]" "RX $MIX MIX1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 INTERP\"]" "RX $MIX2 MIX1"; }
              patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP0 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP0 Volume\"]" "$IIRVOL"
              grep -q 'IIR0 INP1 MUX' "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP1 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP1 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP1\"]" "IIR0"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP1\"]" "IIR1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP1 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP1 Volume\"]" "$IIRVOL"; }
              grep -q 'IIR0 INP2 MUX' "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP2 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP2 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX MIX1 INP2\"]" "IIR0"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"RX $MIX2 MIX1 INP2\"]" "IIR1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP2 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP2 Volume\"]" "$IIRVOL"; }
              grep -q 'IIR0 INP3 MUX' "$TMD" && { patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP3 MUX\"]" "$rx1"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP3 MUX\"]" "$rx2"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR0 INP3 Volume\"]" "$IIRVOL"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"IIR1 INP3 Volume\"]" "$IIRVOL"; }
              MACRO_H=1
            fi
          done
          [ -n "$MACRO_H" ] && awk -F'"' '/ctl name="IIR0 Band1" id="0" value="268435456"/||/ctl name="IIR0 Band1" id="1" value="0"/{f=1}/ctl name="IIR0 Band1" value="00 00 00 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"/{f=2}BEGIN{i1="  ";i2="    "}f==1&&$0~/<path name="sidetone-iir">/{b=i1"<path name=\"silmaril\">";for(n=1;n<=5;n++)for(i=0;i<=4;i++){v=(i==0)?"268435456":"0";b=b"\n"i2"<ctl name=\"IIR0 Band"n"\" id=\""i"\" value=\""v"\"/>\n"i2"<ctl name=\"IIR1 Band"n"\" id=\""i"\" value=\""v"\"/>"}b=b"\n"i1"</path>";print b"\n"$0;next}f==2&&$0~/<path name="sidetone-iir">/{b=i1"<path name=\"silmaril\">";for(n=1;n<=5;n++){b=b"\n"i2"<ctl name=\"IIR0 Band"n"\" value=\"00 00 00 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00\" />\n"i2"<ctl name=\"IIR1 Band"n"\" value=\"00 00 00 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00\" />"}b=b"\n"i1"</path>";print b"\n"$0;next}{print}' "$FILE" > tmp && mv tmp "$FILE"
        fi
        if [ -n "$SLIM_H" ] || [ -n "$MACRO_H" ]; then
          for panam in ${names}; do
            sed -i "/<path name=\"$panam\">/a \ \ \ \ \ <path name=\"silmaril\"/>" "$FILE"
          done
          sed -i -r '/<path name="sidetone-headphones">/,/<\/path>/d' "$FILE"
        fi
        unset names
      fi
    done
    purge
  fi
  if [ "$OEM" == "LG" ] && [ -n "$Q_LGHIM" ]; then
    for FILE in ${MIXS_NESTED}; do
      grep -q "HIFI Custom Filter" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="HIFI Custom Filter"]' "6"; grep -q "Es9018 AVC Volume" "$FILE" && patch_xml -u "$FILE" '/mixer/ctl[@name="Es9018 AVC Volume"]' "0"; ess="$(grep -E -o '(?![^ ]*filter)headphones-hifi-dac[^ ]*' "$FILE" | sort -u)"
      for panam in ${ess}; do
        patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"Es9018 Master Volume\"]" "0"; patch_xml -s "$FILE" "/mixer/path[@name=\"$panam\"]/ctl[@name=\"Es9018 HEADSET TYPE\"]" "3"
      done
    done
    purge
  fi
  for FILE in ${MIXS_NESTED}; do
    if [ "$FILE" != "mixer_paths_overlay_dynamic.xml" ] && [ "$FILE" != "mixer_paths_overlay_static.xml" ]; then
      if grep -q '<path name="line">' "$FILE"; then
        names="$(grep -E -o 'headphone(s(-generic)?|(-generic)?)' "$FILE" | sort -u)"
        for panam in ${names}; do
          sed -i "/<path name=\"$panam\">/a \ \ \ \ <path name=\"line\"/>" "$FILE"
        done
        unset names
        sed -i '\#<path name="line">#,\#</path>#s#<path name="headphones"/>#<!-- <path name="headphones" /> -->#' "$FILE"
        if strings "$PHAL64" 2>/dev/null | grep -q "hph-class-ab-mode" && ! grep -q "hph-class-ab-mode" "$FILE"; then
          sed -i '/<path name="line">/i\<path name="hph-class-ab-mode">\n\ \ </path>' "$FILE"
        fi
      fi
    fi
  done
  purge
fi
if [ -n "$TENZ" ]; then
  ! $AML && { ui_print " "; ui_print " - Patching mixers"; }
  for OFILE in ${MIXS}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
    case $T_CSMPL in "SR_44P1K") US=44100 ;; "SR_48K") US=48000 ;; "SR_88P2K") US=88200 ;; "SR_96K") US=96000 ;; "SR_176P4K") US=176400 ;; "SR_192K") US=192000 ;; esac
    [ -n "$T_CSAMPL_PROCEED" ] && { patch_xml -s "$FILE" '/mixer/ctl[@name="TDM_0_RX Sample Rate"]' "$T_CSMPL"; patch_xml -s "$FILE" '/mixer/ctl[@name="USB_RX Sample Rate"]' "$T_CSMPL"; }; [ -n "$T_CBIT" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="USB_RX Format"]' "$T_CBIT"; [ -n "$T_CBTSAMPL_PROCEED" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="BT_RX Sample Rate"]' "$T_CSMPL"; [ -n "$T_CBTBIT" ] && patch_xml -s "$FILE" '/mixer/ctl[@name="BT_RX Format"]' "$T_CBIT"
  done
  purge
fi
if [ -n "$MTK" ]; then
  ! $AML && { ui_print " "; ui_print " - Patching mixers"; }
  for OFILE in ${MIXA}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
    if [ -n "$M_IMP" ]; then
      patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Audio HP Impedance"]' "$M_IMP"; patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Audio HP Impedance Setting"]' "$M_IMP"
    fi
    [ -n "$M_DHPF" ] && patch_xml -s "$FILE" '/mixercontrol/kctl[@name="DAC HPF Switch"]' "$M_DHPF"
    if [ -n "$M_GAIN_PROCEED" ]; then
      patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Headset_PGAL_GAIN"]' "$M_GAIN"; patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Headset_PGAR_GAIN"]' "$M_GAIN"; patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Lineout_PGAR_GAIN"]' "$M_GAIN"; patch_xml -s "$FILE" '/mixercontrol/kctl[@name="Lineout_PGAL_GAIN"]' "$M_GAIN"
    fi
  done
  purge
fi
if [ -n "$EXY" ]; then
  ! $AML && { ui_print " "; ui_print " - Patching mixers"; }
  for OFILE in ${MIXS}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
    patch_xml -s "$FILE" '/mixer/ctl[@name="Output Ramp Up"]' "0ms/6dB"; patch_xml -s "$FILE" '/mixer/ctl[@name="Output Ramp Down"]' "0ms/6dB"; patch_xml -s "$FILE" '/mixer/ctl[@name="Virtual Bass Boost"]' "Off"; patch_xml -s "$FILE" '/mixer/ctl[@name="Speaker Gain"]' "25"
    if [ -n "$E_CSMPL_PROCEED" ]; then
      patch_xml -s "$FILE" '/mixer/ctl[@name="Sample Rate 2"]' "$E_CSMPL"; patch_xml -s "$FILE" '/mixer/ctl[@name="Sample Rate 3"]' "$E_CSMPL"; patch_xml -s "$FILE" '/mixer/ctl[@name="ASYNC Sample Rate 2"]' "$E_CSMPL"
    fi
  done
  purge
  for OFILE in ${MIXG}; do
    nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"; format_file "$FILE"
    patch_xml -s "$FILE" '/mixer/ctl[@name="HPOUT2L Impedance Volume"]' "117"; patch_xml -s "$FILE" '/mixer/ctl[@name="HPOUT2R Impedance Volume"]' "117"
  done
  purge
fi
##########################################################################################