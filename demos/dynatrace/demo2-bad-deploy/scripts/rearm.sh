#!/usr/bin/env bash
# Put the demo back into the alerting state: bad tag on demo2-live, fix branch recreated, pod in ImagePullBackOff, problem open.
# Pushes only to demo2-live and the fix branch. Never touches main. No force-push to demo2-live.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/env.sh"; FAILED=0
src="$here/../gitops-repo/apps/settlement-service/deployment.yaml"
[ -d "$GITOPS_DIR/.git" ] || git clone -q "https://github.com/$GH_USER/$GH_REPO.git" "$GITOPS_DIR"
cd "$GITOPS_DIR"; git fetch -q origin

# close earlier demo PRs
for n in $(gh pr list -R "$GH_USER/$GH_REPO" --state open --base "$LIVE_BRANCH" --json number -q '.[].number'); do gh pr close "$n" -R "$GH_USER/$GH_REPO" -d; done

# live branch = bad tag (created from main on first run)
if git rev-parse -q --verify "origin/$LIVE_BRANCH" >/dev/null; then git checkout -q -B "$LIVE_BRANCH" "origin/$LIVE_BRANCH"; else git checkout -q -B "$LIVE_BRANCH" origin/main; fi
mkdir -p "$(dirname "$APP_FILE")"; cp "$src" "$APP_FILE"
sed -i "s#image: .*#image: $BAD_TAG#" "$APP_FILE"
git add "$APP_FILE"
git diff --cached --quiet || { git commit -qm "Deploy settlement-service $BAD_TAG (demo: bad tag)"; git push -q origin "$LIVE_BRANCH"; }

# fix branch = one-line revert on top of live
git push -q origin --delete "$FIX_BRANCH" 2>/dev/null || true
git checkout -q -B "$FIX_BRANCH" "$LIVE_BRANCH"
sed -i "s#image: .*#image: $GOOD_TAG#" "$APP_FILE"
git commit -qam "Revert bad image tag on settlement-service"; git push -q origin "$FIX_BRANCH"
git checkout -q "$LIVE_BRANCH"

kubectl --context homelab-rw -n argocd annotate application settlement-service argocd.argoproj.io/refresh=hard --overwrite \
  || echo "NOTE: could not refresh Argo CD; run it yourself or wait ~3 min"

echo "waiting up to 5 min for ImagePullBackOff..."
for _ in $(seq 1 30); do
  kubectl --context "$KUBE_CONTEXT" -n "$NS" get pods -l app=settlement-service -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null | grep -Eq 'ImagePullBackOff|ErrImagePull' && break
  sleep 10
done
# wait until Dynatrace has recorded events from the NEW failing pod (so the workflow never reads the old pod's name)
echo "waiting up to 5 min for Dynatrace to record the new pod's failure events..."
for _ in $(seq 1 30); do
  pod=$(kubectl --context "$KUBE_CONTEXT" -n "$NS" get pods -l app=settlement-service -o json | jq -r '[.items[] | select(.status.containerStatuses[0].state.waiting.reason != null)][0].metadata.name // empty')
  if [ -n "$pod" ]; then
    n=$(dtctl query "fetch events, from:now()-10m | filter k8s.pod.name == \"$pod\" | summarize c = count()" -o json 2>/dev/null | jq -r '.result.records[0].c // 0')
    [ "${n:-0}" -ge 1 ] && break
  fi
  sleep 10
done
exec "$here/preflight.sh"
