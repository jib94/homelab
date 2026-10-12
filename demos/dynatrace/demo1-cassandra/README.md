# Demo 1: Cassandra write latency -> guardrailed remediation

A payment-critical Cassandra node slows down because a bulk-load job saturates its writes. Dynatrace has already raised a problem.
The presenter runs a **manual** workflow that enriches it, builds a ticket payload and proposes the fix as a **GitHub pull request**.
A human merges the PR, **Argo CD applies it**, and write latency falls back to normal. Nothing is applied until the merge.

## What is real and what is a stand-in

| Step | Status |
|---|---|
| Cassandra on k3s, OneAgent, Cassandra extension metric `cassandra.clientRequest.write.latency.95thPercentile` | Real |
| Gen3 DQL anomaly detector (static threshold 200 us) -> Davis problem | Real |
| Workflow trigger | **Manual** (the presenter clicks Run) |
| DQL enrichment (affected node, current vs baseline vs peak P95) | Real |
| Ticket (xMatters / PagerDuty) | **STAND-IN.** A JavaScript task returns the payload. Nothing is sent. |
| Branch + pull request into `jib94/homelab` branch `demo1-live` through the GitHub connector | Real. This is the human guardrail. |
| Email with problem details and the PR link | Real |
| PagerDuty notify (Events API v2 shape) | **STAND-IN.** Mock payload, fake routing key, `sent: false`. |
| Argo CD applies the merged change (ConfigMap `bulk-ingest-config`: `mode: full` -> `throttled`) | Real |
| The bulk-load job picks up the new mode and throttles itself | Real |

The fix is non-destructive and reversible: the load generator keeps running at 4 threads / 100 ops/s instead of 200 unthrottled threads. Reverting the PR restores it.

## Pieces

| Where | What |
|---|---|
| `k8s/` | Namespace `cassandra-demo`, Cassandra StatefulSet, baseline load Job (300 ops/s, 8 h), bulk-load Deployment (off by default; reads `bulk-ingest-config`) |
| `gitops-repo/` | The Argo CD-managed ConfigMap and the Argo CD `Application` (applied once by the user) |
| `dynatrace/anomaly-detector-cassandra-latency.yaml` | Detector. Threshold 200 us, 3 of 5 samples, merge allowed |
| `dynatrace/workflow-cassandra-remediation.yaml` | Workflow. Email address is a placeholder, filled at apply time |
| `scripts/` | `start-demo.sh`, `rearm.sh`, `preflight.sh`, `degrade.sh`, `reset.sh`, `latency.sh`, `apply_workflow.sh`, `teardown.sh` |

Tenant objects: workflow `44d53008-24e2-4d4d-8366-ea589e9cac8c` (id in `dynatrace/workflow.id`), detector "DEMO1 Cassandra write latency P95 high".

## Measured numbers

- Baseline P95: 103 to 149 us. Spike: 215 to 310 us. Values are bucket edges (103, 124, 149, 179, 215, 258, 310), so they look quantized.
- Only a near-saturating, unthrottled write load moved P95. Throttled loads at 4k and 25k ops/s did not.
- Metric crosses 200 within 1 to 5 min of the burst starting.
- First detector event appears about 6 to 7 min after the metric crosses. The workflow started about the same time (two runs).
- P95 decays slowly after the burst ends (about 20 min to fall under 200).
- A Davis problem from this detector can close within 1 to 3 min while the event stays active. The latest problem is therefore often **closed** when you look. The workflow is built for that (it takes the latest problem, open or closed).

## One-time setup (user)

1. Merge the Demo 1 gitops PR into `main`.
2. `scripts/rearm.sh` creates the `demo1-live` branch from `main` (the only branch Argo CD tracks; `main` is never changed by the demo).
3. Apply the Argo CD app once (the `argocd` namespace is protected for Claude): `kubectl --context homelab-rw apply -f gitops-repo/argocd/application.yaml`
4. `kubectl --context homelab-rw apply -f k8s/30-stress-burst.yaml` (resets the bulk-load Deployment to 0 replicas; it now mounts the ConfigMap).
5. `DEMO_EMAIL=<address> scripts/apply_workflow.sh` (the manual-trigger version).

## Setup, one hour before

1. `scripts/rearm.sh` (back to the problem state, closes old demo PRs), then `scripts/preflight.sh` (read-only). Fix any FAIL.
2. T-60: `scripts/start-demo.sh baseline`
3. T-35: `scripts/start-demo.sh spike 55` (a burst that outlasts the demo; roughly 20 GB of Cassandra data on disk, check the node first)
4. T-5: `scripts/preflight.sh` again. Expect: metric 215+, `bulk-ingest-config mode=full`, Argo app Synced/Healthy.
5. During the demo you run the workflow by hand. Afterwards: `scripts/start-demo.sh stop`, then `scripts/rearm.sh` to reset.

The recipient address is never committed.

## Unverified (read before the day)

- **The whole new flow is unrun.** The manual workflow, the PR into `demo1-live`, the Argo CD app, the ConfigMap-driven throttle and the recovery have not been run together. The throttle loop (`kill` of the stress process group) has not been run at all.
- **Time from merge to a clean chart is unmeasured** (Argo CD poll up to ~3 min, kubelet ConfigMap refresh up to ~1.5 min, then P95 decay). The script allows for roughly 8 to 12 minutes.
- **The Davis problem closes by itself within minutes** even while the load runs, so "the problem is fixed" cannot be shown as a problem closing. Show the latency chart.
- **Argo CD needs repo access** to `jib94/homelab` (the repo is public). The Application must be applied by you once.
- **A 55-minute burst costs about 20 GB of disk** (about 3 GB per 8 min).

- **The one-hour timeline has not been run as a sequence.** Each piece worked on its own. The 40-minute burst and the T-35 start time are derived from two earlier runs.
- **An open problem is not guaranteed at T.** Problems closed in 1 to 3 min in the last two runs. If none is open, the Problems app still shows the recent one. Say so rather than pretend.
- **Duplicate problems.** After the merge-allowed fix, one run still produced several problems (P-261045 and P-261050 about 25 min apart; the second may be a real second episode). A second workflow run means a second PR.
- **Two PRs per problem if you click Run during the demo.** The automatic run already opened one.
- **Email delivery** was never confirmed in a mailbox. The task shows SUCCESS.
- **Disk.** A burst writes about 3 GB per 8 min. The node had about 60 GB free earlier. Check before a 40-minute run.
- **Metric unit** is assumed to be microseconds.
- **GitHub connection** was set up for another repo and works for `jib94/homelab`. Its token lives in the connection, not in git.
- **Extension configuration** was made in the Dynatrace UI and is not in git.
- **dtctl safety level** was changed to `readwrite-all` to allow in-place updates; change it back if you prefer.
