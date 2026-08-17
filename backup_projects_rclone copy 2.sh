#!/bin/bash

# =============================================================================
# fast_projects_backup.sh
#
# Fast compressed backup of ~/Desktop/projects to Google Drive
# Uses:
#   - tar
#   - zstd compression
#   - rclone
#
# Result:
#   Single compressed archive uploaded to Google Drive
#
# Usage:
#   ./fast_projects_backup.sh
#   ./fast_projects_backup.sh --dry-run
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------

SOURCE="$HOME/Desktop/projects"
TMP_DIR="$HOME/.backup-temp"
ARCHIVE_NAME="projects_$(date +%Y%m%d_%H%M%S).tar.zst"

LOCAL_ARCHIVE="$TMP_DIR/$ARCHIVE_NAME"

DEST="gdrive:Backups/projects-backup"

LOG="$HOME/fast_projects_backup.log"

# -----------------------------------------------------------------------------
# DRY RUN
# -----------------------------------------------------------------------------

DRY_RUN=""
DRY_LABEL=""

if [[ "$1" == "--dry-run" || "$1" == "-n" ]]; then
  DRY_RUN="--dry-run"
  DRY_LABEL=" (DRY RUN)"
fi

# -----------------------------------------------------------------------------
# DEPENDENCY CHECKS
# -----------------------------------------------------------------------------

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "❌ Missing dependency: $1"
    exit 1
  fi
}

check_command rclone
check_command tar
check_command zstd

# -----------------------------------------------------------------------------
# CHECK RCLONE REMOTE
# -----------------------------------------------------------------------------

if ! rclone listremotes | grep -q "^gdrive:"; then
  echo "❌ rclone remote 'gdrive' not configured"
  echo "Run: rclone config"
  exit 1
fi

# -----------------------------------------------------------------------------
# CREATE TEMP DIRECTORY
# -----------------------------------------------------------------------------

mkdir -p "$TMP_DIR"

# -----------------------------------------------------------------------------
# START
# -----------------------------------------------------------------------------

echo "🚀 Starting FAST compressed backup$DRY_LABEL"
echo ""
echo "📂 Source      : $SOURCE"
echo "☁️  Destination : $DEST"
echo "📦 Archive     : $ARCHIVE_NAME"
echo "🕒 Time        : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# -----------------------------------------------------------------------------
# CREATE COMPRESSED ARCHIVE
# -----------------------------------------------------------------------------

echo "📦 Compressing projects..."

tar \
  - --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='*.log' \
  --exclude='.git/**' \
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
  -I 'zstd -10 -T0' \
  -cf "$LOCAL_ARCHIVE" \
  -C "$HOME/Desktop" \
  projects

echo ""
echo "✅ Compression complete"
echo ""

# -----------------------------------------------------------------------------
# SHOW ARCHIVE SIZE
# -----------------------------------------------------------------------------

ARCHIVE_SIZE=$(du -sh "$LOCAL_ARCHIVE" | awk '{print $1}')

echo "📏 Archive size: $ARCHIVE_SIZE"
echo ""

# -----------------------------------------------------------------------------
# UPLOAD
# -----------------------------------------------------------------------------

echo "☁️  Uploading to Google Drive..."

rclone copy "$LOCAL_ARCHIVE" "$DEST" \
  --progress \
  --stats-one-line \
  --transfers=8 \
  --checkers=16 \
  --fast-list \
  --drive-chunk-size=64M \
  --ignore-checksum \
  --buffer-size=64M \
  --use-mmap \
  --log-file="$LOG" \
  --log-level INFO \
  $DRY_RUN

# -----------------------------------------------------------------------------
# RESULT
# -----------------------------------------------------------------------------

EXIT_CODE=$?

echo ""

if [ $EXIT_CODE -eq 0 ]; then

  if [ -n "$DRY_RUN" ]; then
    echo "✅ Dry run complete"
  else
    echo "✅ Upload complete"

    echo ""
    echo "🧹 Cleaning temporary archive..."

    rm -f "$LOCAL_ARCHIVE"

    echo "✅ Cleanup complete"
  fi

  echo ""
  echo "🕒 Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "📝 Log file: $LOG"

else
  echo "❌ Backup failed"
  echo "Check log: $LOG"
  exit 1
fi
