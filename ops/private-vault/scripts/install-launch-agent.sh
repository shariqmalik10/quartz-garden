#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /absolute/path/to/obsidian-vault" >&2
  exit 2
fi

VAULT_ROOT="${1:A}"
BACKUP_SCRIPT="$VAULT_ROOT/System/Sync/backup-vault.sh"
LABEL="com.shariqmalik.garden-drop-nightly"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/GardenDrop"
LOCAL_ZONE="$(readlink /etc/localtime | sed 's#^.*/zoneinfo/##')"

if [[ "$LOCAL_ZONE" != "Asia/Riyadh" ]]; then
  echo "Expected macOS timezone Asia/Riyadh, found $LOCAL_ZONE. Change it before installing." >&2
  exit 1
fi
if [[ ! -x "$BACKUP_SCRIPT" ]]; then
  echo "Missing executable backup script: $BACKUP_SCRIPT" >&2
  exit 1
fi

mkdir -p "${PLIST:h}" "$LOG_DIR"
sed \
  -e "s#__VAULT_ROOT__#$VAULT_ROOT#g" \
  -e "s#__BACKUP_SCRIPT__#$BACKUP_SCRIPT#g" \
  -e "s#__LOG_DIR__#$LOG_DIR#g" \
  "${0:A:h}/com.shariqmalik.garden-drop-nightly.plist.template" > "$PLIST"

plutil -lint "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL for 23:00 Asia/Riyadh."

