#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-argo-rollouts"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

install_rollouts_cli() {
  local version os arch tmpdir asset dest

  if kubectl argo rollouts version >/dev/null 2>&1; then
    return 0
  fi

  version="$(curl -fsSL https://api.github.com/repos/argoproj/argo-rollouts/releases/latest | jq -r '.tag_name' 2>/dev/null || true)"
  if [[ -z "$version" || "$version" == "null" ]]; then
    warn "Unable to determine latest Argo Rollouts CLI version"
    return 1
  fi

  os="$(uname | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      warn "Unsupported architecture for Argo Rollouts CLI: $arch"
      return 1
      ;;
  esac

  asset="kubectl-argo-rollouts-${os}-${arch}"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  if ! curl -fsSL -o "$tmpdir/kubectl-argo-rollouts" "https://github.com/argoproj/argo-rollouts/releases/download/${version}/${asset}"; then
    warn "Failed to download Argo Rollouts CLI"
    return 1
  fi

  chmod +x "$tmpdir/kubectl-argo-rollouts"

  if [[ -w /usr/local/bin ]]; then
    dest="/usr/local/bin/kubectl-argo-rollouts"
  else
    mkdir -p "$HOME/.local/bin"
    dest="$HOME/.local/bin/kubectl-argo-rollouts"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
  fi

  mv "$tmpdir/kubectl-argo-rollouts" "$dest"

  if ! kubectl argo rollouts version >/dev/null 2>&1; then
    warn "Argo Rollouts CLI installed but plugin is still not callable"
    return 1
  fi
}

for c in minikube kubectl curl jq docker; do
  command -v "$c" >/dev/null 2>&1 || { echo "[ERR] missing command: $c"; exit 1; }
done

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using $COURSE_ROOT"
fi

for i in $(seq 1 20); do
  mkdir -p "$COURSE_ROOT/$i"
done

minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=12288 \
  --disk-size=20g \
  --addons=ingress,metrics-server

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace rollouts-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=180s >/dev/null || warn "argo-rollouts controller not ready yet"
install_rollouts_cli || warn "Argo Rollouts CLI install failed"

cat > "$COURSE_ROOT/2/webapp-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: rollouts-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML

cat > "$COURSE_ROOT/5/analysis-template-job.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-job
  namespace: rollouts-lab
spec:
  metrics:
  - name: smoke-check
    successCondition: result == 0
    provider:
      job:
        spec:
          backoffLimit: 0
          template:
            spec:
              restartPolicy: Never
              containers:
              - name: smoke
                image: busybox:1.36
                command: ["sh", "-c", "exit 0"]
YAML

cat > "$COURSE_ROOT/README-argo-rollouts.txt" <<'TXT'
CNPE Argo Rollouts - Setup rapido

Namespace laboratorio: rollouts-lab
Controller namespace: argo-rollouts

Starter files:
- /course/2/webapp-deployment.yaml
- /course/5/analysis-template-job.yaml

Rollout creati di base:
- payments (canary)
- checkout (blueGreen)
- inventory (canary)
- search (canary)
- stuck-app (canary con immagine volutamente non valida)
TXT

kubectl -n rollouts-lab apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: payments-stable
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
spec:
  selector:
    app: payments
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
  strategy:
    canary:
      canaryService: payments-canary
      stableService: payments-stable
      maxSurge: 1
      maxUnavailable: 0
      steps:
      - setWeight: 20
      - pause:
          duration: 10s
      - setWeight: 50
      - pause:
          duration: 10s
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-active
spec:
  selector:
    app: checkout
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-preview
spec:
  selector:
    app: checkout
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: checkout
spec:
  replicas: 2
  selector:
    matchLabels:
      app: checkout
  template:
    metadata:
      labels:
        app: checkout
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
  strategy:
    blueGreen:
      activeService: checkout-active
      previewService: checkout-preview
      autoPromotionEnabled: false
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: inventory
spec:
  replicas: 2
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
      - setWeight: 25
      - pause:
          duration: 10s
      - setWeight: 50
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: search
spec:
  replicas: 2
  selector:
    matchLabels:
      app: search
  template:
    metadata:
      labels:
        app: search
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
      - setWeight: 20
      - pause:
          duration: 10s
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: stuck-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stuck-app
  template:
    metadata:
      labels:
        app: stuck-app
    spec:
      containers:
      - name: app
        image: nginx:not-a-real-tag
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
YAML

kubectl -n rollouts-lab autoscale rollout search --cpu-percent=70 --min=1 --max=5 >/dev/null 2>&1 || warn "HPA for rollout search not created"

ok "Batteria Argo Rollouts pronta"
echo "Course root: $COURSE_ROOT"
echo "Profile: $PROFILE"
