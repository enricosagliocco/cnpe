#!/usr/bin/env bash
# =============================================================================
# CNPE Batteria 02 - Minikube Setup Script
# Kubernetes 1.35 | CLI-first lab bootstrap for Domains & Competencies
# =============================================================================
# Prerequisites: minikube, kubectl, helm, git, curl, jq, docker
#
# Usage:
#   chmod +x setup-cnpe-batteria-02.sh
#   ./setup-cnpe-batteria-02.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Command '$1' not found"
  log "Found $1"
}

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

section "Checking prerequisites"
check_cmd minikube
check_cmd kubectl
check_cmd helm
check_cmd git
check_cmd curl
check_cmd jq
check_cmd docker

K8S_VERSION="v1.35.0"
PROFILE="cnpe-b2"

# Try to use /course to match simulator paths; fallback to $HOME/course.
if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using $COURSE_ROOT"
fi

section "Starting Minikube profile ${PROFILE}"
info "Resetting Minikube profile ${PROFILE} (delete + recreate)"
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=18432 \
  --disk-size=20g \
  --addons=ingress,metrics-server
log "Minikube started"

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s
log "Cluster is ready"

section "Adding Helm repos"
add_helm_repo() {
  local name="$1"
  local url="$2"
  if helm repo add "$name" "$url" >/dev/null 2>&1; then
    log "Helm repo added: $name"
  else
    warn "Helm repo not added/updated: $name ($url)"
  fi
}

add_helm_repo prometheus https://prometheus-community.github.io/helm-charts
add_helm_repo grafana https://grafana.github.io/helm-charts
add_helm_repo argo https://argoproj.github.io/argo-helm
add_helm_repo kyverno https://kyverno.github.io/kyverno
add_helm_repo crossplane https://charts.crossplane.io/stable
helm repo update >/dev/null
log "Helm repos updated"

section "Namespaces"
NAMESPACES=(
  tenant-a tenant-b tenant-c market shared-apps
  flux-system argocd builder checkout
  dev-platform platform-ops team-lake
  monitor retail tracing ops-lab
  secure-mesh finance payment-staging
)

for ns in "${NAMESPACES[@]}"; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  log "Namespace ready: $ns"
done

section "Core platform components"

# Prometheus stack for Q14 and metrics support.
helm upgrade --install kube-prom-stack prometheus/kube-prometheus-stack \
  --namespace monitor \
  --set grafana.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --wait --timeout=600s >/dev/null 2>&1 || warn "kube-prometheus-stack install failed"

kubectl -n monitor delete daemonset kube-prom-stack-prometheus-node-exporter --ignore-not-found >/dev/null 2>&1 || true

# Loki + Grafana for Q15.
helm upgrade --install loki grafana/loki \
  --namespace monitor \
  --set loki.auth_enabled=false \
  --wait --timeout=600s >/dev/null 2>&1 || warn "Loki install failed"

helm upgrade --install grafana grafana/grafana \
  --namespace monitor \
  --set adminPassword=admin \
  --set service.type=ClusterIP \
  --set datasources."datasources\\.yaml".apiVersion=1 \
  --set datasources."datasources\\.yaml".datasources[0].name=Loki \
  --set datasources."datasources\\.yaml".datasources[0].type=loki \
  --set datasources."datasources\\.yaml".datasources[0].url=http://loki.monitor:3100 \
  --set datasources."datasources\\.yaml".datasources[0].access=proxy \
  --set datasources."datasources\\.yaml".datasources[0].isDefault=true \
  --wait --timeout=600s >/dev/null 2>&1 || warn "Grafana install failed"

# Argo CD for Q5.
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set configs.params."server\\.insecure"=true \
  --set server.service.type=ClusterIP \
  --set applicationSet.enabled=true \
  --set applicationSet.extraArgs[0]=--policy=create-update \
  --set applicationSet.extraArgs[1]=--dry-run=false \
  --wait --timeout=600s >/dev/null 2>&1 || warn "Argo CD install failed"

# Tekton for Q6.
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml >/dev/null 2>&1 || warn "Tekton pipeline install failed"

# Argo Rollouts for Q7.
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "Argo Rollouts install failed"

# Argo Workflows for Q11.
kubectl create namespace argo-workflows --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "Argo Workflows install failed"

