#!/usr/bin/env bash
# Read-only check of everything Demo 1 needs. Run it at T-60 (before the load) and again at T-5.
# Prints PASS / WARN / FAIL per check; exits 1 if anything FAILs. Changes nothing.
set -uo pipefail
CTX="${KUBE_CONTEXT:-homelab-ro}"
NS=cassandra-demo
WF=44d53008-24e2-4d4d-8366-ea589e9cac8c
fails=0
pass() { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails+1)); }

echo "kube context: $CTX   dtctl: $(dtctl config current-context 2>/dev/null || echo '?')"

# --- cluster ---
ready="$(kubectl --context "$CTX" -n $NS get pod cassandra-0 -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)"
[[ "$ready" == "true" ]] && pass "cassandra-0 is Ready" || fail "cassandra-0 is not Ready"
act="$(kubectl --context "$CTX" -n $NS get job cassandra-stress -o jsonpath='{.status.active}' 2>/dev/null)"
[[ "$act" == "1" ]] && pass "baseline load job is running" || warn "baseline load job is not running (scripts/start-demo.sh baseline)"
reps="$(kubectl --context "$CTX" -n $NS get deploy cassandra-stress-burst -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
last="$(kubectl --context "$CTX" -n $NS logs deploy/cassandra-stress-burst --tail=1 2>/dev/null | cut -c1-40)"
if [[ "$last" == *"burst finished"* ]]; then warn "burst finished (idling); start a new one with: scripts/start-demo.sh spike"
elif [[ "${reps:-0}" == "1" ]]; then pass "burst load is running"
else warn "burst load is off"; fi

# --- metric ---
pts="$(dtctl query 'timeseries p95 = avg(cassandra.clientRequest.write.latency.95thPercentile), by:{k8s.pod.name}, from: now()-10m, filter:{k8s.namespace.name == "cassandra-demo"} | fields p95' -o json --series=full 2>/dev/null | grep -o '"p95":\[[^]]*\]')"
if [[ -z "$pts" ]]; then fail "no write-latency metric in the last 10 min (extension not reporting?)"
else pass "metric flowing, last 10 min: ${pts#\"p95\":}"; fi

# --- Dynatrace objects ---
det="$(dtctl get anomaly-detectors -o json 2>/dev/null)"
grep -q 'DEMO1 Cassandra write latency P95 high' <<<"$det" && pass "detector exists" || fail "detector missing"
grep -q '"key":"dt.davis.is_merging_allowed","value":"true"' <<<"$det" && pass "detector merge flag is true" || fail "detector merge flag not true"
wf="$(dtctl get workflows -o json 2>/dev/null | grep -o "\"id\":\"$WF\"[^}]*isDeployed\":[a-z]*" | head -1)"
[[ "$wf" == *'isDeployed":true'* ]] && pass "workflow $WF deployed" || fail "workflow $WF missing or not deployed"
grep -q 'cassandra-demo' <<<"$det" && true

# --- problems and runs (informational) ---
echo "--- latest Cassandra problems (24 h) ---"
dtctl query 'fetch dt.davis.problems, from:now()-24h | filter contains(event.name, "Cassandra write latency") | sort event.start desc | limit 5 | fields display_id, event.status, event.start, event.end' 2>/dev/null | tail -n +1 | head -12
echo "--- latest workflow runs ---"
dtctl describe workflow $WF 2>/dev/null | sed -n '/Recent Executions/,$p' | head -6

# --- GitHub ---
if command -v gh >/dev/null; then
  open="$(gh pr list --repo jib94/homelab --state open --search 'Cassandra write latency in:title' --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null)"
  if [[ -z "$open" ]]; then pass "no stale demo PRs open"; else warn "open demo PRs (close old ones before the demo unless you want them):"; echo "$open"; fi
fi

echo
[[ $fails -eq 0 ]] && { echo "preflight OK (warnings above need a look)"; exit 0; } || { echo "preflight: $fails FAIL"; exit 1; }
