#!/bin/bash
# Fail over to the DR SVM: stop the source schedule (keeps the common snapshot for failback),
# promote the mirror, replace the Route (dr/4-route-dr.yaml).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
AMR=appmirrorrelationships.protect.trident.netapp.io/webapp-demo-napp-mirror

oc patch schedules.protect.trident.netapp.io webapp-replication-schedule -n $SRC_NS \
  --type merge -p '{"spec":{"enabled":false}}' || echo "(source schedule not reachable - continuing)"
echo "Common snapshot for failback: $(oc get $AMR -n $DR_NS -o jsonpath='{.status.lastTransferredSnapshot.name}')"

oc patch $AMR -n $DR_NS --type merge -p '{"spec":{"desiredState":"Promoted"}}'
wait_for $AMR $DR_NS '{.status.state}' Promoted 60

oc delete route frontend -n $DR_NS --ignore-not-found
oc apply -f dr/4-route-dr.yaml
oc rollout status deploy/postgres -n $DR_NS --timeout=5m
oc rollout status deploy/frontend -n $DR_NS --timeout=5m
echo "DR app: $(app_url $DR_NS)"