# Kyverno for Q19.
helm upgrade --install kyverno kyverno/kyverno --namespace finance --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "Kyverno install failed"

# Crossplane for Q12.
helm upgrade --install crossplane crossplane/crossplane --namespace crossplane-system --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "Crossplane install failed"

log "Core components attempted"

section "Question-specific base resources"

# Q1 baseline namespaces already created.

# Q2 market deployments with intentionally rough CPU requests for right-sizing.
kubectl apply -n market -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: market-api
  template:
    metadata:
      labels:
        app: market-api
    spec:
      containers:
      - name: api
        image: nginx:1.25
        resources:
          requests:
            cpu: "500m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "512Mi"
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: market-worker
  template:
    metadata:
      labels:
        app: market-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo worker; sleep 3; done"]
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
EOF

# Q3 shared-apps topology.
kubectl apply -n shared-apps -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: app
        image: postgres:16
        env:
        - name: POSTGRES_PASSWORD
          value: demo1234
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Q6 Tekton skeleton pipeline.
kubectl apply -n builder -f - <<'EOF'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: lint
spec:
  steps:
  - name: run-lint
    image: alpine:3.20
    script: |
      echo "lint ok"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build
spec:
  steps:
  - name: run-build
    image: alpine:3.20
    script: |
      echo "build ok"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: image-scan
spec:
  steps:
  - name: run-scan
    image: alpine:3.20
    script: |
      echo "scan ok"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: deploy
spec:
  steps:
  - name: run-deploy
    image: alpine:3.20
    script: |
      echo "deploy ok"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ci-service
spec:
  tasks:
  - name: build
    taskRef:
      name: build
  - name: deploy
    runAfter: [build]
    taskRef:
      name: deploy
EOF

# Q7 rollout baseline (intentionally incomplete steps).
kubectl create namespace checkout --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n checkout -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
  strategy:
    canary:
      canaryService: web-canary
      stableService: web-stable
      steps:
      - setWeight: 20
      - pause: {}
---
apiVersion: v1
kind: Service
metadata:
  name: web-canary
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-stable
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
EOF

# Q14/Q15 log workload in retail for alerts + Loki query.
kubectl apply -n retail -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: retail-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: retail-api
  template:
    metadata:
      labels:
        app: retail-api
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo ERROR request failed; sleep 2; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: retail-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: retail-worker
  template:
    metadata:
      labels:
        app: retail-worker
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo ERROR worker timeout; sleep 3; done"]
EOF

# Q17 failing app for incident remediation.
kubectl apply -n ops-lab -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crashy-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crashy-app
  template:
    metadata:
      labels:
        app: crashy-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
EOF

