#!/bin/bash
IN=/Users/Shared/ss_size.txt
CHROME=28
last=""
while true; do
  IFS= read -r size < "$IN" 2>/dev/null
  if [ -n "$size" ] && [ "$size" != "$last" ]; then
    w=${size%%,*}; w=${w// /}
    h=${size##*,}; h=${h// /}
    if [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]]; then
      last="$size"
      h=$((h - CHROME))
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
  fi
  sleep 0.05
done
