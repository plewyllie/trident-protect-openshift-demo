#!/bin/bash
# Start replication: dr/1-dr-namespace.yaml, dr/2-source-snapshot-schedule.yaml,
# dr/3-appmirrorrelationship.yaml
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"

oc apply -f dr/1-dr-namespace.yaml
oc apply -f dr/2-source-snapshot-schedule.yaml
UID_=$(oc get applications.protect.trident.netapp.io webapp-demo-napp -n $SRC_NS -o jsonpath='{.metadata.uid}')
render dr/3-appmirrorrelationship.yaml SOURCE_APP_UID="$UID_" | oc apply -f -
wait_for appmirrorrelationships.protect.trident.netapp.io/webapp-demo-napp-mirror $DR_NS '{.status.state}' Established 60
echo "On ONTAP: snapmirror show -destination-vserver <dr-svm>"
