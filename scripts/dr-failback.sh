#!/bin/bash
# Fail back to the primary SVM with a reverse resync (dr/5-reverse-resync.yaml): only the changes
# made at the DR site are sent back; the original volumes are reused.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
TMR=tridentmirrorrelationships.trident.netapp.io

oc scale deploy --all -n $DR_NS --replicas=0
oc wait pod --all -n $DR_NS --for=delete --timeout=3m

dr_volume() { oc get $TMR "$1" -n $DR_NS -o jsonpath='{.status.conditions[0].localVolumeHandle}'; }
render dr/5-reverse-resync.yaml \
  DR_VOLUME_POSTGRES_DATA="$(dr_volume postgres-data)" DR_VOLUME_UPLOADS="$(dr_volume uploads)" | oc apply -f -
for T in postgres-data uploads; do wait_for $TMR/$T $SRC_NS '{.status.conditions[0].state}' reestablished 60; done

for T in postgres-data uploads; do oc patch $TMR $T -n $SRC_NS --type merge -p '{"spec":{"state":"promoted"}}'; done
for T in postgres-data uploads; do wait_for $TMR/$T $SRC_NS '{.status.conditions[0].state}' promoted 60; done

oc scale deploy/postgres -n $SRC_NS --replicas=1
oc scale deploy/frontend -n $SRC_NS --replicas=2
oc rollout status deploy/postgres -n $SRC_NS --timeout=5m
oc rollout status deploy/frontend -n $SRC_NS --timeout=5m
echo "App is back on the primary SVM: $(app_url $SRC_NS)"
