#!/usr/bin/env bash
# Demo 1 latency knob (Option A): throttle Cassandra CPU in place (no pod restart).
# Usage: scripts/degrade.sh [cpu_limit]   default 200m
set -euo pipefail
CTX="${KUBE_CONTEXT:-homelab-rw}"
LIMIT="${1:-200m}"
REQ="100m"   # request must be <= limit
echo "$(date -u +%FT%TZ) DEGRADE: cassandra-0 cpu limit -> $LIMIT (request $REQ)"
kubectl --context "$CTX" -n cassandra-demo patch pod cassandra-0 --subresource resize --type strategic \
  -p "{\"spec\":{\"containers\":[{\"name\":\"cassandra\",\"resources\":{\"requests\":{\"cpu\":\"$REQ\"},\"limits\":{\"cpu\":\"$LIMIT\"}}}]}}"
