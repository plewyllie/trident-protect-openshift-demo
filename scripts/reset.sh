#!/bin/bash
# Start the backup/restore demo over: delete the app namespace (and its ONTAP volumes)
# and deploy a fresh, empty copy. Backups with reclaimPolicy Retain stay in the bucket.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"

if oc get ns $SRC_NS >/dev/null 2>&1; then
  # Trident Protect objects first, so their finalizers don't hold up the namespace
  oc delete backupinplacerestores.protect.trident.netapp.io,backuprestores.protect.trident.netapp.io,backups.protect.trident.netapp.io,snapshots.protect.trident.netapp.io,schedules.protect.trident.netapp.io,applications.protect.trident.netapp.io,tridentmirrorrelationships.trident.netapp.io \
    --all -n $SRC_NS --ignore-not-found --wait=true --timeout=5m
  oc delete namespace $SRC_NS --wait=true --timeout=5m
fi
oc apply -f app/webapp.yaml
oc apply -f backup/1-application.yaml
oc rollout status deploy/postgres -n $SRC_NS --timeout=5m
oc rollout status deploy/frontend -n $SRC_NS --timeout=5m
echo "App: $(app_url $SRC_NS)"
