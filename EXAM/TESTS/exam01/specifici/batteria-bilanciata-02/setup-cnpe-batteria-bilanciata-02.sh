#!/usr/bin/env bash
set -euo pipefail
PROFILE="cnpe-bilanciata-02"
K8S_VERSION="v1.35.0"
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_API="${GITEA_URL%/}/api/v1"
GITEA_OWNER=""
for c in minikube kubectl helm git docker curl; do command -v "$c" >/dev/null 2>&1 || { echo "[ERR] missing command: $c"; exit 1; }; done

seed_git_repo_to_gitea() {
  local repo_path="$1"
  local repo_name="$2"
  local commit_message="$3"
  local status post_status push_base push_url

  git -C "$repo_path" init -b main >/dev/null 2>&1 || true
  git -C "$repo_path" config user.name "CNPE Setup"
  git -C "$repo_path" config user.email "cnpe-setup@example.local"
  git -C "$repo_path" add . >/dev/null 2>&1 || true
  git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true

  if [[ -z "$GITEA_OWNER" ]]; then
    GITEA_OWNER="$(curl -fsS -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
  fi
  [[ -n "$GITEA_OWNER" ]] || return 0

  status="$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/repos/$GITEA_OWNER/$repo_name" || true)"
  if [[ "$status" != "200" ]]; then
    post_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"$repo_name\",\"private\":false,\"auto_init\":false}" "$GITEA_API/user/repos" || true)"
    [[ "$post_status" == "201" || "$post_status" == "409" ]] || return 0
  fi

  push_base="${GITEA_URL%/}"
  push_url="${push_base/\/\//\/\/$GITEA_OWNER:$GITEA_TOKEN@}/$GITEA_OWNER/$repo_name.git"
  git -C "$repo_path" remote remove origin >/dev/null 2>&1 || true
  git -C "$repo_path" remote add origin "$push_url" >/dev/null 2>&1 || true
  git -C "$repo_path" push -u origin main --force >/dev/null 2>&1 || true
}
if mkdir -p /course >/dev/null 2>&1; then COURSE_ROOT="/course"; else COURSE_ROOT="$HOME/course"; mkdir -p "$COURSE_ROOT"; fi
for i in $(seq 1 15); do mkdir -p "$COURSE_ROOT/$i"; done
echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=10240 --addons=ingress,metrics-server
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null
for ns in argocd flux-system kyverno ns-b02-app ns-b02-sec ns-b02-team team-b02; do kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; done
kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null 2>&1 || true
kubectl create -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1 || true
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --wait --timeout=600s >/dev/null 2>&1 || true
kubectl create -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml >/dev/null 2>&1 || true
mkdir -p "$COURSE_ROOT/1/repo-gitops/manifests/base"
cat > "$COURSE_ROOT/1/repo-gitops/manifests/base/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
YAML
cat > "$COURSE_ROOT/1/repo-gitops/manifests/base/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b02
  namespace: ns-b02-app
spec:
  replicas: 2
  selector: {matchLabels: {app: app-b02}}
  template:
    metadata: {labels: {app: app-b02}}
    spec:
      containers:
      - name: app
        image: nginx:1.25
YAML
seed_git_repo_to_gitea "$COURSE_ROOT/1/repo-gitops" "cnpe-bilanciata-02-repo-gitops" "init"
echo "[OK] Batteria bilanciata 02 pronta"
