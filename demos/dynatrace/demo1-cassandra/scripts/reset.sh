#!/usr/bin/env bash
# Stop the burst load; latency returns to baseline.
set -euo pipefail
CTX="${KUBE_CONTEXT:-homelab-rw}"
echo "$(date -u +%FT%TZ) RESET: scaling cassandra-stress-burst to 0"
kubectl --context "$CTX" -n cassandra-demo scale deployment/cassandra-stress-burst --replicas=0
