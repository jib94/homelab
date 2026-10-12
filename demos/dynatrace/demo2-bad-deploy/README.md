# Demo 2 - Bad deploy -> Davis CoPilot proposes the fix -> workflow opens the PR -> human merges

An open problem (custom Gen 3 detector "DEMO2 Image pull failure in payments-demo") -> run workflow "Bad deploy - AI proposes the fix" -> a pull request with the AI's fix appears on GitHub -> a human merges -> Argo CD syncs -> the pod recovers.

## What the workflow does (all real, manual trigger)
1. `find_problem` - DQL on Grail: the ACTIVE problem in `payments-demo`.
2. `read_pods` - DQL on Smartscape: image, readiness and waiting reason of every settlement-service pod (the failing pod shows the bad image, the healthy one the good image).
3. `get_manifest` - GitHub connector: reads `deployment.yaml` from branch `demo2-live`.
4. `ai_fix` - Davis CoPilot (`dynatrace.davis.copilot.workflow.actions:davis-copilot`): proposes the corrected image as strict JSON, using the evidence above.
5. `js_build_patch` - guardrail: the proposal must be well formed, differ from the bad image and keep the same image repository; only the `image:` line is patched. Otherwise the workflow stops before touching GitHub.
6. `create_branch_commit` - GitHub connector: new branch `fix/settlement-service-<timestamp>` off `demo2-live` plus the commit.
7. `open_pr` - GitHub connector: pull request into `demo2-live` with the AI's reasoning, both images, the pods and the problem.
Nothing is applied to the cluster by the workflow. The person merges; Argo CD does the rest. The GitHub token lives in the tenant's GitHub connection (Settings > Connections), not in code. Pattern adapted from the "Self-Healing OOMKill Agent (connector)" example.

## Files
- `gitops-repo/` - the deployment and the Argo CD Application. Argo CD watches branch `demo2-live` of jib94/homelab (public repo), never `main`.
- `dynatrace/workflow-bad-deploy.yaml` - the workflow. `dynatrace/anomaly-detector-imagepull.yaml` - the detector.
- `scripts/rearm.sh` - back to the alerting state (bad tag on `demo2-live`, old fix branches deleted, old PRs closed, waits for the failing pod and its Dynatrace events). `scripts/preflight.sh` - read-only readiness check, must say READY. `scripts/deploy.sh` - installs workflow and detector (updates in place).

## Run order
1. Shortly before the session: `scripts/rearm.sh` (about 5 min, pushes to `demo2-live`), then `scripts/preflight.sh` -> READY.
2. Live: show the problem, open the workflow, Run, show the AI's answer and the PR, merge the PR, Argo CD recovers (about 1-3 min).
3. Repeat: `rearm.sh` again.

## Findings
- Davis opens no problem for ImagePullBackOff on its own (events are CUSTOM_INFO), hence the detector (DQL on events, 10-sample window).
- Problems auto-close every ~3.5-4.5 h and reopen ~5 min later while the pod keeps failing; each failing pod gets its own problem. Never quote a problem ID. The problem closes ~10 min after recovery, so do not wait for it live.
- Right after a re-arm the old healthy pod keeps running (rolling update) - say "the new version can't start", not "the service is down". That healthy pod is also the AI's evidence for the good image.
- The AI step is non-deterministic; the guardrail blocks bad output but cannot force the right answer. Two runs both proposed `nginx:1.27`.
- Needs the user once: apply `gitops-repo/argocd/application.yaml` (argocd ns is protected). The Argo CD refresh in `rearm.sh` is blocked for the same reason; Argo's own poll picks the change up.
