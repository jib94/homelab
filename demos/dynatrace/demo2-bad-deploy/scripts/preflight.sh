#!/usr/bin/env bash
# Read-only. Refuses to pass unless the demo is in the alerting state.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/env.sh"; FAILED=0

app=$(kubectl --context "$KUBE_CONTEXT" -n argocd get application settlement-service -o jsonpath='{.status.sync.status}' 2>&1) \
  && ok "Argo CD app settlement-service ($app)" || bad "Argo CD app missing (user must apply argocd/application.yaml)"

r=$(kubectl --context "$KUBE_CONTEXT" -n "$NS" get pods -l app=settlement-service -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null)
case "$r" in *ImagePullBackOff*|*ErrImagePull*) ok "pod waiting: $r";; *) bad "pod not in ImagePullBackOff (got: '${r:-none}')";; esac

n=$(dtctl query 'fetch dt.davis.problems, from:now()-24h | filter event.status == "ACTIVE" and in("payments-demo", k8s.namespace.name) | summarize c = count()' -o json 2>/dev/null | jq -r '(.result.records[0].c // 0) | tonumber')
[ "${n:-0}" -ge 1 ] && ok "open problem in $NS ($n)" || bad "no open problem in $NS"

dtctl get workflows 2>/dev/null | grep -q "$WF_TITLE" && ok "workflow '$WF_TITLE' exists" || bad "workflow '$WF_TITLE' missing"
gh repo view "$GH_USER/$GH_REPO" >/dev/null 2>&1 && ok "GitHub repo reachable" || bad "GitHub repo not reachable"
gh api "repos/$GH_USER/$GH_REPO/contents/$APP_FILE?ref=$LIVE_BRANCH" -q .content 2>/dev/null | base64 -d | grep -q "image: $BAD_TAG" && ok "$LIVE_BRANCH has the bad tag (fix will be proposed by the workflow)" || bad "$LIVE_BRANCH does not have the bad tag"

[ "$FAILED" = 0 ] && printf '\n\033[32mREADY\033[0m\n' || { printf '\n\033[31mNOT READY\033[0m\n'; exit 1; }
