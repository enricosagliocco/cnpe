#!/usr/bin/env bash
# =============================================================================
# CNPE Hard Lab — Argo Rollouts
# Scenario: argo-rollouts-hard
#
# Focus:
#   - Rollout canary
#   - pause/promote/abort
#   - AnalysisTemplate/AnalysisRun
#   - Service selectors stable/canary
#   - traffic-free canary basics
#   - rollback/undo
#
# Uso:
#   chmod +x setup-argo-rollouts-hard.sh
#   ./setup-argo-rollouts-hard.sh
#   ./setup-argo-rollouts-hard.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-argo-rollouts-hard}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-10000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

ROLL_NS="argo-rollouts"
LAB_NS="rollouts-lab"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/argo-rollouts-hard}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$LAB_NS" "$ROLL_NS" --ignore-not-found --timeout=180s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl curl; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --driver="$DRIVER" --cpus="$CPUS" --memory="${MEMORY}mb" --disk-size=45g --kubernetes-version="$K8S_VERSION" --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

info "install Argo Rollouts"
kubectl create ns "$ROLL_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$ROLL_NS" -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n "$ROLL_NS" wait --for=condition=Available deployment --all --timeout=300s

kubectl create ns "$LAB_NS" --dry-run=client -o yaml | kubectl apply -f -

cat > "$LAB_DIR/00-services.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  type: NodePort
  selector:
    app: payments
    # BUG: manca rollouts-pod-template-hash stabile; il service non è gestito correttamente dal rollout
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
---
apiVersion: v1
kind: Service
metadata:
  name: payments-stable
  namespace: rollouts-lab
spec:
  selector:
    app: payments
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payments-canary
  namespace: rollouts-lab
spec:
  selector:
    app: payments
  ports:
  - port: 80
    targetPort: 80
YAML

cat > "$LAB_DIR/10-analysis-broken.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-check
  namespace: rollouts-lab
spec:
  args:
  - name: service-name
  metrics:
  - name: web-check
    interval: 5s
    count: 2
    successCondition: result == "ok"
    provider:
      job:
        spec:
          template:
            spec:
              restartPolicy: Never
              containers:
              - name: check
                image: curlimages/curl:8.8.0
                command: [sh, -c]
                args:
                # BUG: service-name non usato davvero, e output non è "ok"
                - |
                  curl -sS http://payments-canary.rollouts-lab/ >/dev/null
                  echo passed
YAML

cat > "$LAB_DIR/20-rollout-broken.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: payments
  strategy:
    canary:
      stableService: payments-stable
      canaryService: payments-canary
      steps:
      - setWeight: 25
      - pause: {}
      - analysis:
          templates:
          - templateName: success-rate-check
          args:
          - name: service-name
            value: payments-canary
      - setWeight: 50
      # BUG: manca secondo pause prima del 100
      - setWeight: 100
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        lifecycle:
          postStart:
            exec:
              command:
              - sh
              - -c
              - echo "payments v1" > /usr/share/nginx/html/index.html
YAML

cat > "$LAB_DIR/30-bad-update.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: payments
  strategy:
    canary:
      stableService: payments-stable
      canaryService: payments-canary
      steps:
      - setWeight: 25
      - pause: {}
      - analysis:
          templates:
          - templateName: success-rate-check
          args:
          - name: service-name
            value: payments-canary
      - setWeight: 50
      - pause: {}
      - setWeight: 100
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: web
        image: nginx:bad-tag
        ports:
        - containerPort: 80
YAML

cat > "$LAB_DIR/40-good-update.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: payments
  strategy:
    canary:
      stableService: payments-stable
      canaryService: payments-canary
      steps:
      - setWeight: 25
      - pause: {}
      - analysis:
          templates:
          - templateName: success-rate-check
          args:
          - name: service-name
            value: payments-canary
      - setWeight: 50
      - pause: {}
      - setWeight: 100
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: web
        image: nginx:1.28-alpine
        ports:
        - containerPort: 80
        lifecycle:
          postStart:
            exec:
              command:
              - sh
              - -c
              - echo "payments v2" > /usr/share/nginx/html/index.html
YAML

kubectl apply -f "$LAB_DIR/00-services.yaml"
kubectl apply -f "$LAB_DIR/10-analysis-broken.yaml"
kubectl apply -f "$LAB_DIR/20-rollout-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Scenario: argo-rollouts-hard
Namespace Rollouts controller: argo-rollouts
Namespace lab: rollouts-lab

NodePort:
  http://$(minikube -p "$PROFILE" ip 2>/dev/null):30090

File:
  /course/argo-rollouts-hard/00-services.yaml
  /course/argo-rollouts-hard/10-analysis-broken.yaml
  /course/argo-rollouts-hard/20-rollout-broken.yaml
  /course/argo-rollouts-hard/30-bad-update.yaml
  /course/argo-rollouts-hard/40-good-update.yaml
EOF

kubectl -n "$LAB_NS" get rollout,analysistemplate,svc,pod
ok "Argo Rollouts hard lab pronto: $LAB_DIR"
