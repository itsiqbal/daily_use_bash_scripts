#!/bin/bash

# =============================================================================
# backup_projects_rclone.sh — Backup ~/Desktop/projects to Google Drive
# Usage:
#   ./backup_projects_rclone.sh           → normal backup
#   ./backup_projects_rclone.sh --dry-run → simulate, no files copied
# Or via alias: rkp / rkp-dry
# =============================================================================

SOURCE="$HOME/Desktop/projects/"
DEST="gdrive:Backups/projects-backup"
LOG="$HOME/backup_projects_rclone.log"

# --- Dry run support ---
DRY_RUN=""
DRY_LABEL=""
if [[ "$1" == "--dry-run" || "$1" == "-n" ]]; then
  DRY_RUN="--dry-run"
  DRY_LABEL=" (DRY RUN — no files will be copied)"
fi

# --- Check rclone is installed ---
if ! command -v rclone &> /dev/null; then
  echo "❌ rclone not found. Install it with: brew install rclone"
  exit 1
fi

# --- Check gdrive remote exists ---
if ! rclone listremotes | grep -q "^gdrive:"; then
  echo "❌ rclone remote 'gdrive' not configured."
  echo "   Run: rclone config"
  exit 1
fi

echo "☁️  Starting cloud backup$DRY_LABEL..."
echo "   From : $SOURCE"
echo "   To   : $DEST"
echo "   Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

rclone copy "$SOURCE" "$DEST" \
  --progress \
  --stats-one-line \
  --transfers=32 \
  --checkers=16 \
  --fast-list \
  --tpslimit 10 \
  --drive-chunk-size=64M \
  --ignore-checksum \
  --log-file="$LOG" \
  --log-level INFO \
  $DRY_RUN \
  --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='*.log' \
  --exclude='*.tmp' \
  --exclude='*.o' \
  --exclude='*.a' \
  --exclude='node_modules/**' \
  --exclude='.yarn/**' \
  --exclude='.cache/**' \
  --exclude='.vscode/**' \
  --exclude='.idea/**' \
  --exclude='dist/**' \
  --exclude='build/**' \
  --exclude='.next/**' \
  --exclude='.nuxt/**' \
  --exclude='.turbo/**' \
  --exclude='.swc/**' \
  --exclude='out/**' \
  --exclude='.expo/**' \
  --exclude='coverage/**' \
  --exclude='.nyc_output/**' \
  --exclude='ios/Pods/**' \
  --exclude='ios/build/**' \
  --exclude='ios/DerivedData/**' \
  --exclude='android/.gradle/**' \
  --exclude='android/build/**' \
  --exclude='android/app/build/**' \
  --exclude='vendor/**' \
  --exclude='bin/**' \
  --exclude='*.exe' \
  --exclude='*.test' \
  --exclude='__pycache__/**' \
  --exclude='*.pyc' \
  --exclude='.venv/**' \
  --exclude='venv/**' \
  --exclude='*.egg-info/**' \
  --exclude='.pytest_cache/**' \
  --exclude='.mypy_cache/**' \
  --exclude='.ruff_cache/**' \
  --exclude='htmlcov/**' \
  --exclude='.coverage' \
  --exclude='temp_source_binaries/**'

# --- Summary ---
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  if [ -n "$DRY_RUN" ]; then
    echo "✅ Dry run complete — no files were copied"
  else
    echo "✅ Cloud backup complete — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "   Log saved to: $LOG"
  fi
else
  echo ""
  echo "❌ Cloud backup failed (exit code $EXIT_CODE) — check log: $LOG"
  exit 1
fi