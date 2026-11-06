#!/bin/bash
# Back up the app (backup/3-backup.yaml, with a timestamped name) and remember where it was
# stored in .last-backup - the Backup object is gone once the namespace is deleted.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
NAME=webapp-backup-$(date +%Y%m%d-%H%M%S)

oc apply -f backup/1-application.yaml
sed "s/name: webapp-backup-1/name: $NAME/" backup/3-backup.yaml | oc apply -f -
wait_for backups.protect.trident.netapp.io/$NAME $SRC_NS '{.status.state}' Completed 90
oc get backups.protect.trident.netapp.io $NAME -n $SRC_NS -o jsonpath='{.status.appArchivePath}' > .last-backup
echo "Archive path (saved to .last-backup): $(cat .last-backup)"
