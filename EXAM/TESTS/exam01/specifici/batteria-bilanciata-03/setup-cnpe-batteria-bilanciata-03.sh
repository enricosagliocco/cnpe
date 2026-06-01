#!/usr/bin/env bash
set -euo pipefail
PROFILE="cnpe-bilanciata-03"
K8S_VERSION="v1.35.0"
for c in minikube kubectl helm git docker; do command -v "$c" >/dev/null 2>&1 || { echo "[ERR] missing command: $c"; exit 1; }; done
if mkdir -p /course >/dev/null 2>&1; then COURSE_ROOT="/course"; else COURSE_ROOT="$HOME/course"; mkdir -p "$COURSE_ROOT"; fi
for i in $(seq 1 15); do mkdir -p "$COURSE_ROOT/$i"; done
echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=10240 --addons=ingress,metrics-server
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null
for ns in argocd flux-system kyverno ns-b03-app ns-b03-sec ns-b03-team team-b03 rollouts-lab; do kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; done
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >/dev/null 2>&1 || true
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1 || true
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 || true
helm repo add crossplane https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --wait --timeout=600s >/dev/null 2>&1 || true
helm upgrade --install crossplane crossplane/crossplane -n crossplane-system --create-namespace --wait --timeout=600s >/dev/null 2>&1 || true
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml >/dev/null 2>&1 || true
mkdir -p "$COURSE_ROOT/1/repo-gitops/manifests/base"
cat > "$COURSE_ROOT/1/repo-gitops/manifests/base/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
YAML
cat > "$COURSE_ROOT/1/repo-gitops/manifests/base/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b03
  namespace: ns-b03-app
spec:
  replicas: 2
  selector: {matchLabels: {app: app-b03}}
  template:
    metadata: {labels: {app: app-b03}}
    spec:
      containers:
      - name: app
        image: nginx:1.25
YAML
(cd "$COURSE_ROOT/1/repo-gitops" && git init -b main >/dev/null 2>&1 && git add . && git commit -m init >/dev/null 2>&1)
echo "[OK] Batteria bilanciata 03 pronta"
