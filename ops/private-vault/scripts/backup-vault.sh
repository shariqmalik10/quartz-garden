#!/bin/zsh
set -euo pipefail

VAULT_ROOT="${GARDEN_VAULT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOCK_DIR="${TMPDIR:-/tmp}/com.shariqmalik.garden-drop-nightly.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "A vault backup is already running."
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

cd "$VAULT_ROOT"
if [[ ! -d .git ]]; then
  echo "The vault is not a Git repository: $VAULT_ROOT" >&2
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
  echo "Refusing to back up unexpected branch: $BRANCH" >&2
  exit 1
fi

git add --all
if ! git diff --cached --quiet; then
  git commit -m "vault: nightly backup $(TZ=Asia/Riyadh date '+%Y-%m-%d %H:%M %Z')"
fi

git pull --rebase origin main
git push origin main

