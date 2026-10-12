# Demo 1 script (about 13 minutes, browser only)

Flow: the problem already exists -> you explain it -> you walk the workflow -> you run it by hand -> you approve the PR on GitHub
-> Argo CD applies the fix -> you show latency back to normal in Dynatrace.

Setup is done an hour before (README). Tabs open in advance: Problems app, Notebook with the latency chart, Workflows app, GitHub PR list for `jib94/homelab`, mailbox, Argo CD (optional).
Steps marked **(skip)** can be dropped if you are short on time.

| Min | Say / do | Show |
|---|---|---|
| 0:00 | "Payments sit on Cassandra. A slow write path delays settlement. Here is what Dynatrace already sees." | Problems app, the Cassandra problem |
| 1:30 | Walk the problem: title, node `cassandra-0`, timeline. If it shows as closed, say "it opened earlier and the condition is still ongoing" and point at the chart. | Problem detail, then the Notebook latency chart: about 258 us against a 100 to 150 baseline |
| 3:30 | "Detection is a Davis anomaly detector written in DQL. Threshold 200 microseconds." **(skip)** | Davis anomaly detector settings |
| 4:30 | Open the workflow "Cassandra write latency - guardrailed remediation". Describe each step left to right: find the problem, enrich with DQL, ticket payload (stand-in), build the fix, open a pull request (the guardrail), email, PagerDuty payload (stand-in). | Workflow graph |
| 7:00 | Click Run. Open the execution while it runs (about 20 s). | Execution view |
| 8:00 | Show `enrich_latency` (real numbers), `STAND-IN: ticket` (JSON, nothing sent), then `open_fix_pr`. | Task results |
| 9:00 | Switch to GitHub: PR "[Dynatrace P-26xxxx] Cassandra write latency - throttle bulk load" into `demo1-live`. Read the body. "The change is one line: throttle the bulk-load job. Nothing is deleted, and reverting restores it." | PR page, Files changed |
| 10:00 | "This is the guardrail. Our change process, our audit trail." **Merge the PR.** | PR page |
| 10:30 | Show the email and the PagerDuty payload (`sent: false`) **(skip)**. Show Argo CD syncing `demo1-bulk-ingest` **(skip)**. | Mailbox / Argo CD |
| 11:30 | Go back to the Notebook chart and refresh: latency falling toward baseline. See the timing note below. | Notebook chart |
| 12:30 | Close: detect with DQL, enrich, propose through version control, a human approves, GitOps applies. | |

## Timing: be honest about this

After you merge, the fix reaches Cassandra in stages: Argo CD notices the merge (up to about 3 min), Kubernetes refreshes the mounted file (up to about 1.5 min), the job restarts at the lower rate (10 s), then P95 falls back (several minutes, because it is a percentile). **Expect roughly 8 to 12 minutes from merge to a clean chart. This has not been measured end to end.** Merge early (around minute 8 to 9 if you can) and return to the chart at the end, or tell the audience "this settles over the next few minutes".

## If something is off

- **Run fails:** show the failed task and say so. Check the GitHub connection.
- **No PR:** check `create_fix_branch` and `open_fix_pr` in the execution.
- **Chart not moving after the merge:** check the Argo CD app and the `bulk-ingest-config` ConfigMap (`mode` should be `throttled`).
- **No problem listed:** show the Notebook chart and the last workflow run.
