#!/bin/bash
# Trident with an NFS backend on the primary SVM: setup/1-5.
#   ONTAP_USERNAME=<user> ONTAP_PASSWORD=<pw> MANAGEMENT_LIF=<ip> PRIMARY_SVM=<svm> \
#   PRIMARY_DATA_LIF=<ip> scripts/install-trident.sh
# Skips the operator install if Trident is already installed.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"
: "${ONTAP_USERNAME:?} ${ONTAP_PASSWORD:?} ${MANAGEMENT_LIF:?} ${PRIMARY_SVM:?} ${PRIMARY_DATA_LIF:?}"

if ! oc get crd tridentorchestrators.trident.netapp.io >/dev/null 2>&1; then
  oc apply -f setup/1-trident-operator.yaml
  echo "Waiting for the Trident operator..."
  until oc get crd tridentorchestrators.trident.netapp.io >/dev/null 2>&1; do sleep 10; done
fi
oc get tridentorchestrator trident >/dev/null 2>&1 || oc apply -f setup/2-trident-orchestrator.yaml
until [ "$(oc get tridentorchestrator trident -o jsonpath='{.status.status}' 2>/dev/null)" = Installed ]; do sleep 10; done

render setup/3-ontap-credentials.yaml ONTAP_USERNAME="$ONTAP_USERNAME" ONTAP_PASSWORD="$ONTAP_PASSWORD" | oc apply -f -
render setup/4-trident-backend-primary.yaml MANAGEMENT_LIF="$MANAGEMENT_LIF" PRIMARY_SVM="$PRIMARY_SVM" \
  PRIMARY_DATA_LIF="$PRIMARY_DATA_LIF" | oc apply -f -
oc wait tbc/backend-ontap-nas-primary -n trident --for=jsonpath='{.status.phase}'=Bound --timeout=3m
oc apply -f setup/5-storageclass-primary.yaml
