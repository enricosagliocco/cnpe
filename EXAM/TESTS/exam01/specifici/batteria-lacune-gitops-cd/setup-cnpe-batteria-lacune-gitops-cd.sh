#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-lacune-gitops"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }

apply_manifest_from_url() {
  local name="$1"
  local namespace="$2"
  local url="$3"
  local attempts="${4:-4}"
  local i tmp_file

  tmp_file="$(mktemp)"
  for i in $(seq 1 "$attempts"); do
    if curl -fsSL --retry 3 --retry-all-errors --connect-timeout 15 --max-time 180 "$url" -o "$tmp_file"; then
      if [[ -n "$namespace" ]]; then
        if kubectl apply -n "$namespace" -f "$tmp_file"; then
          ok "$name installed"
          rm -f "$tmp_file"
          return 0
        fi
      else
        if kubectl apply -f "$tmp_file"; then
          ok "$name installed"
          rm -f "$tmp_file"
          return 0
        fi
      fi
    fi

    warn "$name install attempt $i/$attempts failed"
    sleep $((i * 2))
  done

  rm -f "$tmp_file"
  warn "$name install failed after $attempts attempts"
  return 1
}

init_local_git_repo() {
  local repo_path="$1"
  local commit_message="$2"

  git -C "$repo_path" init -b main >/dev/null 2>&1
  git -C "$repo_path" config user.name "CNPE Setup"
  git -C "$repo_path" config user.email "cnpe-setup@example.local"
  git -C "$repo_path" add .
  git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true
}

for c in minikube kubectl git docker; do
  command -v "$c" >/dev/null 2>&1 || { echo "[ERR] missing command: $c"; exit 1; }
done

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using $COURSE_ROOT"
fi

for i in $(seq 1 12); do
  mkdir -p "$COURSE_ROOT/$i"
done

info "Deleting previous minikube profile (if present): $PROFILE"
echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" || true
info "Starting minikube profile: $PROFILE"
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=8192 --addons=ingress,metrics-server
info "Waiting for node readiness"
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

info "Creating namespaces"
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns flux-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns ns-gc-app --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns rollouts-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

apply_manifest_from_url "Argo CD" "argocd" "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" || true
apply_manifest_from_url "Flux" "" "https://github.com/fluxcd/flux2/releases/latest/download/install.yaml" || true
apply_manifest_from_url "Argo Rollouts" "rollouts-lab" "https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml" || true

mkdir -p "$COURSE_ROOT/2/repo-gitops/manifests/base"
cat > "$COURSE_ROOT/2/repo-gitops/manifests/base/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-gc02
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-gc02
  template:
    metadata:
      labels:
        app: app-gc02
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML
cat > "$COURSE_ROOT/2/repo-gitops/manifests/base/svc.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: app-gc02
spec:
  selector:
    app: app-gc02
  ports:
  - port: 80
    targetPort: 80
YAML

init_local_git_repo "$COURSE_ROOT/2/repo-gitops" "init gitops repo"

mkdir -p "$COURSE_ROOT/5/repo-flux/overlays/dev"
cat > "$COURSE_ROOT/5/repo-flux/overlays/dev/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
YAML
cat > "$COURSE_ROOT/5/repo-flux/overlays/dev/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flux-dev-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flux-dev-app
  template:
    metadata:
      labels:
        app: flux-dev-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
YAML
init_local_git_repo "$COURSE_ROOT/5/repo-flux" "init flux repo"

ok "Setup GitOps/CD lacune pronto"
echo "Course root: $COURSE_ROOT"
