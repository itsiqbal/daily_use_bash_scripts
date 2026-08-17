#!/bin/bash

# =============================================================================
# backup_projects.sh — Backup ~/Desktop/projects to external drive
# Usage:
#   ./backup_projects.sh           → normal backup
#   ./backup_projects.sh --dry-run → simulate, no files copied
# Or via alias: backupprojects / backupprojects-dry
# =============================================================================

SOURCE="$HOME/Desktop/projects/"
DEST="/Volumes/PC exFAT/projects-backup/"
LOG="$HOME/backup_projects.log"

# --- Dry run support ---
DRY_RUN=""
DRY_LABEL=""
if [[ "$1" == "--dry-run" || "$1" == "-n" ]]; then
  DRY_RUN="--dry-run"
  DRY_LABEL=" (DRY RUN — no files will be copied)"
fi

# --- Check drive is mounted ---
if [ ! -d "$DEST" ]; then
  echo "❌ Drive not found at: $DEST"
  echo "   Plug in your 'PC exFAT' drive and try again."
  exit 1
fi

echo "🚀 Starting backup$DRY_LABEL..."
echo "   From : $SOURCE"
echo "   To   : $DEST"
echo "   Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

rsync -av --delete \
  --progress \
  --stats \
  $DRY_RUN \
  --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='*.log' \
  --exclude='*.tmp' \
  --exclude='*.o' \
  --exclude='*.a' \
  --exclude='node_modules' \
  --exclude='.yarn' \
  --exclude='.cache' \
  --exclude='.vscode' \
  --exclude='.idea' \
  --exclude='dist' \
  --exclude='build' \
  --exclude='.next' \
  --exclude='.nuxt' \
  --exclude='.turbo' \
  --exclude='.swc' \
  --exclude='out' \
  --exclude='.expo' \
  --exclude='coverage' \
  --exclude='.nyc_output' \
  --exclude='ios/Pods' \
  --exclude='ios/build' \
  --exclude='ios/DerivedData' \
  --exclude='*.xcworkspace/xcuserdata' \
  --exclude='android/.gradle' \
  --exclude='android/build' \
  --exclude='android/app/build' \
  --exclude='vendor' \
  --exclude='bin' \
  --exclude='*.exe' \
  --exclude='*.test' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.venv' \
  --exclude='venv' \
  --exclude='*.egg-info' \
  --exclude='.pytest_cache' \
  --exclude='.mypy_cache' \
  --exclude='.ruff_cache' \
  --exclude='htmlcov' \
  --exclude='.coverage' \
  --exclude='temp_source_binaries' \
  "$SOURCE" "$DEST" \
  | tee -a "$LOG"

# --- Summary ---
EXIT_CODE=${PIPESTATUS[0]}
if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  if [ -n "$DRY_RUN" ]; then
    echo "✅ Dry run complete — no files were copied"
  else
    echo "✅ Backup complete — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "   Log saved to: $LOG"
  fi
else
  echo ""
  echo "❌ Backup failed (exit code $EXIT_CODE) — check log: $LOG"
  exit 1
fi