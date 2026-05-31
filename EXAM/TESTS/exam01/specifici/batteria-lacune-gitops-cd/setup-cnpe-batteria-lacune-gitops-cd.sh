#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-lacune-gitops"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

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

minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=8192 --addons=ingress,metrics-server
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns flux-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns ns-gc-app --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns rollouts-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null 2>&1 || warn "Argo CD install failed"
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "Flux install failed"
kubectl apply -n rollouts-lab -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null 2>&1 || true

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

(cd "$COURSE_ROOT/2/repo-gitops" && git init -b main >/dev/null 2>&1 && git add . && git commit -m "init gitops repo" >/dev/null 2>&1)

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
(cd "$COURSE_ROOT/5/repo-flux" && git init -b main >/dev/null 2>&1 && git add . && git commit -m "init flux repo" >/dev/null 2>&1)

ok "Setup GitOps/CD lacune pronto"
echo "Course root: $COURSE_ROOT"
