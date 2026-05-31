#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-lacune-platform"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

for c in minikube kubectl helm docker; do
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
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=8192
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

kubectl create ns team-a --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns team-b --dry-run=client -o yaml | kubectl apply -f - >/dev/null

helm repo add crossplane https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install crossplane crossplane/crossplane -n crossplane-system --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "Crossplane install failed"

kubectl -n team-a create deploy payments --image=nginx:1.25 >/dev/null 2>&1 || true
kubectl -n team-a expose deploy payments --port=80 --target-port=80 >/dev/null 2>&1 || true

cat > "$COURSE_ROOT/8/README-golden-path.txt" <<'TXT'
Crea in questa domanda un bundle riusabile con:
- Deployment
- Service
- HPA
- PodDisruptionBudget
Target applicazione: payments
TXT

ok "Setup Platform API/Self-Service lacune pronto"
echo "Course root: $COURSE_ROOT"
