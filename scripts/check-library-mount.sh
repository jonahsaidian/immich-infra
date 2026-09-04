#!/usr/bin/env bash
# Refuses to proceed unless the real external photo-library drive is
# mounted. Without this, an unmounted drive would leave an empty directory
# at the mount point, and Immich would happily start writing/reading an
# "empty library" there instead of failing loudly.
set -euo pipefail

MOUNT_POINT="${IMMICH_LIBRARY_PATH:-/mnt/photos}"
MARKER="$MOUNT_POINT/.immich-library-marker"

if ! mountpoint -q "$MOUNT_POINT"; then
  echo "ERROR: $MOUNT_POINT is not a mounted filesystem. Refusing to start Immich." >&2
  exit 1
fi

if [ ! -f "$MARKER" ]; then
  echo "ERROR: $MARKER not found on $MOUNT_POINT." >&2
  echo "This does not look like the real library drive. Refusing to start Immich." >&2
  exit 1
fi

echo "Library drive verified at $MOUNT_POINT."
