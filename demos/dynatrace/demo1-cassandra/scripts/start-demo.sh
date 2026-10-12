#!/usr/bin/env bash
# Demo 1 setup, in phases. Run the phases on the day (times are relative to demo start, T):
#   T-60  scripts/start-demo.sh baseline      steady 300 ops/s write load (P95 settles near 100-150 us)
#   T-35  scripts/start-demo.sh spike 40      unthrottled burst for 40 min (P95 -> 215-310 us)
#   any   scripts/start-demo.sh status        what is running
#   after scripts/start-demo.sh stop          stop the burst (the baseline job runs 8 h by itself)
# Writes only to the cassandra-demo namespace. The only delete is the finished baseline Job (asks first).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="${KUBE_CONTEXT:-homelab-rw}"
NS=cassandra-demo
K=(kubectl --context "$CTX" -n "$NS")
MANIFESTS="$HERE/../k8s"

phase="${1:-}"; arg="${2:-}"

case "$phase" in
  baseline)
    echo "kube context: $(kubectl config current-context) (using $CTX)"
    state="$("${K[@]}" get job cassandra-stress -o jsonpath='{.status.active}{"/"}{.status.succeeded}{"/"}{.status.failed}' 2>/dev/null || echo missing)"
    if [[ "$state" == "missing" ]]; then
      echo "no baseline job yet; creating it"
    elif [[ "$state" == 1/* ]]; then
      echo "baseline job is already running; nothing to do"; exit 0
    else
      echo "baseline job exists but is not running (active/succeeded/failed = $state)."
      read -r -p "Delete job/cassandra-stress (label part-of=demo1-cassandra) and start a new one? [y/N] " a
      [[ "$a" == "y" ]] || { echo "aborted"; exit 1; }
      "${K[@]}" delete job cassandra-stress
    fi
    "${K[@]}" apply -f "$MANIFESTS/20-stress-job.yaml"
    echo "waiting for the baseline pod (it waits for Cassandra, then writes 300 ops/s)..."
    until "${K[@]}" get pod -l job-name=cassandra-stress -o name 2>/dev/null | grep -q pod; do sleep 2; done
    "${K[@]}" wait --for=condition=Ready pod -l job-name=cassandra-stress --timeout=300s
    echo "$(date -u +%FT%TZ) baseline running"
    ;;
  spike)
    mins="${arg:-40}"
    echo "kube context: $(kubectl config current-context) (using $CTX)"
    echo "Burst for ${mins} min. Rough disk cost: ~3 GB per 8 min of burst (about $((mins * 3 / 8)) GB). Check node disk first."
    "${K[@]}" set env deployment/cassandra-stress-burst "BURST_DURATION=${mins}m"
    "${K[@]}" scale deployment/cassandra-stress-burst --replicas=0
    "${K[@]}" wait --for=delete pod -l app.kubernetes.io/name=cassandra-stress-burst --timeout=90s || true
    "${K[@]}" scale deployment/cassandra-stress-burst --replicas=1
    echo "$(date -u +%FT%TZ) spike started. Expect: P95 crosses 200 in ~1-5 min, Davis problem + workflow run ~6-8 min after that."
    ;;
  stop)
    "$HERE/reset.sh"
    ;;
  status)
    "${K[@]}" get pods,deploy,job 2>&1
    "$HERE/latency.sh" 10 2>&1 || true
    ;;
  *)
    sed -n '2,8p' "$0"; exit 2
    ;;
esac
