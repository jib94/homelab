# Demo 2 - Bad deploy -> automation opens the fix -> human approves in Git

Open problem (Davis "Backoff event" on `payments-demo`) -> run workflow "Bad deploy - open the fix" -> revert PR + email -> human merges -> Argo CD syncs -> problem closes.

- `gitops-repo/` : the deployment and Argo CD Application. Argo CD watches branch `demo2-live` of jib94/homelab (must be public); the PR targets it too.
- `dynatrace/workflow-bad-deploy.yaml` : manual-trigger Gen 3 workflow. The GitHub PR step is a STAND-IN (builds the payload, sends nothing); email is real.
- `scripts/deploy.sh` setup, `rearm.sh` back to alerting state, `preflight.sh` read-only readiness check.

Needs the user: make the homelab repo public (or give Argo CD a credential), apply `argocd/application.yaml` once (argocd ns is protected), run deploy.sh.
Unverified until the live test: problem opens and stays open for hours; `read_pod` DQL returns a row; manual trigger runs from the UI.
