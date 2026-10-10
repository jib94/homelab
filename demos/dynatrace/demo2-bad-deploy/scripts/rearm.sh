#!/usr/bin/env bash
# Put the demo back into the alerting state: bad tag on main, fix branch recreated, pod in ImagePullBackOff, problem open.
# Pushes to the DEMO repo's main only (never the homelab repo). Adds a commit; no force-push to main.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/env.sh"; FAILED=0
F=apps/settlement-service/deployment.yaml
cd "$GITOPS_DIR"; git checkout -q main; git pull -q --ff-only

# close earlier demo PRs/issues
for n in $(gh pr list -R "$GH_USER/$GH_REPO" --state open --json number -q '.[].number'); do gh pr close "$n" -R "$GH_USER/$GH_REPO" -d; done
for n in $(gh issue list -R "$GH_USER/$GH_REPO" --state open --json number -q '.[].number'); do gh issue close "$n" -R "$GH_USER/$GH_REPO"; done

# main = bad tag
if ! grep -q "image: $BAD_TAG" "$F"; then
  sed -i "s#image: .*#image: $BAD_TAG#" "$F"
  git commit -qam "Deploy settlement-service $BAD_TAG (demo: bad tag)"; git push -q origin main
fi

# fix branch = one-line revert, recreated from main
git branch -D fix/revert-bad-tag 2>/dev/null || true
git push -q origin --delete fix/revert-bad-tag 2>/dev/null || true
git checkout -q -b fix/revert-bad-tag
sed -i "s#image: .*#image: $GOOD_TAG#" "$F"
git commit -qam "Revert bad image tag on settlement-service"; git push -q origin fix/revert-bad-tag
git checkout -q main

# refresh Argo CD (the Application lives in argocd; annotating it is a write there, so the user runs this if blocked)
kubectl --context homelab-rw -n argocd annotate application settlement-service argocd.argoproj.io/refresh=hard --overwrite \
  || echo "NOTE: could not refresh Argo CD; run it yourself or wait ~3 min"

echo "waiting up to 5 min for ImagePullBackOff..."
for _ in $(seq 1 30); do
  kubectl --context "$KUBE_CONTEXT" -n "$NS" get pods -l app=settlement-service -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null | grep -Eq 'ImagePullBackOff|ErrImagePull' && break
  sleep 10
done
exec "$here/preflight.sh"