# Q18 secure-mesh sample apps.
kubectl apply -n secure-mesh -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: curlimages/curl:8.8.0
        command: ["sh", "-c", "sleep 36000"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF

# Q19 baseline namespace only.

section "Preparing /course content"

for i in $(seq 1 20); do
  mkdir -p "$COURSE_ROOT/$i"
  log "Prepared $COURSE_ROOT/$i"
done

# Q4 Flux local git scaffold.
mkdir -p "$COURSE_ROOT/4/team-red/base"
cat > "$COURSE_ROOT/4/team-red/base/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-red-app
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels:
      app: team-red-app
  template:
    metadata:
      labels:
        app: team-red-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
cat > "$COURSE_ROOT/4/team-red/kustomization.yaml" <<'EOF'
resources:
- base/deploy.yaml
EOF

# Q5 Argo app git scaffold.
mkdir -p "$COURSE_ROOT/5/payment-app/manifests"
cat > "$COURSE_ROOT/5/payment-app/manifests/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: payment-staging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
        version: v1
    spec:
      containers:
      - name: api
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-api-content
  namespace: payment-staging
data:
  index.html: "Payment API Staging v1"
EOF
(
  cd "$COURSE_ROOT/5/payment-app"
  git init -b main >/dev/null 2>&1 || true
  git config user.email "student@cnpe.local" >/dev/null 2>&1 || true
  git config user.name "student" >/dev/null 2>&1 || true
  git add .
  git commit -m "init payment app" >/dev/null 2>&1 || true
  git branch staging >/dev/null 2>&1 || true
)

# Q8 Kustomize base + overlays.
mkdir -p "$COURSE_ROOT/8/app-config/base"
mkdir -p "$COURSE_ROOT/8/app-config/overlays/dev"
mkdir -p "$COURSE_ROOT/8/app-config/overlays/prod"

cat > "$COURSE_ROOT/8/app-config/base/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-config-demo
  template:
    metadata:
      labels:
        app: app-config-demo
    spec:
      containers:
      - name: app
        image: nginx:1.25
        env:
        - name: BASE_VAR
          value: "on"
EOF

cat > "$COURSE_ROOT/8/app-config/base/kustomization.yaml" <<'EOF'
resources:
- deploy.yaml
EOF

cat > "$COURSE_ROOT/8/app-config/overlays/dev/kustomization.yaml" <<'EOF'
resources:
- ../../base
namespace: market
EOF

cat > "$COURSE_ROOT/8/app-config/overlays/prod/kustomization.yaml" <<'EOF'
resources:
- ../../base
namespace: market
patches:
- target:
    kind: Deployment
    name: app-config-demo
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
EOF

# Q9 CRD skeleton.
cat > "$COURSE_ROOT/9/appenvironment-crd.yaml" <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: appenvironments.platform.example.io
spec:
  group: platform.example.io
  names:
    plural: appenvironments
    singular: appenvironment
    kind: AppEnvironment
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              team:
                type: string
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              team:
                type: string
              size:
                type: string
                enum: [small, medium, large]
              owner:
                type: string
EOF

# Q10 operator-like CRD + sample controller target workload.
cat > "$COURSE_ROOT/10/databaseclaim.yaml" <<'EOF'
apiVersion: platform.example.io/v1alpha1
kind: DatabaseClaim
metadata:
  name: db-team1
  namespace: platform-ops
spec:
  engine: postgres
  size: small
  storage: 5Gi
EOF

# Q11 workflow template partial.
cat > "$COURSE_ROOT/11/workflowtemplate.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-bootstrap
  namespace: argo-workflows
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: namespace
      value: default
  templates:
  - name: main
    steps:
    - - name: create-configmap
        template: create-configmap
  - name: create-configmap
    resource:
      action: create
      manifest: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: app-cm
          namespace: {{workflow.parameters.namespace}}
        data:
          key: value
EOF

# Q12 composition skeleton.
cat > "$COURSE_ROOT/12/composition.yaml" <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: app-runtime
spec:
  compositeTypeRef:
    apiVersion: platform.example.io/v1alpha1
    kind: RuntimeClaim
  resources:
  - name: workload
    base:
      apiVersion: apps/v1
      kind: Deployment
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: runtime
        template:
          metadata:
            labels:
              app: runtime
          spec:
            containers:
            - name: app
              image: nginx:1.25
              ports:
              - containerPort: 8080
EOF

# Q13 tofu scaffolds.
mkdir -p "$COURSE_ROOT/13/service-a" "$COURSE_ROOT/13/service-b" "$COURSE_ROOT/13/service-c"

cat > "$COURSE_ROOT/13/service-a/main.tf" <<'EOF'
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_namespace" "service_a" {
  metadata { name = "service-a" }
}
EOF

cat > "$COURSE_ROOT/13/service-b/main.tf" <<'EOF'
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "service_b" {
  metadata {
    name = "service-b"
    namespace = "market"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "service-b" }
    }
    template {
      metadata { labels = { app = "service-b" } }
      spec {
        container {
          name = "app"
          image = "nginx:1.25"
        }
      }
    }
  }
}
EOF

cat > "$COURSE_ROOT/13/service-c/main.tf" <<'EOF'
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "service_c" {
  metadata {
    name = "service-c"
    namespace = "market"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "service-c" }
    }
    template {
      metadata { labels = { app = "service-c" } }
      spec {
        container {
          name = "app"
          image = "nginx:1.25"
          port { container_port = 8080 }
        }
      }
    }
  }
}
EOF

# Q14 PrometheusRule skeleton.
cat > "$COURSE_ROOT/14/high5xx-rule.yaml" <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: retail-alerts
  namespace: monitor
spec:
  groups:
  - name: retail.rules
    rules:
    - alert: High5xxRate
      expr: sum(rate(http_requests_total{namespace="retail",status=~"5.."}[2m])) > 5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: high 5xx rate in retail
EOF

# Q16 trace export target placeholder.
cat > "$COURSE_ROOT/16/README.txt" <<'EOF'
Export 10 traces from service checkout to:
/course/16/checkout-traces.json
(or fallback path if /course is not writable)
EOF

