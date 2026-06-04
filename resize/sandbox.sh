#!/bin/bash
IN=/Users/Shared/sandbox_screen_size.txt
CHROME=28

# Programs to control — pass as arguments, e.g.:  ./watcher.sh Code "Docker Desktop"
# Defaults to VS Code if none given.
PROCS=("$@")
[ ${#PROCS[@]} -eq 0 ] && PROCS=("Code")

last=""
while true; do
  IFS= read -r size < "$IN" 2>/dev/null
  if [ -n "$size" ] && [ "$size" != "$last" ]; then
    w=${size%%,*}; w=${w// /}
    h=${size##*,}; h=${h// /}
    if [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]]; then
      last="$size"
      h=$((h - CHROME))
      for proc in "${PROCS[@]}"; do
        osascript -e "tell application \"System Events\" to tell process \"$proc\"
          repeat with win in windows
            try
              if (value of attribute \"AXMinimized\" of win) is false then
                set position of win to {0, 0}
                set size of win to {$w, $h}
                set position of win to {0, 0}
              end if
            end try
          end repeat
        end tell" 2>/dev/null
      done
    fi
  fi
  sleep 0.05
done
