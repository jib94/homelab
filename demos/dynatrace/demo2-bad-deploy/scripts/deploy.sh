#!/usr/bin/env bash
# One-command setup. Run steps that need the protected argocd namespace yourself (printed below).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/env.sh"; root="$here/.."

echo "1) Workflow (Dynatrace):"
sed "s#REPLACE_DEMO_EMAIL#$DEMO_EMAIL#" "$root/dynatrace/workflow-bad-deploy.yaml" > "${TMPDIR:-/tmp}/wf-demo2.yaml"
dtctl apply -f "${TMPDIR:-/tmp}/wf-demo2.yaml"

echo; echo "2) Run this yourself ONCE (argocd namespace is protected for Claude):"
echo "   kubectl --context homelab-rw apply -f $root/gitops-repo/argocd/application.yaml"
read -r -p "Press Enter when applied... " _
"$here/rearm.sh"
