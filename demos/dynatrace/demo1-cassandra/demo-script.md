# Demo 1 script (about 12 to 13 minutes, browser only)

Setup is done an hour before (README). Tabs open in advance: Problems app, Workflows app (execution list), GitHub PR list for `jib94/homelab`, mailbox, Notebooks.
Steps marked **(skip)** can be dropped if you are short on time.

| Min | Say / do | Show |
|---|---|---|
| 0:00 | "Payments sit on Cassandra. A slow write path delays settlement. This is the page that tells us, and what happens next without anyone paging an engineer." | Problems app, filtered to Cassandra |
| 1:30 | Open the latest problem. Point at the title, the node (`cassandra-0`), and the timeline. Be straight about status: if it is closed, say "it opened a few minutes ago; the workflow already ran on it". | Problem detail |
| 3:00 | "Detection is a Davis anomaly detector written in DQL. Threshold 200 microseconds against a normal 100 to 150." | Settings / Davis anomaly detectors, "DEMO1 Cassandra write latency P95 high" **(skip)** |
| 4:00 | Open the workflow. "It started on its own when the problem opened." Open the latest execution. | Workflows, execution graph |
| 5:00 | `enrich_latency`: node, current vs baseline vs peak. "Plain DQL, real numbers." | Task result |
| 6:00 | `STAND-IN: ticket`: show the JSON payload. "This is what we would send to xMatters or PagerDuty. In this demo it only builds the payload, nothing is sent." | Task result |
| 7:30 | `js_build_fix` then `open_fix_pr`: the fix is a branch and a pull request, not a change on the cluster. | Task results |
| 8:30 | Switch to GitHub. Open the pull request: title "[Dynatrace P-26xxxx] Cassandra write latency - proposed tuning", the body with the problem details and latency numbers. | PR page |
| 9:30 | "This is the guardrail. Nothing changes until a person reviews and merges. Your change process, your audit trail." Do **not** merge during the demo unless you want to; the proposal is illustrative. | PR page |
| 10:30 | Show the email with the problem summary and the PR link **(skip if mail is slow)**. | Mailbox |
| 11:30 | `verify` and `STAND-IN: PagerDuty notify`: show the mock payload (`sent: false`, fake routing key). "Same pattern for any tool you use. We connect it, nothing was sent today." | Task results |
| 12:30 | Close: detect with DQL, enrich, propose through version control, a human approves. | |

## If something is off

- **No problem listed:** open the Workflows execution list and show the last run; say the live problem expired.
- **Workflow shows ERROR:** show the failed task and say it plainly. Do not click Run during the demo unless you want a second PR.
- **No PR:** check the execution's `create_fix_branch` and `open_fix_pr` tasks. The GitHub connection may have expired.
- **Metric looks flat:** the burst ended. Show the Notebooks chart of the earlier spike instead.
