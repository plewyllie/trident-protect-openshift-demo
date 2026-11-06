#!/bin/bash
# Restore from a backup: backup/4a-restore-inplace.yaml or backup/4b-restore-full.yaml
#   scripts/restore.sh inplace|full [archive-path]   (default: .last-backup from backup.sh)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
ARCHIVE=${2:-$(cat .last-backup 2>/dev/null || true)}
[ -n "$ARCHIVE" ] || { echo "No archive path: run scripts/backup.sh first or pass it"; exit 1; }

case "${1:-}" in
  inplace) FILE=backup/4a-restore-inplace.yaml; KIND=backupinplacerestores.protect.trident.netapp.io/webapp-restore-inplace
           oc get ns $SRC_NS >/dev/null || { echo "$SRC_NS does not exist - use 'full'"; exit 1; } ;;
  full)    FILE=backup/4b-restore-full.yaml;    KIND=backuprestores.protect.trident.netapp.io/webapp-restore-full
           ! oc get ns $SRC_NS >/dev/null 2>&1 || { echo "$SRC_NS still exists - use 'inplace' or delete it first"; exit 1; } ;;
  *) echo "usage: $0 inplace|full [archive-path]"; exit 1 ;;
esac

oc delete "$KIND" -n $SRC_NS --ignore-not-found >/dev/null 2>&1 || true
render $FILE ARCHIVE_PATH="$ARCHIVE" | oc apply -f -
wait_for "$KIND" $SRC_NS '{.status.state}' Completed 120
oc rollout status deploy/postgres -n $SRC_NS --timeout=5m
oc rollout status deploy/frontend -n $SRC_NS --timeout=5m
echo "App: $(app_url $SRC_NS)"
