#!/bin/bash
OUT=/Users/Shared/sandbox_screen_size.txt
TMP="$OUT.tmp"
last=""
while true; do
  size=$(osascript -e 'tell application "System Events" to tell process "Screen Sharing" to get size of window 1' 2>/dev/null)
  if [ -n "$size" ] && [ "$size" != "$last" ]; then
    printf '%s\n' "$size" > "$TMP" && mv "$TMP" "$OUT"
    last="$size"
    # snap viewport back to top-left so sandbox {0,0} stays visible
    osascript -e 'tell application "System Events" to tell process "Screen Sharing"
      try
        set value of scroll bar 1 of scroll area 1 of window 1 to 0
      end try
      try
        set value of scroll bar 2 of scroll area 1 of window 1 to 0
      end try
    end tell' 2>/dev/null
  fi
  sleep 0.1
done
