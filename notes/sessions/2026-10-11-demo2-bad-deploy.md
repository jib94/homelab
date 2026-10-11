# Demo 2: bad deploy -> automation opens the fix (2026-10-11)

## Goal and what was accomplished
Build Demo 2 of 3 for a customer Dynatrace presentation: a bad image tag deployed via Git, a problem already open, a manual-trigger workflow that prepares the revert PR, a person merges, Argo CD recovers. External tools are stand-ins only.

Done:
- Scaffold in `demos/dynatrace/demo2-bad-deploy/` (gitops-repo manifests, Argo CD Application, workflow, detector, scripts, README).
- Workflow "Bad deploy - open the fix" (id `c71dc0fb-67b2-48cf-8751-b432e069f7a4`) created in the tenant, manual trigger, 5 s runs, succeeded twice.
- Custom Gen 3 detector "DEMO2 Image pull failure in payments-demo" created in the tenant.
- Argo CD Application `settlement-service` applied by the user (watches branch `demo2-live` of jib94/homelab).
- Three rearm runs, two merge/recovery runs (merge to Healthy: 2m43s, then ~40 s). Preflight reports READY.

## Decisions and why
- **Use the homelab repo, not a new repo.** The token cannot create repos (deliberate) or write to a new repo. Argo CD watches the dedicated branch `demo2-live`, never `main`, so rearm can push the bad tag without breaking the no-commit-to-main rule. Repo was made public so Argo CD needs no credential.
- **Custom detector** (user override of the "no custom detector" rule): Davis opens no problem for ImagePullBackOff on its own (events are CUSTOM_INFO). Detector uses DQL on Grail events, 10-sample window because Kubernetes re-emits the event only every 4-5 min.
- **PR step is a STAND-IN** (builds the payload, sends nothing). No evidence of a GitHub connection in the tenant. Email task is real; the user will likely not show it.
- Fix branch is pre-staged: `claude/fix-revert-bad-tag`; the revert PR (into `demo2-live`) is opened by hand or by Claude.
- Workflow trigger is manual; `find_problem` looks up whichever problem is ACTIVE in `payments-demo`.

## Current state
- Cluster: namespace `payments-demo`, Deployment `settlement-service` (bad tag `nginx:1.27-doesnotexist` on `demo2-live`). New pod in ImagePullBackOff, old healthy pod still running (rolling update). Argo app Synced/Degraded. Other namespaces untouched.
- Dynatrace: several ACTIVE problems for payments-demo (one per failing pod; older ones from deleted pods linger).
- GitHub (jib94/homelab): PR #3 open (scaffold, into main; merging deploys nothing). PRs #11 and #13 merged into `demo2-live`. `demo2-live` currently has the bad tag. Branch `claude/fix-revert-bad-tag` has the one-line revert.
- Local: main checkout `~/src/homelab` is on `main`. Worktree `~/src/homelab-demo2-scripts` is on `claude/demo2-bad-deploy` (scripts run from here). Clone `~/src/homelab-demo2` is used by rearm.sh. `~/src/payments-demo-gitops` is a leftover local seed repo, unused. `jib94/payments-demo-gitops` on GitHub is empty and unused.
- `demos/dynatrace/demo1-cassandra/scripts/degrade.sh` has an uncommitted change in the main checkout that is not from this session.

## Unfinished work and exact next steps
1. User says when ready: run `~/src/homelab-demo2-scripts/demos/dynatrace/demo2-bad-deploy/scripts/rearm.sh` (about 5 min, pushes to `demo2-live` and the fix branch; needs approval), then `scripts/preflight.sh` and expect READY. No test runs (user decision: too slow).
2. Open the revert PR from `claude/fix-revert-bad-tag` into `demo2-live` if wanted for the live merge.
3. Merge PR #3 (user) when ready; optional.
4. User: record backup video; decide whether to delete `~/src/payments-demo-gitops` and the empty GitHub repo.
5. Demos 1 and 3 untouched this session.

## Gotchas, commands, paths
- Problems auto-close every ~3.5-4.5 h and reopen ~5 min later; each failing pod gets its own problem. Never quote a problem ID. Closing after a fix takes ~10 min, so do not wait for it live.
- `argocd` namespace is protected: Claude cannot refresh or read the Application; rearm prints a "could not refresh" note and waits for Argo's poll. User applies Argo objects with their own `kubectl` (user `jordan` has only a `default` context, no `homelab-rw`; files must be readable by jordan, e.g. /tmp).
- Right after rearm the workflow can name the old pod; rearm now waits for the new pod's events.
- `dtctl` returns counts as strings; use `jq ... | tonumber`. `deploy.sh` updates workflow/detector in place by title lookup (no duplicates).
- Say "the new version can't start", not "the service is down" (the old pod keeps serving).
- Files: `demos/dynatrace/demo2-bad-deploy/{README.md,dynatrace/,gitops-repo/,scripts/}`. Memory: demo2-problem-cycles.
- `gh` token can push branches and open/close PRs on jib94/homelab but cannot create repos (intentional).
