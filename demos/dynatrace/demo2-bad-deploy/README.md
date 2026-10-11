# Demo 2 - Bad deploy -> automation opens the fix -> human approves in Git

Open problem (custom Gen 3 detector "DEMO2 Image pull failure in payments-demo") -> run workflow "Bad deploy - open the fix" -> revert PR + email -> human merges -> Argo CD syncs -> problem closes.

- `gitops-repo/` : the deployment and Argo CD Application. Argo CD watches branch `demo2-live` of jib94/homelab (must be public); the PR targets it too.
- `dynatrace/workflow-bad-deploy.yaml` : manual-trigger Gen 3 workflow. The GitHub PR step is a STAND-IN (builds the payload, sends nothing); email is real.
- `scripts/deploy.sh` setup, `rearm.sh` back to alerting state, `preflight.sh` read-only readiness check.

Needs the user: make the homelab repo public (or give Argo CD a credential), apply `argocd/application.yaml` once (argocd ns is protected), run deploy.sh.
Unverified until the live test: problem opens and stays open for hours; `read_pod` DQL returns a row; manual trigger runs from the UI.

## Findings from the first live run (2026-10-11)
- Davis opens no problem for ImagePullBackOff on its own (events are CUSTOM_INFO), so `dynatrace/anomaly-detector-imagepull.yaml` was added (DQL on Grail events, 10-sample window).
- Problems auto-close every ~3.5-4.5 h and a new one opens ~5 min later while the pod keeps failing. Never quote a problem ID; `find_problem` looks up whichever is ACTIVE. Run `preflight.sh` before a session.
- Workflow ran end to end (manual trigger, 5 s). Recovery close after the merge: ~10 min expected, not yet confirmed.
