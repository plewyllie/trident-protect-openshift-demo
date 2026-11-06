#!/bin/bash
# After a failback: remove the reverse relationships and the old DR copy, then mirror
# primary -> DR again (full copy into new DR volumes).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO"

oc delete tridentmirrorrelationships.trident.netapp.io --all -n $SRC_NS --ignore-not-found
oc delete namespace $DR_NS --ignore-not-found --wait=true --timeout=5m
"$REPO/scripts/dr-start-mirror.sh"
