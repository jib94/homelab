#!/usr/bin/env bash
# One-command setup. Run steps that need the protected argocd namespace yourself (printed below).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/env.sh"; root="$here/.."

echo "1) Workflow + detector (Dynatrace). Updates in place if they already exist (no duplicates):"
sed "s#REPLACE_DEMO_EMAIL#$DEMO_EMAIL#" "$root/dynatrace/workflow-bad-deploy.yaml" > "${TMPDIR:-/tmp}/wf-demo2.yaml"
wf_id=$(dtctl get workflows -o json | jq -r --arg t "$WF_TITLE" '.result[] | select(.title==$t) | .id' | head -1)
dtctl apply -f "${TMPDIR:-/tmp}/wf-demo2.yaml" ${wf_id:+--id "$wf_id"}
det_title="DEMO2 Image pull failure in payments-demo"
det_id=$(dtctl get anomaly-detectors -o json | jq -r --arg t "$det_title" '.result[] | select(.value.title==$t) | .objectId' | head -1)
dtctl apply -f "$root/dynatrace/anomaly-detector-imagepull.yaml" ${det_id:+--id "$det_id"}

echo; echo "2) Run this yourself ONCE (argocd namespace is protected for Claude):"
echo "   kubectl --context homelab-rw apply -f $root/gitops-repo/argocd/application.yaml"
read -r -p "Press Enter when applied... " _
"$here/rearm.sh"
