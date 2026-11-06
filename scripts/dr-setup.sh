#!/bin/bash
# One-time DR setup: dr/setup/1-4 (DR backend + storage class, DR bucket + AppVault).
#   MANAGEMENT_LIF=<ip> DR_SVM=<svm> DR_DATA_LIF=<ip> scripts/dr-setup.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
: "${MANAGEMENT_LIF:?} ${DR_SVM:?} ${DR_DATA_LIF:?}"

if [ "$(oc get sc ontap-nas-sc -o jsonpath='{.parameters.selector}')" != "site=primary" ]; then
  echo "ontap-nas-sc must select the primary backend first (see setup/5-storageclass-primary.yaml)"; exit 1
fi

render dr/setup/1-trident-backend-dr.yaml MANAGEMENT_LIF="$MANAGEMENT_LIF" DR_SVM="$DR_SVM" \
  DR_DATA_LIF="$DR_DATA_LIF" | oc apply -f -
oc wait tbc/backend-ontap-nas-dr -n trident --for=jsonpath='{.status.phase}'=Bound --timeout=3m
oc apply -f dr/setup/2-storageclass-dr.yaml

oc apply -f dr/setup/3-dr-bucket.yaml
oc wait obc/trident-protect-backups-dr -n $TP_NS --for=jsonpath='{.status.phase}'=Bound --timeout=5m
render dr/setup/4-appvault-dr.yaml BUCKET_NAME="$(bucket_name trident-protect-backups-dr)" SERVICE_CA="$(service_ca)" | oc apply -f -
oc wait appvault/odf-noobaa-dr -n $TP_NS --for=jsonpath='{.status.state}'=Available --timeout=2m
