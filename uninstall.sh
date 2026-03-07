# Don't modify anything after this
rm -rf /data/property/*
rm -f /data/media/0/silmaril_*
if [ -f "$INFO" ]; then
  while read -r LINE; do
    if [ "$(echo -n "$LINE" | tail -c 1)" == "~" ]; then
      continue
    elif [ -f "$LINE~" ]; then
      mv -f "$LINE~" "$LINE"
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