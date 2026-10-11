# Shared settings for Demo 2 scripts (sourced). Override via environment.
# Argo CD watches branch demo2-live of the homelab repo (never main). rearm.sh only ever pushes to demo2-live and the fix branch.
export GH_USER="${GH_USER:-jib94}"
export GH_REPO="${GH_REPO:-homelab}"
export LIVE_BRANCH=demo2-live
export FIX_BRANCH=claude/fix-revert-bad-tag
export APP_FILE=demos/dynatrace/demo2-bad-deploy/gitops-repo/apps/settlement-service/deployment.yaml
export GITOPS_DIR="${GITOPS_DIR:-$HOME/src/homelab-demo2}"   # separate clone, so the working checkout is never disturbed
export KUBE_CONTEXT="${KUBE_CONTEXT:-homelab-ro}"            # reads only
export NS=payments-demo
export BAD_TAG="nginx:1.27-doesnotexist"
export GOOD_TAG="nginx:1.27"
export DEMO_EMAIL="${DEMO_EMAIL:-jordanbanuelos94@gmail.com}"
export WF_TITLE="Bad deploy - open the fix"
ok()  { printf '\033[32mOK  \033[0m %s\n' "$*"; }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$*"; FAILED=1; }
