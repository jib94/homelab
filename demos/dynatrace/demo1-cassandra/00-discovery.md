# 00 - Discovery (Phase 0, read-only)

Date: 2026-10-10. Nothing was changed on the cluster or tenant to produce this.

## Targets (confirmed by the presenter)
- Kubernetes: single-node k3s `jordan-ms-7d77` (v1.35.4+k3s1), context `homelab-ro` for reads, `homelab-rw` for changes.
- Dynatrace: dtctl context `homelab`, a Dynatrace Labs sprint tenant, safety level `readwrite-mine`.
- dtctl 0.42.0. `dtctl doctor`: token OK, connectivity OK.
  Warning only: keyring probe fails (set `DTCTL_TOKEN_STORAGE=file` if needed).

## Cluster capacity
| Item | Value |
|---|---|
| Allocatable | 12 CPU, ~32 GB RAM, 110 pods |
| Requested | 4.5 CPU (37%), 15 GB (48%) |
| Headroom vs needed (~3 CPU / ~3 GiB) | Enough. No shrinking needed. |
| Storage class | `local-path` (default, WaitForFirstConsumer, reclaim `Delete`) |

Teardown deletes the PVC, which deletes the Cassandra data.

## OneAgent
- DynaKube `jordan-ubuntu-cluster-agents` uses `cloudNativeFullStack`, host group `demo`.
- Injection applies to every namespace not labelled `dynatrace.com/inject=false`, so `cassandra-demo` should be injected.
- Not yet verified: the Cassandra process appearing in Dynatrace (needs the pod running).

## dtctl capabilities used
| Need | Command |
|---|---|
| DQL | `dtctl query`, `dtctl verify query`, `dtctl wait query` |
| Workflows | `dtctl apply/create workflow -f`, `dtctl exec workflow`, `dtctl get workflow-executions` |
| Metric event | `dtctl create settings -f` (schema `builtin:anomaly-detection.metric-events`) |
| Alternative detector | `dtctl create anomaly-detector -f` (schema `builtin:davis.anomaly-detectors`) |
| Metrics catalog | `dtctl query 'metrics \| filter ...'` |
| Problems | DQL on `fetch events` (`event.kind == "DAVIS_PROBLEM"`) |

## Workflow building blocks available
- `dynatrace.automations/http-function` (HTTP Request), `execute-dql-query`, `run-javascript`.
- **`dynatrace.automations/request-approval` - a native approval step exists.** Settings schema `builtin:automation.approval` is present (`workflowAppAccessApprovalEnabled` defaults to true). So no fallback second-workflow is needed.
- `dynatrace.email` app for the email step.

## Cassandra extension
- Hub has **Apache Cassandra** `com.dynatrace.extension.jmx-cassandra` (releases 1.3.0, 1.2.0, 1.1.1, 1.1.0).
- It is **not installed** in the tenant. No `cassandra` metrics exist yet.
- Installing it is a tenant write (`dtctl create extension`) and needs presenter approval.
- Setup requirements (JMX endpoint / monitoring config) not yet read: the hub describe output has no detail. To check before Phase 2.

## Existing tenant content (do not touch)
11 existing workflows, including Davis-problem-triggered ones (e.g. "Send Email Notifications for problems", active, availability category).
Make sure the demo workflow's trigger filter is specific to the Cassandra problem so it does not overlap.

## Stub reachability
- One EdgeConnect exists in the tenant (unnamed, id `8274c48c-264a-40ab-8705-5984b025bc9c`). Not yet checked whether it is online or can reach the cluster.
- The SaaS tenant cannot reach in-cluster addresses directly. Decision needed in Phase 5.

## Open decisions for the presenter
1. Approve creating the new namespaces and the Cassandra manifests (Phase 1).
2. Approve installing the Cassandra extension in the tenant (Phase 2).
3. Stub exposure approach (Phase 5).
4. Email recipient env var and `DT_TOKEN` (metrics.ingest, fallback only).
