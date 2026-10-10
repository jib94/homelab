#!/usr/bin/env bash
# Demo 1 latency knob (Option B): start the unthrottled burst write load against Cassandra.
set -euo pipefail
CTX="${KUBE_CONTEXT:-homelab-rw}"
echo "$(date -u +%FT%TZ) DEGRADE: scaling cassandra-stress-burst to 1"
kubectl --context "$CTX" -n cassandra-demo scale deployment/cassandra-stress-burst --replicas=1
