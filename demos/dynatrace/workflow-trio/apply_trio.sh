#!/usr/bin/env bash
# Apply one workflow of the trio. Fills the email recipient from $DEMO_EMAIL (never stored in git).
# Usage: DEMO_EMAIL=you@example.com ./apply_trio.sh <workflow.yaml> [--dry-run]
# Re-applying updates in place when <workflow>.id exists next to the YAML (put the workflow id from the first apply there).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${DEMO_EMAIL:?set DEMO_EMAIL to the recipient address}"
SRC="${1:?usage: apply_trio.sh <workflow.yaml> [--dry-run]}"; shift || true
[[ -f "$SRC" ]] || SRC="$HERE/$SRC"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed "s#REPLACE_DEMO_EMAIL#${DEMO_EMAIL}#g" "$SRC" > "$TMP/wf.yaml"
ID_FILE="${SRC%.yaml}.id"
ID_ARG=()
[[ -s "$ID_FILE" ]] && ID_ARG=(--id "$(cat "$ID_FILE")")
dtctl apply -f "$TMP/wf.yaml" "${ID_ARG[@]}" "$@"
