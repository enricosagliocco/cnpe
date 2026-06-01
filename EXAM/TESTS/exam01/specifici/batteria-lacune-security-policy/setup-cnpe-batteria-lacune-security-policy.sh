#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-lacune-security"
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

echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start --profile="$PROFILE" --kubernetes-version="$K8S_VERSION" --driver=docker --cpus=4 --memory=8192
kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

kubectl create ns kyverno --dry-run=client -o yaml | kubectl apply -f - >/dev/null
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "Kyverno install failed"

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml >/dev/null 2>&1 || warn "Gatekeeper install failed"

for ns in ns-sp01 ns-sp02 ns-sp03 ns-sp04 ns-sp05 ns-sp06 ns-sp07 ns-sp08 ns-sp09 ns-sp10 ns-sp11; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$ns" create deploy "app-${ns}" --image=nginx:1.25 >/dev/null 2>&1 || true
done

ok "Setup Security/Policy lacune pronto"
echo "Course root: $COURSE_ROOT"
