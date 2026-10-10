#!/usr/bin/env bash
# Removes ONLY resources labelled app.kubernetes.io/part-of=demo1-cassandra.
# Run by the user (Claude has no delete permission). Usage: scripts/teardown.sh [--yes]
set -euo pipefail

CTX="${KUBE_CONTEXT:-homelab-rw}"
LABEL="app.kubernetes.io/part-of=demo1-cassandra"
NAMESPACES=(cassandra-demo demo-stubs)
K="kubectl --context $CTX"

echo "Context: $CTX"
echo "Will delete everything labelled $LABEL in: ${NAMESPACES[*]}"
echo "Namespaces are deleted only if they carry the same label."
$K get all,pvc,configmap,ingress,job,statefulset -n cassandra-demo -l "$LABEL" 2>/dev/null || true
$K get all,configmap,ingress -n demo-stubs -l "$LABEL" 2>/dev/null || true

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Proceed? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

for ns in "${NAMESPACES[@]}"; do
  $K get ns "$ns" >/dev/null 2>&1 || { echo "skip $ns (not found)"; continue; }
  # workloads and PVCs first, so StatefulSet PVCs go too
  $K delete job,statefulset,deployment,service,ingress,configmap,pvc -n "$ns" -l "$LABEL" --ignore-not-found
done

# Namespaces last, and only if labelled as ours.
for ns in "${NAMESPACES[@]}"; do
  if $K get ns -l "$LABEL" -o name 2>/dev/null | grep -qx "namespace/$ns"; then
    $K delete ns "$ns" --ignore-not-found
  else
    echo "Namespace $ns is not labelled $LABEL, leaving it."
  fi
done

echo "Done. Dynatrace objects (workflows, anomaly detector) are not removed here; delete them by name in the tenant."
