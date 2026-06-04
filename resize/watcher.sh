#!/bin/bash
IN=/Users/Shared/sandbox_screen_size.txt
CHROME=28
PERIOD=10   # forced full pass every PERIOD iterations (10 * 0.05s ≈ 0.5s)

# Programs to control — pass as arguments, e.g.:  ./watcher.sh Code "Docker Desktop"
PROCS=("$@")
[ ${#PROCS[@]} -eq 0 ] && PROCS=("Code")

last=""
count=0
while true; do
  IFS= read -r size < "$IN" 2>/dev/null
  count=$((count + 1))

  changed=0
  [ -n "$size" ] && [ "$size" != "$last" ] && changed=1

  if [ "$changed" -eq 1 ] || [ "$count" -ge "$PERIOD" ]; then
    count=0                      # any pass resets the timer
    if [ -n "$size" ]; then
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
  fi

  sleep 0.05
done
