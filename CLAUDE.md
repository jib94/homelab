# Homelab

## Environment
- Ubuntu on a single desktop (dual-boot with Windows), hostname MS-7D77, node IP 192.168.1.100.
- Single-node k3s with the default SQLite datastore. Traefik is the ingress controller.
- Argo CD runs in the `argocd` namespace. Dynatrace Operator with cloudNativeFullStack OneAgent runs in the `dynatrace` namespace. Never modify either.
- App and demo namespaces: apps, easytrade, otel-demo, selfhealing-demo, wealth-demo. Claude may write only here.
- Workspace: /home/claude/src/homelab (git). Manifests in manifests/<app>/, notes in notes/.

## Access model
- The default kube context is homelab-ro (read-only, no Secrets). Use `--context homelab-rw` only when I ask for a change, and only in the app namespaces. Never switch the default context.
- You cannot delete anything or read Secrets. If a task needs that, print the exact command and stop so I can run it.
- There is no general sudo. If root is needed, print the command for me to run.
- Helm: use `helm template` to render. I run `helm upgrade` myself.

## How to work
- Plan first. Show the manifest diff, then apply only after I approve.
- Prefer small, reversible steps. Commit after each working change.
- Never put secrets, tokens or kubeconfigs in files, notes or commit messages.
- When the context gets long or I change topics, run /handoff before we stop.

## Notes index
@notes/INDEX.md

## Git workflow
- Never commit or push to main. Create a branch named claude/<topic>, commit there, push it, and open a pull request with `gh pr create`. I merge in GitHub.
- Argo CD only syncs main, so nothing changes in the cluster until I merge.

## Dynatrace tools
- Default to dtctl for everything Dynatrace: queries, listing and reading resources, and creating or changing notebooks, dashboards and workflows. Try dtctl first.
- Use the Dynatrace MCP plugin only for: (1) root cause analysis of a specific problem, (2) turning a plain-English question into DQL when I ask for it, (3) anything dtctl cannot do. Say which case applies before using it.
- Do not use the MCP plugin for plain queries, listing resources, or building and editing content.
- Keep definitions as files under dynatrace/ in git. Show me the diff, then apply with dtctl after I approve.
- Start DQL with short timeframes (for example the last 2 hours), since scans can cost money.
