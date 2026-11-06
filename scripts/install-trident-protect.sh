#!/bin/bash
# Trident Protect and its backup target: setup/trident-protect-values.yaml and setup/6-8.
#   CLUSTER_NAME=<name> scripts/install-trident-protect.sh   (overrides clusterName in the values)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"

helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart >/dev/null 2>&1 || true
helm repo update netapp-trident-protect >/dev/null
helm upgrade --install trident-protect netapp-trident-protect/trident-protect \
  --version "${TP_CHART_VERSION:-100.2606.0}" -n $TP_NS --create-namespace \
  -f setup/trident-protect-values.yaml ${CLUSTER_NAME:+--set clusterName=$CLUSTER_NAME} \
  --force-conflicts --wait --timeout 10m

oc apply -f setup/6-volumesnapshotclass.yaml
oc apply -f setup/7-backup-bucket.yaml
oc wait obc/trident-protect-backups -n $TP_NS --for=jsonpath='{.status.phase}'=Bound --timeout=5m

render setup/8-appvault.yaml BUCKET_NAME="$(bucket_name trident-protect-backups)" SERVICE_CA="$(service_ca)" | oc apply -f -
oc wait appvault/odf-noobaa -n $TP_NS --for=jsonpath='{.status.state}'=Available --timeout=2m
