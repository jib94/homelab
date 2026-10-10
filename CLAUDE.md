# Homelab

## Environment
- Ubuntu on a single desktop (dual-boot with Windows), hostname MS-7D77, node IP 192.168.1.100.
- Single-node k3s with the default SQLite datastore. Traefik is the ingress controller.
- Argo CD runs in the `argocd` namespace. Dynatrace Operator with cloudNativeFullStack OneAgent runs in the `dynatrace` namespace. Never modify either.
- Claude may write in any namespace except the protected ones: kube-system, argocd, dynatrace, claude-access, kube-public, kube-node-lease (an admission policy blocks writes there).
- Workspace: /home/claude/src/homelab (git). Manifests in manifests/<app>/, notes in notes/.

## Access model
- The default kube context is homelab-ro (read-only, no Secrets). Use `--context homelab-rw` only when I ask for a change. Never switch the default context.
- You can create and manage namespaces and workloads, and delete with my approval, but never in protected namespaces. You cannot read Secrets, change RBAC, or touch nodes or CRDs. If a task needs those, print the exact command and stop so I can run it.
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
