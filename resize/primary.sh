#!/bin/bash
OUT=/Users/Shared/ss_size.txt
last=""
while true; do
  size=$(osascript -e 'tell application "System Events" to tell process "Screen Sharing" to get size of window 1' 2>/dev/null)
  if [ -n "$size" ] && [ "$size" != "$last" ]; then
    echo "$size" > "$OUT"; last="$size"
  fi
  sleep 0.25
done