# Q17 incident template.
cat > "$COURSE_ROOT/17/incident-report.md" <<'EOF'
# Incident Report

## Impact

## Root Cause

## Fix Applied

## Prevention
EOF

# Q19 test output file placeholder.
cat > "$COURSE_ROOT/19/kyverno-tests.txt" <<'EOF'
Run admission tests and collect outputs here.
EOF

# Q20 artifacts scaffold.
mkdir -p "$COURSE_ROOT/20/artifacts"
cat > "$COURSE_ROOT/20/compliance-result.txt" <<'EOF'
PENDING
EOF

section "Done"
SERVICE_HOST="0.0.0.0"

echo "Profile: $PROFILE"
echo "Kubernetes: $K8S_VERSION"
echo "Course root: $COURSE_ROOT"
echo ""
echo "Useful endpoints (if components started):"
echo "- Argo CD: http://$SERVICE_HOST:32030"
echo "- Grafana: http://$SERVICE_HOST:32080 (admin/admin)"
echo "- Rollout demo service: http://$SERVICE_HOST:32161"
echo ""
echo "Quick checks:"
echo "- kubectl get pods -A"
echo "- kubectl get ns"
echo "- ls -la $COURSE_ROOT"

echo ""
echo "=== BEGIN_EXERCISE_ENDPOINT_SUMMARY ==="
echo "Endpoint e credenziali per esercizio (Batteria 02)"
echo "- Q1  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q2  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q3  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q4  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q5  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q6  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q7  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q8  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q9  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q10 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q11 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q12 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q13 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q14 | Endpoint: http://0.0.0.0:32080                    | Credenziali: admin/admin"
echo "- Q15 | Endpoint: http://0.0.0.0:32080                    | Credenziali: admin/admin"
echo "- Q16 | Endpoint: http://0.0.0.0:32161                    | Credenziali: n/a"
echo "- Q17 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q18 | Endpoint: http://0.0.0.0:32030                    | Credenziali: admin/admin"
echo "- Q19 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q20 | Endpoint: n/a                                      | Credenziali: n/a"
echo "=== END_EXERCISE_ENDPOINT_SUMMARY ==="

echo ""
echo ""
echo "=== BEGIN_SERVICE_PORT_FORWARD ==="
echo "Port-forward servizi necessari su 0.0.0.0"

PF_DIR="/tmp/cnpe/port-forward"
mkdir -p "$PF_DIR"
forward_count=0

start_pf() {
  local ns="$1"
  local svc="$2"
  local local_port="$3"
  local remote_port="$4"

  kubectl -n "$ns" get svc "$svc" >/dev/null 2>&1 || return 0

  if pgrep -f "kubectl -n $ns port-forward svc/$svc $local_port:$remote_port --address=0.0.0.0" >/dev/null 2>&1; then
    return 0
  fi

  local log_file="$PF_DIR/${ns}__${svc}__${local_port}.log"
  kubectl -n "$ns" port-forward "svc/$svc" "$local_port:$remote_port" --address=0.0.0.0 >"$log_file" 2>&1 &
  sleep 0.3

  if pgrep -f "kubectl -n $ns port-forward svc/$svc $local_port:$remote_port --address=0.0.0.0" >/dev/null 2>&1; then
    forward_count=$((forward_count + 1))
  fi
}

# Batteria 01 endpoints
start_pf prometheus prometheus-server 30020 80
start_pf argocd argocd-server 30030 80
start_pf malawi app1-expose 30041 80
start_pf malawi app2-expose 30042 80
start_pf opencost opencost 30070 9003
start_pf opencost prometheus-opencost-server 30077 80
start_pf grafana grafana 30080 80
start_pf argo-workflows argo-server 30110 2746
start_pf tekton-dashboard tekton-dashboard 30120 9097
start_pf argo-rollouts argo-rollouts-dashboard 30160 3100
start_pf baltic webapp-stable 30161 80
start_pf eyre jaeger-query 30014 16686

# Batteria 02 endpoints
start_pf argocd argocd-server 32030 80
start_pf monitor grafana 32080 80
start_pf retail web-stable 32161 80

echo "Port-forward attivi creati: $forward_count"
echo "Log port-forward: $PF_DIR"
echo "=== END_SERVICE_PORT_FORWARD ==="
