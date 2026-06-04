#!/bin/bash
IN=/Users/Shared/ss_size.txt
CHROME=28
while true; do
  if [ -f "$IN" ]; then
    size=$(cat "$IN")
    w=$(echo "$size" | cut -d, -f1 | tr -d ' ')
    h=$(echo "$size" | cut -d, -f2 | tr -d ' '); h=$((h - CHROME))
    osascript -e "tell application \"System Events\" to tell process \"Code\"
      repeat with win in windows
        try
          if (value of attribute \"AXMinimized\" of win) is false then
            set position of win to {0, 0}
            set size of win to {$w, $h}
          end if
        end try
      end repeat
    end tell" 2>/dev/null
  fi
  sleep 0.25
done
