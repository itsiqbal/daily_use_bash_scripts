#!/bin/bash

#############################################
# Defined App Killer (macOS - No sudo)
# Kills ONLY apps explicitly listed by user
#############################################

LOG_FILE="$HOME/.mac_defined_killer.log"
DRY_RUN=false
INTERACTIVE=true

#############################################
# Apps you want to kill (EDIT THIS LIST)
#############################################
TARGET_APPS=(
  "Google Chrome"
  "Slack"
  "Microsoft Teams"
  "Spotify"
  "Postman"
  "Discord"
  "Bruno",
  "Electron",
  "Preview",
  "Sourcetree",
  "datagrip",
  "idea"
  "Terminal"
)

#############################################
# Args
#############################################
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      ;;
    --auto)
      INTERACTIVE=false
      ;;
  esac
done

echo "🚀 Defined App Killer Started" | tee -a "$LOG_FILE"

#############################################
# Function: kill app safely
#############################################
kill_app() {
  local app="$1"

  echo ""
  echo "🔍 Searching processes for: $app" | tee -a "$LOG_FILE"

  # Find PIDs matching app name
  pids=$(ps -u "$USER" -o pid,command | grep -i "$app" | awk '{print $1}')

  if [[ -z "$pids" ]]; then
    echo "⚠️ No running process found for $app" | tee -a "$LOG_FILE"
    return
  fi

  for pid in $pids; do

    echo "🎯 Found PID: $pid for $app" | tee -a "$LOG_FILE"

    if $INTERACTIVE; then
      read -p "Kill $app (PID $pid)? (y/n): " confirm
      if [[ "$confirm" != "y" ]]; then
        echo "⏭ Skipped $pid" | tee -a "$LOG_FILE"
        continue
      fi
    fi

    if $DRY_RUN; then
      echo "🧪 DRY RUN: would kill PID $pid ($app)" | tee -a "$LOG_FILE"
    else
      echo "❌ Killing PID $pid ($app)" | tee -a "$LOG_FILE"

      # Kill process group (important for full app shutdown)
      PGID=$(ps -o pgid= -p "$pid" | tr -d ' ')
      if [[ -n "$PGID" ]]; then
        kill -TERM -"$PGID" 2>/dev/null
      else
        kill -TERM "$pid" 2>/dev/null
      fi
    fi

  done
}

#############################################
# Main loop
#############################################
for app in "${TARGET_APPS[@]}"; do
  kill_app "$app"
done

echo ""
echo "✅ Done. All selected apps processed." | tee -a "$LOG_FILE"