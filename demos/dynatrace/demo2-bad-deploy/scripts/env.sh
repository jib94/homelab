# Shared settings for Demo 2 scripts (sourced). Override via environment.
export GH_USER="${GH_USER:-jib94}"
export GH_REPO="${GH_REPO:-payments-demo-gitops}"
export GITOPS_DIR="${GITOPS_DIR:-$HOME/src/$GH_REPO}"   # local clone of the demo repo (outside the homelab repo)
export KUBE_CONTEXT="${KUBE_CONTEXT:-homelab-ro}"        # reads only; rearm/deploy use homelab-rw explicitly
export NS=payments-demo
export BAD_TAG="nginx:1.27-doesnotexist"
export GOOD_TAG="nginx:1.27"
export DEMO_EMAIL="${DEMO_EMAIL:-jordanbanuelos94@gmail.com}"
export WF_TITLE="Bad deploy - open the fix"
ok()  { printf '\033[32mOK  \033[0m %s\n' "$*"; }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$*"; FAILED=1; }
