#!/bin/bash
OUT=/Users/Shared/sandbox_screen_size.txt
TMP="$OUT.tmp"
last=""
while true; do
  size=$(osascript -e 'tell application "System Events" to tell process "Screen Sharing" to get size of window 1' 2>/dev/null)
  if [ -n "$size" ] && [ "$size" != "$last" ]; then
    printf '%s\n' "$size" > "$TMP" && mv "$TMP" "$OUT"
    last="$size"
  fi
  sleep 0.1
done
