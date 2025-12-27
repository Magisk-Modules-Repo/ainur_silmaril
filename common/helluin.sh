for i in ${POLS}; do
  [ "$(basename "$i")" == "audio_policy_configuration.xml" ] || continue; POLVER=$(awk -F '"' '/<audioPolicyConfiguration/{sub(/\.0$/,"",$2); print $2}' "$i" 2>/dev/null); [ -n "$POLVER" ] && break
done
[ -z "$POLVER" ] && POLVER=1
for OFILE in ${POLS}; do
  nest "$OFILE"; cp_ch "$ORIGDIR""$OFILE" "$FILE"
  case "$(basename "${FILE}")" in
  audio_policy_configuration.xml | audio_policy_configuration_ull.xml | audio_policy_configuration_le_offload_disabled.xml | audio_policy_configuration_bluetooth_legacy_hal.xml | audio_policy_configuration_a2dp_offload_disabled.xml)
    format_file "$FILE"; [ "$POLVER" -lt 7 ] && { D=","; C="|"; } || { D=" "; C=" "; }
    [ -n "$U_SDRC_PROCEED" ] && awk '{if (/<globalConfiguration/){if ($0 ~ /speaker_drc_enabled="true"/){gsub(/speaker_drc_enabled="true"/, "speaker_drc_enabled=\"false\"")}else if ($0 !~ /speaker_drc_enabled/){sub(/<globalConfiguration([^>]*>)/, "<globalConfiguration speaker_drc_enabled=\"false\"\\1")}} print}' "$FILE" > tmp && mv tmp "$FILE"; [ -n "$U_APDBR" ] && { sed -i '/<routes>/,/<\/routes>/{/sink="Earpiece"/b;/sink="Speaker"/b;/sink="Speaker Safe"/b;s/deep[_]?buffer([_ ](out(put)?))?,//g;s/,$//}' "$FILE"; dbp=""; } || { dbp="$(grep -E -o '<mixPort name=\"deep[_]?buffer([_ ](out(put)?))?\"' \"$FILE\" | sed 's/<mixPort name=\"([^\"]*)\"/\1/' | sort -u | awk '{printf "%s|", $0}' | sed 's/|$//')"; }; [ -n "$Q_DSPOD" ] && sed -i '/<routes>/,/<\/routes>/{/sink="Earpiece"/b;/sink="Speaker"/b;/sink="Speaker Safe"/b;s/compressed_offload,//g;s/,$//}' "$FILE"; [ -z "$U_BT_KEEPFX" ] && sed -i '/<routes>/,/<\/routes>/{/sink="Earpiece"/b;/sink="Speaker"/b;/sink="Speaker Safe"/b;s/(immersive_out|spatial[ _]out(put)?),//g;s/,$//}' "$FILE"; [ -n "$Q_DSPOD" ] && awk -v C="$C" '/<mixPort name="compress(ed_offload|_passthrough)" role="source"/ { in_block=1 } /<\/mixPort>/ { in_block=0 } !in_block && /AUDIO_OUTPUT_FLAG_DIRECT_PCM/ { flag_present=1 } !in_block && /flags="AUDIO_OUTPUT_FLAG_DIRECT/ && !flag_present { gsub(/flags="AUDIO_OUTPUT_FLAG_DIRECT/, "flags=\"AUDIO_OUTPUT_FLAG_DIRECT" C "AUDIO_OUTPUT_FLAG_DIRECT_PCM") } { print }' "$FILE" > tmp && mv tmp "$FILE"; rp="fast|direct_pcm"; [ -z "$U_APDBR" ] && { mp1="$rp|$dbp"; mp1=$(echo "$mp1" | sed 's/||*/|/g; s/^|//; s/|$//'); } || mp1="$rp"
    while IFS= read -r name; do
      awk -v C="$C" -v FLAG="AUDIO_OUTPUT_FLAG_RAW" -v NAME="$name" 'BEGIN {in_block=0;modified=0} /<mixPort name="/ {if($0~"name=\""NAME"\"") {in_block=1;modified=0;if($0~FLAG) {print;if($0~/\/>$/) in_block=0} else if($0~/flags="/) {sub(/"/,C FLAG"\"");modified=1;print} else if($0~/\/>$/) {sub(/\/>$/," flags=\""FLAG"\"/>");modified=1;print;in_block=0} else {sub(/>$/," flags=\""FLAG"\">");modified=1;print}} else print;next} /<\/mixPort>/ {if(in_block) {in_block=0;print} else print;next} in_block&&!modified {print} {print}' "$FILE" > tmp && mv tmp "$FILE"
    done < <(echo "$mp1" | tr '|' '\n')
    unset name
    for name in "USB Device Out" "USB Headset Out"; do
      sed -i "s/<route type=\"mix\" sink=\"$name\"/<route type=\"mux\" sink=\"$name\"/g" "$FILE"
    done
    unset name
    if { strings "$AFLN64" 2>/dev/null | grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT' || strings "$APED64" 2>/dev/null | grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT'; } && ! grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT' "$FILE"; then
      awk -v c="$C" '/<mixPort name="hifi_(playback|output)" role="source"/ {if($0~/flags="/) {if($0!~/AUDIO_OUTPUT_FLAG_BIT_PERFECT/) sub(/flags="/, "flags=\"AUDIO_OUTPUT_FLAG_BIT_PERFECT"c)} else sub(/\/>$/, " flags=\"AUDIO_OUTPUT_FLAG_BIT_PERFECT\"/>")} 1' "$FILE" > temp && mv temp "$FILE"
    fi
    for device in "Aux Line" "Wired Headset" "Wired Headphones" "Line" "HDMI" "USB Device Out" "USB Headset Out"; do
      awk -v device="$device" 'BEGIN { inside_devicePort = 0 } /<devicePort tagName="/ { if ($0 ~ "tagName=\"" device "\"") inside_devicePort = 1; print; next } /<\/devicePort>/ { inside_devicePort = 0; print; next } inside_devicePort && /<profile/ { print "<!--"; print; next } inside_devicePort && /\/>/ { print; print "-->"; next } { print }' "$FILE" > tmp && mv tmp "$FILE"
      if [ -z "$U_APFF" ] || [ "$U_APFF" == "add" ]; then
        for format in "AUDIO_FORMAT_PCM_8_BIT" "AUDIO_FORMAT_PCM_16_BIT" "AUDIO_FORMAT_PCM_24_BIT_PACKED" "AUDIO_FORMAT_PCM_8_24_BIT" "AUDIO_FORMAT_PCM_32_BIT"; do
          if strings "$APMD64" 2>/dev/null | grep -q "$format"; then
            awk -v device="$device" -v fmt="$format" -v rd="$D" 'BEGIN { inside_devicePort = 0; if (device == "HDMI" || device == "USB Device Out" || device == "USB Headset Out") { sample_rates = "dynamic"; chan_masks = "dynamic" } else { if (fmt == "AUDIO_FORMAT_PCM_8_BIT") { sample_rates = "8000"rd"11025"rd"12000"rd"16000"rd"22050"rd"24000"rd"32000"rd"44100"rd"48000" } else if (fmt == "AUDIO_FORMAT_PCM_16_BIT") { sample_rates = "44100"rd"48000"rd"88200"rd"96000"rd"176400"rd"192000" } else { sample_rates = "44100"rd"48000"rd"88200"rd"96000"rd"176400"rd"192000"rd"352800"rd"384000" }; chan_masks = "AUDIO_CHANNEL_OUT_STEREO" } } /<devicePort tagName="/ { if ($0 ~ "tagName=\""device"\"") inside_devicePort = 1; print; next } /<\/devicePort>/ { if (inside_devicePort) { inside_devicePort = 0; printf "                    <profile name=\"\" format=\"%s\"\n                             samplingRates=\"%s\"\n                             channelMasks=\"%s\"/>\n", fmt, sample_rates, chan_masks } print; next } { print }' "$FILE" > tmp && mv tmp "$FILE"
          fi
        done
      fi
    done
    unset device format
    mpnames="fast|raw|direct|direct_pcm"; [ -z "$U_APDBR" ] && { mp2="$mpnames|$dbp"; mp2=$(echo "$mp2" | sed 's/||*/|/g; s/^|//; s/|$//'); } || mp2="$mpnames"
    while IFS= read -r name; do
      awk -v name="$name" 'BEGIN {inside_mixPort=0} /<mixPort name="/ {if($0~"name=\""name"\"") inside_mixPort=1; print; next} /<\/mixPort>/ {inside_mixPort=0; print; next} inside_mixPort&&/<profile/ {print "<!--"; print; next} inside_mixPort&&/\/>/ {print; print "-->"; next} {print}' "$FILE" > tmp && mv tmp "$FILE"
      if [ -z "$U_APFF" ] || [ "$U_APFF" == "add" ]; then
        for format in "AUDIO_FORMAT_PCM_8_BIT" "AUDIO_FORMAT_PCM_16_BIT" "AUDIO_FORMAT_PCM_24_BIT_PACKED" "AUDIO_FORMAT_PCM_8_24_BIT" "AUDIO_FORMAT_PCM_32_BIT"; do
          if strings "$APMD" 2>/dev/null | grep -q "$format" || strings "$APMD64" 2>/dev/null | grep -q "$format"; then
            awk -v name="$name" -v fmt="$format" -v rd="$D" 'BEGIN {inside_mixPort=0; float_exists=0; if(fmt=="AUDIO_FORMAT_PCM_8_BIT") sample_rates="8000"rd"11025"rd"12000"rd"16000"rd"22050"rd"24000"rd"32000"rd"44100"rd"48000"; else if(fmt=="AUDIO_FORMAT_PCM_16_BIT") sample_rates="44100"rd"48000"rd"88200"rd"96000"rd"176400"rd"192000"; else sample_rates="44100"rd"48000"rd"88200"rd"96000"rd"176400"rd"192000"rd"352800"rd"384000"; chan_masks="AUDIO_CHANNEL_OUT_MONO"rd"AUDIO_CHANNEL_OUT_STEREO"rd"AUDIO_CHANNEL_OUT_2POINT1"rd"AUDIO_CHANNEL_OUT_QUAD"rd"AUDIO_CHANNEL_OUT_PENTA"rd"AUDIO_CHANNEL_OUT_5POINT1"rd"AUDIO_CHANNEL_OUT_6POINT1"rd"AUDIO_CHANNEL_OUT_7POINT1"} /<mixPort name="/ {if($0~"name=\""name"\"") inside_mixPort=1; print; next} /<\/mixPort>/ {if(inside_mixPort) {inside_mixPort=0; printf "                    <profile name=\"\" format=\"%s\"\n                             samplingRates=\"%s\"\n                             channelMasks=\"%s\"/>\n", fmt, sample_rates, chan_masks} print; next} inside_mixPort&&/<profile/&&/AUDIO_FORMAT_PCM_FLOAT/ {float_exists=1} {print}' "$FILE" > tmp && mv tmp "$FILE"
          fi
        done
      fi
      if strings "$APMD64" 2>/dev/null | grep -q 'AUDIO_FORMAT_PCM_FLOAT' || strings "$APMD" 2>/dev/null | grep -q 'AUDIO_FORMAT_PCM_FLOAT'; then
        case "$U_APFF" in ""|"add") BEH="add" ;; "force") BEH="force" ;; esac
        [ -n "$BEH" ] && awk -v name="$name" -v rd="$D" -v behav="$BEH" 'BEGIN {inside_mixPort=0; float_exists=0; sample_rates="44100"rd"48000"rd"88200"rd"96000"rd"176400"rd"192000"rd"352800"rd"384000"; chan_masks="AUDIO_CHANNEL_OUT_MONO"rd"AUDIO_CHANNEL_OUT_STEREO"rd"AUDIO_CHANNEL_OUT_2POINT1"rd"AUDIO_CHANNEL_OUT_QUAD"rd"AUDIO_CHANNEL_OUT_PENTA"rd"AUDIO_CHANNEL_OUT_5POINT1"rd"AUDIO_CHANNEL_OUT_6POINT1"rd"AUDIO_CHANNEL_OUT_7POINT1"} /<mixPort name="/ {if($0~"name=\""name"\"") inside_mixPort=1; print; next} /<\/mixPort>/ {if(inside_mixPort) {inside_mixPort=0; if(behav=="force"||(behav=="add"&&!float_exists)) printf "                    <profile name=\"\" format=\"AUDIO_FORMAT_PCM_FLOAT\"\n                             samplingRates=\"%s\"\n                             channelMasks=\"%s\"/>\n", sample_rates, chan_masks} print; next} inside_mixPort&&/<profile/&&/AUDIO_FORMAT_PCM_FLOAT/ {float_exists=1} {print}' "$FILE" > tmp && mv tmp "$FILE"
      fi
    done < <(echo "$mp2" | tr '|' '\n')
    unset device format name
    purge
  ;;
  usb_audio_policy_configuration.xml)
    format_file "$FILE"
    for name in "USB Device Out" "USB Headset Out"; do
      sed -i "s/<route type=\"mix\" sink=\"$name\"/<route type=\"mux\" sink=\"$name\"/g" "$FILE"
    done
    unset name
    if { strings "$AFLN64" 2>/dev/null | grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT' || strings "$APED64" 2>/dev/null | grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT'; } && ! grep -q 'AUDIO_OUTPUT_FLAG_BIT_PERFECT' "$FILE"; then
      awk '/<mixPort name="usb_device output" role="source"/ {sub(/flags="[^"]*"/, "flags=\"AUDIO_OUTPUT_FLAG_BIT_PERFECT\"") || sub(/[ \t]*\/>$/, " flags=\"AUDIO_OUTPUT_FLAG_BIT_PERFECT\"/>")} 1' "$FILE" > temp && mv temp "$FILE"
    fi
    purge
  ;;
  esac
done
purge
