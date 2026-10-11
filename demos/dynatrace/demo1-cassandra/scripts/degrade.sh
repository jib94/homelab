#!/usr/bin/env bash
# Demo 1 latency knob (Option B): start the unthrottled burst write load against Cassandra.
set -euo pipefail
CTX="${KUBE_CONTEXT:-homelab-rw}"
echo "$(date -u +%FT%TZ) DEGRADE: scaling cassandra-stress-burst to 1"
# A finished burst pod idles at 1 replica, so scale 0 -> 1 to guarantee a fresh run.
kubectl --context "$CTX" -n cassandra-demo scale deployment/cassandra-stress-burst --replicas=0
kubectl --context "$CTX" -n cassandra-demo wait --for=delete pod -l app.kubernetes.io/name=cassandra-stress-burst --timeout=90s || true
kubectl --context "$CTX" -n cassandra-demo scale deployment/cassandra-stress-burst --replicas=1
