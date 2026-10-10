#!/usr/bin/env bash
# Restore Cassandra CPU to the StatefulSet values (request 1, limit 2) in place.
set -euo pipefail
CTX="${KUBE_CONTEXT:-homelab-rw}"
echo "$(date -u +%FT%TZ) RESET: cassandra-0 cpu -> request 1 / limit 2"
kubectl --context "$CTX" -n cassandra-demo patch pod cassandra-0 --subresource resize --type strategic \
  -p '{"spec":{"containers":[{"name":"cassandra","resources":{"requests":{"cpu":"1"},"limits":{"cpu":"2"}}}]}}'
