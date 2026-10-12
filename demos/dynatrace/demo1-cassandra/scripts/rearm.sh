#!/usr/bin/env bash
# Put the GitOps side of Demo 1 back into the "problem" state: mode=full on the demo1-live branch, old fix PRs closed.
# Pushes only to demo1-live (created from main on the first run). Never touches main. No force-push.
# Does NOT start any load: use scripts/start-demo.sh for that.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
GH_USER="${GH_USER:-jib94}"; GH_REPO="${GH_REPO:-homelab}"
LIVE_BRANCH=demo1-live
APP_FILE=demos/dynatrace/demo1-cassandra/gitops-repo/apps/bulk-ingest/configmap.yaml
GITOPS_DIR="${GITOPS_DIR:-$HOME/src/homelab-demo1-gitops}"   # separate clone, so the working checkout is never disturbed
src="$here/../gitops-repo/apps/bulk-ingest/configmap.yaml"
grep -q 'mode: full' "$src" || { echo "FAIL: $src is not in mode: full"; exit 1; }

[ -d "$GITOPS_DIR/.git" ] || git clone -q "https://github.com/$GH_USER/$GH_REPO.git" "$GITOPS_DIR"
cd "$GITOPS_DIR"; git fetch -q origin

echo "closing earlier demo PRs into $LIVE_BRANCH (and deleting their branches)"
for n in $(gh pr list -R "$GH_USER/$GH_REPO" --state open --base "$LIVE_BRANCH" --json number -q '.[].number'); do
  gh pr close "$n" -R "$GH_USER/$GH_REPO" -d
done

if git rev-parse -q --verify "origin/$LIVE_BRANCH" >/dev/null; then
  git checkout -q -B "$LIVE_BRANCH" "origin/$LIVE_BRANCH"
else
  git rev-parse -q --verify origin/main:"$APP_FILE" >/dev/null || { echo "FAIL: $APP_FILE is not on main yet; merge the Demo 1 gitops PR first"; exit 1; }
  git checkout -q -B "$LIVE_BRANCH" origin/main
fi
mkdir -p "$(dirname "$APP_FILE")"; cp "$src" "$APP_FILE"
git add "$APP_FILE"
if git diff --cached --quiet; then echo "$LIVE_BRANCH already has mode: full"
else git commit -qm "Bulk-load job unthrottled (demo: problem state)"; fi
git push -q origin "$LIVE_BRANCH"
git checkout -q --detach

kubectl --context homelab-rw -n argocd annotate application demo1-bulk-ingest argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null \
  || echo "NOTE: could not refresh Argo CD (argocd namespace is protected); it syncs on its own within ~3 min"
echo "done. demo1-live is in the problem state."
