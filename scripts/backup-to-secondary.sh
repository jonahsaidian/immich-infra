#!/usr/bin/env bash
# PHASE 2 -- not active until the second backup HDD exists and
# udev/99-backup-drive.rules is installed. Backs up the photo library to a
# second external drive using restic, so the same repo can later add an
# offsite Cloudflare R2 copy with just a second `restic backup` target and
# a cron/systemd timer -- restic already encrypts client-side.
set -euo pipefail

# Requires RESTIC_PASSWORD to be exported (e.g. from a root-only
# /etc/immich-backup-env file, not committed to this repo).
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD must be set}"

LIBRARY_PATH="${UPLOAD_LOCATION:-/mnt/photos}"
BACKUP_MOUNT="${BACKUP_DRIVE_PATH:-/mnt/photos-backup}"
RESTIC_REPO="$BACKUP_MOUNT/restic-repo"

if ! mountpoint -q "$BACKUP_MOUNT"; then
  echo "ERROR: backup drive not mounted at $BACKUP_MOUNT. Aborting." >&2
  exit 1
fi

if [ ! -f "$RESTIC_REPO/config" ]; then
  echo "No restic repo found at $RESTIC_REPO -- initializing one."
  restic -r "$RESTIC_REPO" init
fi

restic -r "$RESTIC_REPO" backup "$LIBRARY_PATH"
restic -r "$RESTIC_REPO" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
