# Demo 1: Cassandra write latency -> guardrailed remediation

A payment-critical Cassandra node slows down. Dynatrace opens a problem, a workflow enriches it, files a ticket payload,
and proposes a fix as a **GitHub pull request**. Nothing is applied until a human merges it. That merge is the guardrail.

## What is real and what is a stand-in

| Step | Status |
|---|---|
| Cassandra on k3s, OneAgent, Cassandra extension metric `cassandra.clientRequest.write.latency.95thPercentile` | Real |
| Gen3 DQL anomaly detector (static threshold 200 us) -> Davis problem | Real |
| Workflow trigger on the Davis problem | Real |
| DQL enrichment (affected node, current vs baseline vs peak P95) | Real |
| Ticket (xMatters / PagerDuty) | **STAND-IN.** A JavaScript task returns the payload. Nothing is sent. |
| Branch + pull request in `jib94/homelab` through the GitHub connector | Real. This is the human guardrail. |
| Email with problem details and the PR link | Real |
| Verify (latency back under 200?) | Real DQL |
| PagerDuty notify (Events API v2 shape) | **STAND-IN.** Mock payload, fake routing key, `sent: false`. |

Merging the tuning PR does **not** change the live Cassandra. The proposal is a ConfigMap-shaped file, illustrative only.

## Pieces

| Where | What |
|---|---|
| `k8s/` | Namespace `cassandra-demo`, Cassandra StatefulSet, baseline load Job (300 ops/s, 8 h), burst Deployment (unthrottled, off by default) |
| `dynatrace/anomaly-detector-cassandra-latency.yaml` | Detector. Threshold 200 us, 3 of 5 samples, merge allowed |
| `dynatrace/workflow-cassandra-remediation.yaml` | Workflow. Email address is a placeholder, filled at apply time |
| `scripts/` | `start-demo.sh`, `preflight.sh`, `degrade.sh`, `reset.sh`, `latency.sh`, `apply_workflow.sh`, `teardown.sh` |

Tenant objects: workflow `44d53008-24e2-4d4d-8366-ea589e9cac8c` (id in `dynatrace/workflow.id`), detector "DEMO1 Cassandra write latency P95 high".

## Measured numbers

- Baseline P95: 103 to 149 us. Spike: 215 to 310 us. Values are bucket edges (103, 124, 149, 179, 215, 258, 310), so they look quantized.
- Only a near-saturating, unthrottled write load moved P95. Throttled loads at 4k and 25k ops/s did not.
- Metric crosses 200 within 1 to 5 min of the burst starting.
- First detector event appears about 6 to 7 min after the metric crosses. The workflow started about the same time (two runs).
- P95 decays slowly after the burst ends (about 20 min to fall under 200).
- A Davis problem from this detector can close within 1 to 3 min while the event stays active. The latest problem is therefore often **closed** when you look. The workflow is built for that (it takes the latest problem, open or closed).

## Setup, one hour before

1. `scripts/preflight.sh` (read-only). Fix any FAIL. Close old demo PRs in GitHub if you do not want them in the story.
2. T-60: `scripts/start-demo.sh baseline`
3. T-35: `scripts/start-demo.sh spike 40` (a 40-minute burst, about 15 GB of Cassandra data on disk)
4. T-5: `scripts/preflight.sh` again. Expect: metric 215+, a problem listed, a workflow run SUCCESS, one open PR titled "[Dynatrace P-26xxxx] Cassandra write latency - proposed tuning".
5. After: `scripts/start-demo.sh stop`, close or merge the PR, and delete its branch.

Applying the workflow needs the recipient: `DEMO_EMAIL=<address> scripts/apply_workflow.sh`. The address is never committed.

## Unverified (read before the day)

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
