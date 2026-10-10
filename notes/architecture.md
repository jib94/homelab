# Homelab architecture: what exists, why, and its limits

Read this before proposing any change to access, permissions, networking or deploys.
The design is defense in depth: every layer assumes the others can fail. The purpose is
that I (Ramon) can let Claude see everything and change things only with my approval.

## Core rules
- Never try to get around a guardrail. If something is blocked, stop, explain which layer
  blocked it and why, print the exact command, and let me run it. Looking for a workaround
  (another tool, encoding, a script, a different identity) counts as a failure even if it
  would technically work.
- Never weaken a guardrail to finish a task. Do not edit ~/.claude/settings.json, the guard
  hook, kubeconfigs, RBAC, admission policies, firewall rules, or tokens.
- Before every command that needs approval, explain in plain English: what it does, what
  changes, whether it is reversible, the risk, and a recommendation.
- If you are not sure whether you are allowed to do something, ask.

## Layer 1: Linux user "claude"
- Claude runs as a dedicated user, not as jordan (my admin account). It cannot read jordan's
  files and has no general sudo. The only sudo allowed is two read-only commands:
  "sudo -n ufw status verbose" and "sudo -n ss -tlnp".
- It is not in the docker group, because docker group membership is root-equivalent.
- Why: if a mistake or a prompt injection happens, the damage stops at this user's files.
- Limit: files under /home/claude are not in the restic backup. The workspace is safe
  because it lives in git (GitHub). Do not keep anything important only on disk.

## Layer 2: Kubernetes RBAC (two identities, in namespace claude-access)
- claude-ro is the default kube context (homelab-ro). It reads almost everything
  (built-in "view" role plus nodes, namespaces, PVs, storage classes, CRDs, metrics,
  Dynatrace, Argo CD and Traefik resources). It cannot read Secrets and cannot write.
- claude-rw is used only with --context homelab-rw, only when I ask for a change.
  ClusterRole claude-rw-cluster lets it create, update, patch and delete: namespaces,
  pods, services, endpoints, configmaps, PVCs, service accounts, resource quotas,
  limit ranges, deployments, statefulsets, daemonsets, replicasets, jobs, cronjobs,
  ingresses, network policies and traefik.io resources. It can read logs and events and
  open port-forwards.
- It deliberately cannot: read or write Secrets, touch RBAC (roles, bindings), change
  nodes, CRDs, PVs or storage classes, or exec into pods. Reasons: Secrets hold credentials;
  RBAC writes would let it grant itself more power; pods/exec can read Secret contents.
- Why two identities: reads can never write by accident, and any write needs an explicit
  context switch that Claude Code also asks me to approve.
- The admin kubeconfig (/etc/rancher/k3s/k3s.yaml) is mode 600, root only, and the k3s
  service uses --write-kubeconfig-mode 600. Claude cannot use "k3s kubectl". KUBECONFIG
  for the claude user points at /home/claude/.kube/config.

## Layer 3: admission policy protecting system namespaces
- ValidatingAdmissionPolicy claude-rw-protect-system (with a binding) refuses any create,
  update or delete by the claude-rw identity in: kube-system, argocd, dynatrace,
  claude-access, kube-public, kube-node-lease. It also refuses deleting those namespaces.
- Why: RBAC cannot exclude namespaces once a role is bound cluster-wide, and I want
  Claude to manage namespaces and apps without being able to break k3s, Argo CD,
  Dynatrace monitoring, or its own access setup.
- Limits: it only applies to the claude-rw identity. It does NOT stop a pod spec that is
  privileged or mounts host paths. Because claude-rw can create workloads in any
  non-protected namespace, a bad spec could reach the node. A second policy to block this
  is planned but not yet written. Until then you must never create privileged
  containers, hostPath volumes, hostNetwork, hostPID, hostIPC, or added capabilities, and
  you must tell me if a task seems to need them.

## Layer 4: Claude Code permissions (~/.claude/settings.json)
- Order of precedence: deny, then ask, then allow. defaultMode is "default" (manual).
  Never switch to auto mode and never recommend it.
- Allowed without asking (read-only): ls, kubectl get, describe, logs, top, auth can-i,
  api-resources, config get-contexts and current-context, helm template, git status,
  diff and log, journalctl, systemctl status, ss -tlnp, the two sudo reads above,
  gh pr view/list, gh issue view/list, dtctl get/describe/query/doctor/commands/inventory.
- Asks every time: kubectl apply, create, patch, scale, rollout, port-forward and delete,
  anything with --context homelab-rw, rm, git add/commit/push, npm, npx, pip, tmux, ufw,
  tailscale, gh pr create, gh issue create, dtctl apply/create/edit/exec.
- Denied outright: rm -r/-rf/-fr, kubectl drain, kubectl config use-context, helm
  uninstall/delete, mkfs/dd/shred/wipefs, git push --force and -f, git reset --hard,
  git clean, any push to main, reading .env files, ~/.ssh, ~/.kube and the Dynatrace and
  dtctl credential folders, gh repo delete/auth/secret, dtctl delete/auth/config set-*/
  use-context.
- kubectl delete used to be denied. I chose to allow it with approval, only where the
  admission policy allows writes. Drain stays denied.

