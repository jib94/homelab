#!/usr/bin/env bash
# Apply the Demo 1 workflow. Fills the email recipient from $DEMO_EMAIL (never stored in git).
# Usage: DEMO_EMAIL=you@example.com scripts/apply_workflow.sh [--dry-run]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${DEMO_EMAIL:?set DEMO_EMAIL to the recipient address}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed "s#REPLACE_DEMO_EMAIL#${DEMO_EMAIL}#g" "$HERE/../dynatrace/workflow-cassandra-remediation.yaml" > "$TMP/wf.yaml"
dtctl apply -f "$TMP/wf.yaml" "$@"
