#!/bin/bash
# =============================================================================
# MinIO Backup Script
# =============================================================================
# Usage:
#   Manual:    bash scripts/backup.sh
#   Cron job:  0 2 * * * /path/to/minio-server/scripts/backup.sh
#
# What it does:
#   - Compresses ./data into a timestamped .tar.gz in ./backups/
#   - Keeps only the last N backups (default: 7)
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
BACKUP_DIR="$PROJECT_DIR/backups"
KEEP_LAST=7   # Number of backups to retain

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/minio-backup-$TIMESTAMP.tar.gz"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
if [ ! -d "$DATA_DIR" ]; then
  echo "[ERR] Data directory not found: $DATA_DIR"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# Create backup
# ---------------------------------------------------------------------------
echo "[INFO] Starting backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C "$PROJECT_DIR" data
echo "[INFO] Backup complete: $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"

# ---------------------------------------------------------------------------
# Rotate old backups — keep only the last N
# ---------------------------------------------------------------------------
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/minio-backup-*.tar.gz 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt "$KEEP_LAST" ]; then
  DELETE_COUNT=$(( BACKUP_COUNT - KEEP_LAST ))
  echo "[INFO] Rotating backups: deleting $DELETE_COUNT old backup(s)..."
  ls -1t "$BACKUP_DIR"/minio-backup-*.tar.gz | tail -n "$DELETE_COUNT" | xargs rm -f
  echo "[INFO] Kept latest $KEEP_LAST backups."
fi

echo "[INFO] Backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/minio-backup-*.tar.gz 2>/dev/null || echo "  (none)"