## Layer 5: guard hook (/home/claude/.claude/hooks/guard.sh)
- Runs before every Bash command. It appends each command to ~/.claude/audit.log and
  blocks (exit code 2) text matching: recursive or forced rm, kubectl drain, replace
  --force, kubectl config use-context/set-/delete-, disk-level commands, force push,
  reset --hard, git clean, "curl | sh", and any mention of ~/.kube, ~/.ssh, id_ed25519,
  .restic-pass, .env, claude-secrets, the Dynatrace and dtctl credential paths, and
  DT_PLATFORM_TOKEN.
- The script and its folder are owned by root so you cannot edit them. I edit it as jordan.
- Limits: it is text matching, so it is a backstop, not a boundary. A legitimate command
  that merely contains a blocked string will be blocked, so reword it or ask me to run it.
  It cannot see what a script does inside a file. The RBAC and admission layers are the
  real boundaries.
- Known gap: settings.json itself is writable by the claude user (edits need my approval).
  Root-owned managed settings are not configured yet.

## GitHub: repo jib94/homelab (private) and why access is narrow
- The token on this machine is a fine-grained personal access token limited to the
  homelab repository, with only Contents (read/write) and Pull requests (read/write).
  Everything else is deliberately "no access": Administration (it could edit branch rules),
  Workflows (it could edit .github/workflows, which runs arbitrary code in CI), Secrets,
  Actions, Issues. If this token ever leaks, the damage is limited to this one repo.
- It is stored by gh in ~/.config/gh/hosts.yml, which your shell can technically read.
  gh auth, gh secret and gh repo delete are denied. Never print or inspect it.
- Branch ruleset "protect-main" on GitHub: block deletion, block force pushes, require a
  pull request (0 required approvals, because I cannot approve my own PR). Local deny
  rules also block pushes to main. Two layers on purpose.
- Workflow: work on a branch named claude/<topic>, commit, push the branch, open a PR with
  gh pr create. I review and merge in GitHub. Never merge PRs yourself, even though
  Contents write would technically allow it through the API. Once Argo CD is syncing this
  repo (Phase 4b), merging a PR is the deploy, so the PR is the approval gate.
- Limits: the ruleset's enforcement depends on my GitHub plan. You can push any branch.
  Never commit Secrets, tokens, kubeconfigs, or .env files. Kubernetes Secrets are created
  by me with kubectl as admin; Sealed Secrets or SOPS may come later.
- A different, separate token connects Dynatrace Workflows to GitHub. It is not yours.

## Dynatrace
- Tenant: tel93518.sprint.apps.dynatracelabs.com (a lab tenant, not production).
- dtctl is the default tool. Context "homelab", safety level readwrite-mine, using a
  platform token whose scopes are chosen by me. The safety level is a client-side check
  only. The real limit is the token's scopes. dtctl delete, auth and config changes are denied.
- The token is in ~/.local/share/dtctl and ~/.config/dtctl in plaintext (no keyring on this
  server). Never read these. Writes to the tenant (dtctl apply/create/edit/exec) ask me first.
- The Dynatrace MCP plugin uses a separate read-only platform token via DT_PLATFORM_TOKEN.
  Use it only for root-cause analysis, plain-English-to-DQL when I ask, or things dtctl
  cannot do. Say which case applies before using it.
- If dtctl returns 401 or an expired token, stop and tell me. Do not try to log in
  yourself. Login is interactive and credentials are mine to handle.
- Use Gen 3 features (DQL on Grail, Notebooks, Dashboards, Workflows, Davis anomaly
  detectors, OpenPipeline, IAM policies and Segments). Avoid classic features.

## Network and firewall
- ufw is active: default deny incoming, allow outgoing. From my home network (192.168.1.0/24)
  it allows SSH (22) and the NodePorts 32582 (EasyTrade), 30090 (OTel demo), 30800 and
  30808 (sdv2-lab Traefik), plus the k3s pod and service ranges (10.42.0.0/16, 10.43.0.0/16).
- The Kubernetes API (6443) and kubelet (10250) are closed to the LAN on purpose; this
  machine is the only client.
- You cannot change the firewall (no sudo; ufw commands ask me). If a new app needs a
  NodePort, tell me the port and I will open it. Prefer Ingress or port-forward.
- Never use Tailscale Funnel or router port forwards. Nothing here should be public.

## Backups
- Nightly k3s datastore archive (03:00) in /var/backups/homelab, and a restic repo
  (03:30) in /var/backups/restic. Both are root-only. You cannot read or run them.
- Not backed up: the Docker Desktop image, and /home/claude (git is the backup).
- k3s uses the default SQLite datastore, so backups copy the db folder and the server token.

## Argo CD and deploys
- Argo CD runs in the argocd namespace and is protected from writes by you. Phase 4b
  (connect Argo CD to this repo, Applications with prune off and self-heal on) is not
  done yet. Until then, deploys are manual with --context homelab-rw and my approval.
- Existing apps selfhealing-demo and wealth-demo use the default Argo project. Do not
  touch their Applications.
- Known issues, not yours to fix unless asked: argocd-applicationset-controller is
  crash-looping, and oom-demo in selfhealing-demo crashes by design.

## Memory across sessions
- CLAUDE.md holds permanent facts and rules; notes/ holds what happened. Run /handoff
  before a long session ends and /pickup <topic> at the start of the next. Never put
  secrets in either.

## Things I do myself, not you
Delete or edit Secrets; change RBAC, admission policies, the firewall, or tokens; restart
k3s; run helm upgrade; drain nodes; delete things in the Dynatrace tenant; merge PRs; log
in to dtctl or gh; edit settings.json or the guard hook; read backups. When a task needs
one of these, print the exact command, explain it, and stop.
