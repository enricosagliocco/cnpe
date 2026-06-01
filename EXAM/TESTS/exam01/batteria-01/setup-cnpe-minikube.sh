#!/usr/bin/env bash
# =============================================================================
# CNPE Killer Shell — Minikube Setup Script
# Kubernetes 1.35 | 4 CPU | 18GB RAM
# =============================================================================
# Prerequisiti: minikube, helm, kubectl, git, curl, jq
#
# Uso:
#   chmod +x setup-cnpe-minikube.sh
#   ./setup-cnpe-minikube.sh
#
# Il cluster emula le 20 domande del CNPE Simulator Killer Shell.
# =============================================================================

set -euo pipefail

# ─── Colori ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✔]${NC} $*"; }
info() { echo -e "${BLUE}[ℹ]${NC} $*"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${NC}\n"; }

# ─── Prerequisiti ─────────────────────────────────────────────────────────────
section "🔍 Verifica prerequisiti"

check_cmd() { command -v "$1" &>/dev/null || err "Comando '$1' non trovato. Installarlo prima."; log "$1 trovato"; }
check_cmd minikube
check_cmd kubectl
check_cmd helm
check_cmd git
check_cmd curl
check_cmd jq
check_cmd docker

MINIKUBE_K8S_VERSION="v1.35.0"
CLUSTER_NAME="cnpe-simulator"

# ─── Avvio Minikube ───────────────────────────────────────────────────────────
section "🚀 Avvio Minikube ($MINIKUBE_K8S_VERSION | 4 CPU | 18GB RAM)"

info "Reset cluster '$CLUSTER_NAME': delete + recreate"
echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$CLUSTER_NAME" >/dev/null 2>&1 || true
minikube start \
  --profile="$CLUSTER_NAME" \
  --kubernetes-version="$MINIKUBE_K8S_VERSION" \
  --cpus=4 \
  --memory=18432 \
  --disk-size=20g \
  --driver=docker \
  --addons=ingress,metrics-server \
  --extra-config=kubelet.max-pods=200
log "Cluster avviato"

kubectl config use-context "$CLUSTER_NAME"

# Aspetta che il cluster sia pronto
info "Attendo che il cluster sia pronto..."
kubectl wait --for=condition=Ready node --all --timeout=120s
log "Cluster pronto"

# ─── Alias & Tool ─────────────────────────────────────────────────────────────
section "🛠️  Tool aggiuntivi"

# kubectl alias
if ! grep -q "alias k=kubectl" ~/.bashrc 2>/dev/null; then
  echo "alias k=kubectl" >> ~/.bashrc
fi

# Helm repos
add_helm_repo() {
  local name="$1"
  local url="$2"
  if helm repo add "$name" "$url" >/dev/null 2>&1; then
    log "Helm repo aggiunto: $name"
  else
    warn "Helm repo non aggiunto/aggiornato: $name ($url)"
  fi
}

add_helm_repo stable          https://charts.helm.sh/stable
add_helm_repo prometheus      https://prometheus-community.github.io/helm-charts
add_helm_repo grafana         https://grafana.github.io/helm-charts
add_helm_repo argo            https://argoproj.github.io/argo-helm
add_helm_repo flagger         https://flagger.app
add_helm_repo gatekeeper      https://open-policy-agent.github.io/gatekeeper/charts
add_helm_repo opencost        https://opencost.github.io/opencost-helm-chart
add_helm_repo tekton-pipeline https://cdfoundation.github.io/tekton-helm-chart
add_helm_repo fluxcd          https://fluxcd-community.github.io/helm-charts
add_helm_repo kyverno         https://kyverno.github.io/kyverno
add_helm_repo crossplane      https://charts.crossplane.io/stable
add_helm_repo linkerd         https://helm.linkerd.io/stable
add_helm_repo jaegertracing   https://jaegertracing.github.io/helm-charts
helm repo update
log "Helm repos aggiornati"

# ─── Namespaces ───────────────────────────────────────────────────────────────
section "📁 Creazione Namespaces"

NAMESPACES=(
  prometheus grafana loki
  argocd argo-workflows argo-rollouts
  flagger
  gatekeeper-system
  opencost
  tekton-pipelines tekton-dashboard
  flux-system
  kyverno
  crossplane-system
  linkerd
  jaeger
  # Namespaces delle domande
  kariba pacific atlantic malawi baikal
  planet-apps ammersee-legacy eyre sargasso
  baltic builder caribbean
  caspian-pipeline1 caspian-pipeline2 caspian-pipeline3
  saltlake-app danau kaw havel-east
  opencost
)

for ns in "${NAMESPACES[@]}"; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
  log "Namespace: $ns"
done

# ─── Q1: CRD, Kustomize, Git ──────────────────────────────────────────────────
section "📦 Q1 — Operator Pattern, CRD, Kustomize, Git"

mkdir -p /tmp/cnpe/1/team-monitoring
cd /tmp/cnpe/1/team-monitoring
git init -b main 2>/dev/null || git init && git checkout -b main 2>/dev/null || true
git config user.email "root@cnpe7683" 2>/dev/null || true
git config user.name "root" 2>/dev/null || true

cat > /tmp/cnpe/1/team-monitoring/crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: teammonitorings.monitoring.killer.sh
spec:
  group: monitoring.killer.sh
  scope: Namespaced
  names:
    kind: TeamMonitoring
    plural: teammonitorings
    singular: teammonitoring
    shortNames:
      - tmon
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          description: TeamMonitoring defines monitoring configuration per team
          properties:
            spec:
              type: object
              properties:
                target:
                  type: string
EOF

cat > /tmp/cnpe/1/team-monitoring/kustomization.yaml << 'EOF'
resources:
  - crd.yaml
EOF

cat > /tmp/cnpe/1/team-monitoring/README.md << 'EOF'
# TeamMonitoring CRD
Custom operator CRD for team monitoring.
EOF

kubectl apply -f /tmp/cnpe/1/team-monitoring/crd.yaml 2>/dev/null || true
cd /tmp/cnpe/1/team-monitoring
git add . && git commit -m "init of project" --allow-empty 2>/dev/null || true

kubectl create namespace pacific --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
log "Q1 setup completato"

# ─── Q2: Prometheus ───────────────────────────────────────────────────────────
section "📊 Q2 — Prometheus Monitoring"

helm upgrade --install prometheus prometheus/prometheus \
  --namespace prometheus \
  --set server.service.type=ClusterIP \
  --set alertmanager.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --set pushgateway.enabled=false \
  --wait --timeout=300s

kubectl -n prometheus delete daemonset prometheus-prometheus-node-exporter --ignore-not-found >/dev/null 2>&1 || true

# Namespace kariba con app fake
kubectl create namespace kariba --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n kariba -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: kariba
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
        image: nginx:alpine
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: kariba
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
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: proxy
  namespace: kariba
spec:
  replicas: 1
  selector:
    matchLabels:
      app: proxy
  template:
    metadata:
      labels:
        app: proxy
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 8080
EOF

log "Q2 setup completato (Prometheus)"

# ─── Q3: Argo CD ──────────────────────────────────────────────────────────────
section "🔄 Q3 — Argo CD"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=ClusterIP \
  --set applicationSet.enabled=true \
  --set applicationSet.extraArgs[0]=--policy=create-update \
  --set applicationSet.extraArgs[1]=--dry-run=false \
  --wait --timeout=600s 2>/dev/null || warn "Argo CD: install/upgrade Helm non riuscito"

# Patch password to 'admin'
BCRYPT_ADMIN='$2a$10$mivhwttXM0U5uo0y/j0WhOBqrKkPgCkFbHfMzUBpzHGZlS0cFD4Iq'
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {\"admin.password\": \"$BCRYPT_ADMIN\", \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"}}" \
  2>/dev/null || true

# Git repo per web-client
mkdir -p /tmp/cnpe/3/web-client/manifests
cd /tmp/cnpe/3/web-client
git init -b main 2>/dev/null || (git init && git checkout -b main 2>/dev/null) || true
git config user.email "root@cnpe3849" 2>/dev/null || true
git config user.name "root" 2>/dev/null || true

cat > /tmp/cnpe/3/web-client/manifests/web-client.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-client
  template:
    metadata:
      labels:
        app: web-client
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-client
  namespace: default
data:
  index.html: "Lagoon Web Client v1"
EOF

cd /tmp/cnpe/3/web-client
git add . && git commit -m "init web-client v1" 2>/dev/null || true

log "Q3 setup completato (ArgoCD, user: admin/admin)"

# ─── Q4: Flagger Blue/Green ───────────────────────────────────────────────────
section "🔵🟢 Q4 — Flagger Blue/Green"

helm upgrade --install flagger flagger/flagger \
  --namespace flagger \
  --set meshProvider=kubernetes \
  --set metricsServer=http://prometheus-server.prometheus:80 \
  --wait --timeout=300s 2>/dev/null || warn "Flagger: install potrebbe richiedere configurazione aggiuntiva"

kubectl create namespace malawi --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n malawi -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: malawi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.7.0
        ports:
        - containerPort: 9898
        env:
        - name: APP_VERSION
          value: "1.0.0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: malawi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.7.0
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: app1-expose
  namespace: malawi
spec:
  type: ClusterIP
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: app2-expose
  namespace: malawi
spec:
  type: ClusterIP
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 9898
EOF

log "Q4 setup completato (app1: 30041, app2: 30042)"

# ─── Q5: OPA Gatekeeper, Helm ─────────────────────────────────────────────────
section "🔒 Q5 — OPA Gatekeeper, Helm"

helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --wait --timeout=300s

kubectl create namespace planet-apps --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/cnpe/5/infra-opa /tmp/cnpe/5/app-saturn/templates

cat > /tmp/cnpe/5/infra-opa/constraint-template.yaml << 'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: planetappconstraint
spec:
  crd:
    spec:
      names:
        kind: PlanetAppConstraint
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package planetappconstraint
        violation[{"msg": msg}] {
          input.review.kind.kind == "Pod"
          not input.review.object.metadata.labels.planet
          msg := "TODO: Pod must include label 'planet'"
        }
        violation[{"msg": msg}] {
          input.review.kind.kind == "Deployment"
          replicas := input.review.object.spec.replicas
          replicas < 2
          msg := "TODO: Deployment must have at least 2 replicas"
        }
EOF

cat > /tmp/cnpe/5/infra-opa/constraint.yaml << 'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PlanetAppConstraint
metadata:
  name: planet-app-constraint
spec:
  match:
    kinds:
      - apiGroups: ["", "apps"]
        kinds: ["Pod", "Deployment"]
EOF

# Helm chart di esempio
cat > /tmp/cnpe/5/app-saturn/Chart.yaml << 'EOF'
apiVersion: v2
name: app-saturn
description: Saturn App
type: application
version: 1.0.1
appVersion: "1.0.0"
EOF

cat > /tmp/cnpe/5/app-saturn/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: saturn
  namespace: planet-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: saturn
  template:
    metadata:
      labels:
        app: saturn
    spec:
      containers:
      - name: saturn
        image: nginx:alpine
EOF

log "Q5 setup completato (OPA Gatekeeper, Helm chart in /tmp/cnpe/5/)"

# ─── Q6: OpenTofu / Terraform ─────────────────────────────────────────────────
section "🏗️  Q6 — OpenTofu / Terraform"

# Installa OpenTofu se non presente
if ! command -v tofu &>/dev/null; then
  info "Installazione OpenTofu..."
  TOFU_VERSION="1.8.0"
  curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
    -o /tmp/tofu.tar.gz 2>/dev/null && \
    tar -xzf /tmp/tofu.tar.gz -C /tmp && \
    sudo mv /tmp/tofu /usr/local/bin/ 2>/dev/null || \
    warn "OpenTofu: installazione manuale necessaria da https://opentofu.org/docs/intro/install/"
fi

# Struttura per i 3 service
for svc in service-black-bean service-green-curry service-red-velvet; do
  mkdir -p /tmp/cnpe/6/$svc
done

cat > /tmp/cnpe/6/service-black-bean/main.tf << 'EOF'
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "black_bean" {
  metadata {
    name      = "black-bean"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "black-bean" }
    }
    template {
      metadata { labels = { app = "black-bean" } }
      spec {
        container {
          name  = "app"
          image = "nginx:alpine"
        }
      }
    }
  }
}
EOF

cat > /tmp/cnpe/6/service-green-curry/main.tf << 'EOF'
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "green_curry" {
  metadata {
    name      = "green-curry"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "green-curry" }
    }
    template {
      metadata { labels = { app = "green-curry" } }
      spec {
        container {
          name  = "app"
          image = "nginx:alpine"
        }
      }
    }
  }
}
EOF

cat > /tmp/cnpe/6/service-red-velvet/main.tf << 'EOF'
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}
resource "kubernetes_deployment" "red_velvet" {
  metadata {
    name      = "red-velvet"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "red-velvet" }
    }
    template {
      metadata { labels = { app = "red-velvet" } }
      spec {
        container {
          name  = "app"
          image = "nginx:alpine"
        }
      }
    }
  }
}
EOF

log "Q6 setup completato (tf files in /tmp/cnpe/6/)"

# ─── Q7: OpenCost + Prometheus ────────────────────────────────────────────────
section "💰 Q7 — OpenCost, Prometheus"

# Usiamo il Prometheus della Q2 (namespace prometheus) per evitare dipendenze da un secondo release opzionale.
OPENCOST_PROM_URL="http://prometheus-server.prometheus:80"
kubectl -n prometheus get svc prometheus-server >/dev/null 2>&1 || warn "Prometheus principale non trovato in namespace prometheus"

# Nota: il messaggio Helm "Release \"opencost\" does not exist. Installing it now."
# e normale al primo avvio con "helm upgrade --install".
if ! helm upgrade --install opencost opencost/opencost \
  --namespace opencost \
  --set opencost.prometheus.internal.enabled=false \
  --set opencost.prometheus.external.url="$OPENCOST_PROM_URL" \
  --set prometheus.external.url="$OPENCOST_PROM_URL" \
  --set service.type=ClusterIP \
  --wait --timeout=600s >/dev/null 2>&1; then
  warn "OpenCost non pronto al primo tentativo, riprovo una volta"
  kubectl -n opencost get pods >/dev/null 2>&1 || true
  sleep 15
  helm upgrade --install opencost opencost/opencost \
    --namespace opencost \
    --set opencost.prometheus.internal.enabled=false \
    --set opencost.prometheus.external.url="$OPENCOST_PROM_URL" \
    --set prometheus.external.url="$OPENCOST_PROM_URL" \
    --set service.type=ClusterIP \
    --wait --timeout=600s >/dev/null 2>&1 || warn "OpenCost: configurazione manuale potrebbe essere necessaria (controlla: kubectl -n opencost get pods, kubectl -n opencost logs deploy/opencost)"
fi

# Alcune versioni/chart ignorano il valore external.url e tornano al default prometheus-system.
# Forziamo l'endpoint corretto sul deployment OpenCost individuato via label (nome release variabile).
OPENCOST_DEPLOY="$(kubectl -n opencost get deploy -l app.kubernetes.io/name=opencost -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$OPENCOST_DEPLOY" ]]; then
  OPENCOST_DEPLOY="opencost"
fi

kubectl -n opencost set env deploy/"$OPENCOST_DEPLOY" \
  PROMETHEUS_SERVER_ENDPOINT="$OPENCOST_PROM_URL" \
  >/dev/null 2>&1 || warn "OpenCost: impossibile impostare PROMETHEUS_SERVER_ENDPOINT su deploy/$OPENCOST_DEPLOY"

kubectl -n opencost rollout restart deploy/"$OPENCOST_DEPLOY" >/dev/null 2>&1 || true
kubectl -n opencost rollout status deploy/"$OPENCOST_DEPLOY" --timeout=180s >/dev/null 2>&1 || warn "OpenCost: rollout non completato, verificare log del pod"

if ! kubectl -n opencost get deploy/"$OPENCOST_DEPLOY" -o jsonpath='{.spec.template.spec.containers[?(@.name=="opencost")].env[?(@.name=="PROMETHEUS_SERVER_ENDPOINT")].value}' 2>/dev/null | grep -q 'prometheus-server.prometheus:80'; then
  warn "OpenCost: env PROMETHEUS_SERVER_ENDPOINT non applicata correttamente su deploy/$OPENCOST_DEPLOY"
fi

# Namespace atlantic per query Prometheus
kubectl create namespace atlantic --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n atlantic -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: sample-pod
  namespace: atlantic
  labels:
    app: sample
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF

mkdir -p /tmp/cnpe/7
log "Q7 setup completato (OpenCost 30070, Prometheus 30020)"

# ─── Q8: Grafana + Loki ───────────────────────────────────────────────────────
section "📈 Q8 — Grafana, Loki"

helm upgrade --install loki grafana/loki \
  --namespace loki \
  --create-namespace \
  --set loki.auth_enabled=false \
  --wait --timeout=300s 2>/dev/null || warn "Loki: install potrebbe richiedere configurazione"

helm upgrade --install grafana grafana/grafana \
  --namespace grafana \
  --set adminPassword=admin \
  --set service.type=ClusterIP \
  --set datasources."datasources\.yaml".apiVersion=1 \
  --set datasources."datasources\.yaml".datasources[0].name=Loki \
  --set datasources."datasources\.yaml".datasources[0].type=loki \
  --set datasources."datasources\.yaml".datasources[0].url="http://loki.loki:3100" \
  --set datasources."datasources\.yaml".datasources[0].access=proxy \
  --set datasources."datasources\.yaml".datasources[0].isDefault=true \
  --wait --timeout=300s 2>/dev/null || warn "Grafana: install potrebbe richiedere configurazione"

# Pod che producono log connection.*
kubectl apply -n loki -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: connection-app-a
  namespace: loki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: connection-app-a
  template:
    metadata:
      labels:
        app: connection-app-a
        pod: connection-app-a
    spec:
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "while true; do echo 'ERROR: connection failed'; sleep 5; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: connection-app-b
  namespace: loki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: connection-app-b
  template:
    metadata:
      labels:
        app: connection-app-b
        pod: connection-app-b
    spec:
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "while true; do echo 'ERROR: connection timeout'; sleep 3; done"]
EOF

log "Q8 setup completato (Grafana 30080, Loki, user: admin/admin)"

# ─── Q9: Kustomize + Prometheus CRDs ─────────────────────────────────────────
section "⚙️  Q9 — Kustomize, Prometheus CRDs"

mkdir -p /tmp/cnpe/9/prom-config/base
mkdir -p /tmp/cnpe/9/prom-config/overlays/staging
mkdir -p /tmp/cnpe/9/prom-config/overlays/production

# Install Prometheus Operator CRDs
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml 2>/dev/null || \
  warn "PodMonitor CRD: potrebbe già essere installata"

cat > /tmp/cnpe/9/prom-config/base/kustomization.yaml << 'EOF'
resources:
  - operator-config.yaml
  - pod-monitor.yaml
EOF

cat > /tmp/cnpe/9/prom-config/base/operator-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: operator-config
data:
  reconcile_interval_seconds: "60"
EOF

cat > /tmp/cnpe/9/prom-config/base/pod-monitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: proxy-monitor
spec:
  selector:
    matchLabels:
      app: proxy
  podMetricsEndpoints:
  - port: http
EOF

cat > /tmp/cnpe/9/prom-config/overlays/staging/kustomization.yaml << 'EOF'
bases:
  - ../../base
namespace: prometheus-staging
EOF

cat > /tmp/cnpe/9/prom-config/overlays/production/kustomization.yaml << 'EOF'
bases:
  - ../../base
namespace: prometheus-production
EOF

kubectl create namespace prometheus-staging --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace prometheus-production --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

log "Q9 setup completato (Kustomize overlays in /tmp/cnpe/9/)"

# ─── Q10: ResourceQuota, Git ──────────────────────────────────────────────────
section "📏 Q10 — ResourceQuota, Git"

for ns in caspian-pipeline1 caspian-pipeline2 caspian-pipeline3; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

mkdir -p /tmp/cnpe/10/pipelines-repo
cd /tmp/cnpe/10/pipelines-repo
git init -b main 2>/dev/null || (git init && git checkout -b main 2>/dev/null) || true
git config user.email "root@cnpe1080" 2>/dev/null || true
git config user.name "root" 2>/dev/null || true

# Commit con 100Gi per caspian-pipeline2 (poi ripristinato)
cat > /tmp/cnpe/10/pipelines-repo/pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-2d60t
  namespace: caspian-pipeline2
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
EOF
git add . && git commit -m "add large pvc for pipeline2" 2>/dev/null || true

# Ripristina
cat > /tmp/cnpe/10/pipelines-repo/pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-2d60t
  namespace: caspian-pipeline2
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
git add . && git commit -m "revert pvc size to 1Gi" 2>/dev/null || true

log "Q10 setup completato (namespaces caspian-pipeline1/2/3, git history con 100Gi)"

# ─── Q11: Argo Workflows ──────────────────────────────────────────────────────
section "🔄 Q11 — Argo Workflows"

kubectl create namespace argo-workflows --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl apply -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml 2>/dev/null; then
  warn "Argo Workflows manifest apply fallito, provo fallback Helm"
  if kubectl -n argo-workflows get deploy argo-server >/dev/null 2>&1; then
    warn "Argo Workflows risulta gia presente (apply parziale). Skip fallback Helm per evitare conflitti di ownership"
  else
    helm upgrade --install argo-workflows argo/argo-workflows \
      --namespace argo-workflows \
      --set server.serviceType=ClusterIP \
      --wait --timeout=300s 2>/dev/null || warn "Argo Workflows: potrebbe richiedere configurazione aggiuntiva"
  fi
fi

kubectl create namespace kaw --dry-run=client -o yaml | kubectl apply -f -

# WorkflowTemplate greeter (con errore da fixare)
kubectl apply -n argo-workflows -f - << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: greeter
  namespace: argo-workflows
spec:
  entrypoint: greeter
  templates:
  - name: greeter
    steps:
    - - name: greet
        template: say-hello
  - name: say-hello
    container:
      image: alpine:3.18
      command: [sh, -c]
      # BUG INTENZIONALE: comando errato (da fixare)
      args: ["echoo hello world"]
EOF

mkdir -p /tmp/cnpe/11

cat > /tmp/cnpe/11/configurator.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: configurator
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: namespace
  templates:
  - name: main
    steps:
    - - name: create-config1
        template: create-configmap
        arguments:
          parameters:
          - name: cm-name
            value: cm1
  - name: create-configmap
    inputs:
      parameters:
      - name: cm-name
    resource:
      action: create
      manifest: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: "{{inputs.parameters.cm-name}}"
          namespace: "{{workflow.parameters.namespace}}"
        data:
          created-by: argo-workflows
EOF

log "Q11 setup completato (Argo Workflows, WorkflowTemplate greeter con bug)"

# ─── Q12: Tekton ──────────────────────────────────────────────────────────────
section "🔧 Q12 — Tekton"

kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml 2>/dev/null || \
  warn "Tekton Pipelines: install da kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"

kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml 2>/dev/null || \
  warn "Tekton Dashboard: install manuale necessaria"

kubectl create namespace builder --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/cnpe/12/p1-team-onboarding /tmp/cnpe/12/p2-team-scanner

cat > /tmp/cnpe/12/p1-team-onboarding/pipeline.yaml << 'EOF'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: p1-team-onboarding
  namespace: builder
spec:
  params:
  - name: team-name
    type: string
  tasks:
  - name: p1-create-namespace
    taskRef:
      name: p1-create-namespace
    params:
    - name: team-name
      value: $(params.team-name)
  - name: p1-create-roles
    taskRef:
      name: p1-create-roles
    params:
    - name: team-name
      value: $(params.team-name)
    runAfter: [p1-create-namespace]
EOF

cat > /tmp/cnpe/12/p1-team-onboarding/tasks.yaml << 'EOF'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p1-create-namespace
  namespace: builder
spec:
  params:
  - name: team-name
    type: string
  steps:
  - name: create-ns
    image: bitnami/kubectl:latest
    script: |
      kubectl create namespace team-$(params.team-name) --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p1-create-roles
  namespace: builder
spec:
  params:
  - name: team-name
    type: string
  steps:
  - name: create-role
    image: bitnami/kubectl:latest
    script: |
      echo "Creating roles for team $(params.team-name)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p1-create-labels
  namespace: builder
spec:
  params:
  - name: team-name
    type: string
  steps:
  - name: label-ns
    image: bitnami/kubectl:latest
    script: |
      kubectl label namespace team-$(params.team-name) auto-created=true --overwrite
EOF

log "Q12 setup completato (Tekton, builder namespace, task templates in /tmp/cnpe/12/)"

# ─── Q13: Pod Security Standards ─────────────────────────────────────────────
section "🛡️  Q13 — Pod Security Standards"

kubectl create namespace ammersee-legacy --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/cnpe/13

# Workloads non-compliant (da fixare)
kubectl apply -n ammersee-legacy -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-app
  namespace: ammersee-legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-app
  template:
    metadata:
      labels:
        app: legacy-app
    spec:
      # NON COMPLIANT: privileged container
      containers:
      - name: app
        image: nginx:alpine
        securityContext:
          privileged: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-db
  namespace: ammersee-legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-db
  template:
    metadata:
      labels:
        app: legacy-db
    spec:
      containers:
      - name: db
        image: nginx:alpine
        # NON COMPLIANT: runAsRoot
        securityContext:
          runAsUser: 0
EOF

# Copia in /tmp/cnpe/13/
kubectl get deploy legacy-app -n ammersee-legacy -o yaml > /tmp/cnpe/13/legacy-app.yaml 2>/dev/null || true
kubectl get deploy legacy-db -n ammersee-legacy -o yaml > /tmp/cnpe/13/legacy-db.yaml 2>/dev/null || true

log "Q13 setup completato (ammersee-legacy con workload non-compliant)"

# ─── Q14: Jaeger ─────────────────────────────────────────────────────────────
section "🔍 Q14 — Jaeger"

kubectl create namespace eyre --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace eyre \
  --set query.service.type=ClusterIP \
  --set allInOne.enabled=true \
  --set storage.type=memory \
  --wait --timeout=300s 2>/dev/null || \
  kubectl apply -n eyre -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/examples/simplest.yaml 2>/dev/null || \
  warn "Jaeger: installazione manuale potrebbe essere necessaria"

# Deploy servizi con tag per Jaeger
kubectl apply -n eyre -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-model-service
  namespace: eyre
  labels:
    ai.model: fast_v1.2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-model-service
  template:
    metadata:
      labels:
        app: ai-model-service
        ai.model: fast_v1.2
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0.0
        args: ["-text=ai-model-service", "-listen=:9555"]
        ports:
        - containerPort: 9555
        env:
        - name: AI_MODEL
          value: fast_v1.2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: public-service
  namespace: eyre
  labels:
    access.public: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: public-service
  template:
    metadata:
      labels:
        app: public-service
        access.public: "true"
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0.0
        args: ["-text=public-service", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: speechai
  namespace: eyre
spec:
  replicas: 1
  selector:
    matchLabels:
      app: speechai
  template:
    metadata:
      labels:
        app: speechai
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0.0
        args: ["-text=speechai", "-listen=:8080"]
        ports:
        - containerPort: 8080
EOF

mkdir -p /tmp/cnpe/14
log "Q14 setup completato (Jaeger, namespace eyre)"

# ─── Q15: VPA ────────────────────────────────────────────────────────────────
section "📈 Q15 — Vertical Pod Autoscaler (VPA)"

kubectl create namespace sargasso --dry-run=client -o yaml | kubectl apply -f -

# Install VPA
VPA_VERSION="1.0.0"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml 2>/dev/null || \
  warn "VPA CRDs: installazione manuale: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler"

mkdir -p /tmp/cnpe/15

cat > /tmp/cnpe/15/etcd.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: etcd
  namespace: sargasso
spec:
  serviceName: etcd
  replicas: 1
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
      - name: etcd
        image: registry.k8s.io/etcd:3.5.12-0
        command: ["etcd"]
        args:
        - --name=etcd-0
        - --data-dir=/var/lib/etcd
        - --listen-client-urls=http://0.0.0.0:2379
        - --advertise-client-urls=http://etcd.sargasso.svc.cluster.local:2379
        volumeMounts:
        - name: etcd-data
          mountPath: /var/lib/etcd
        ports:
        - containerPort: 2379
        resources:
          requests:
            cpu: 20m
            memory: 20Mi
      volumes:
      - name: etcd-data
        emptyDir: {}
---
# VPA da aggiungere qui (domanda Q15)
# apiVersion: autoscaling.k8s.io/v1
# kind: VerticalPodAutoscaler
# ...
EOF

kubectl apply -f /tmp/cnpe/15/etcd.yaml 2>/dev/null || true
log "Q15 setup completato (VPA, sargasso namespace, etcd.yaml in /tmp/cnpe/15/)"

# ─── Q16: Argo Rollouts, Canary ───────────────────────────────────────────────
section "🌊 Q16 — Argo Rollouts, Canary"

kubectl create namespace baltic --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml 2>/dev/null; then
  warn "Argo Rollouts manifest apply fallito, provo fallback Helm"
  if kubectl -n argo-rollouts get deploy argo-rollouts >/dev/null 2>&1; then
    warn "Argo Rollouts risulta gia presente (apply parziale). Skip fallback Helm per evitare conflitti di ownership"
  else
    helm upgrade --install argo-rollouts argo/argo-rollouts \
      --namespace argo-rollouts \
      --set dashboard.enabled=true \
      --set dashboard.service.type=ClusterIP \
      --wait --timeout=300s 2>/dev/null || warn "Argo Rollouts: configurazione manuale"
  fi
fi

mkdir -p /tmp/cnpe/16

cat > /tmp/cnpe/16/analysis_template.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: webapp-health
  namespace: baltic
spec:
  args:
  - name: service-url
  metrics:
  - name: http-check
    interval: 10s
    successCondition: result == 200
    failureLimit: 3
    provider:
      web:
        url: "http://{{args.service-url}}/health"
        timeoutSeconds: 10
EOF

kubectl apply -n baltic -f - << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: webapp
  namespace: baltic
spec:
  replicas: 4
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.18.0"
  strategy:
    canary:
      canaryService: webapp-canary
      stableService: webapp-stable
      steps:
      - setWeight: 50
      - pause: {}
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-canary
  namespace: baltic
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-stable
  namespace: baltic
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
EOF

log "Q16 setup completato (Argo Rollouts 30160, webapp canary in baltic)"

# ─── Q17: FluxCD ─────────────────────────────────────────────────────────────
section "🌊 Q17 — FluxCD"

# Install Flux CLI
if ! command -v flux &>/dev/null; then
  curl -s https://fluxcd.io/install.sh | sudo bash 2>/dev/null || \
    warn "Flux CLI: installazione manuale da https://fluxcd.io/docs/installation/"
fi

flux install --namespace=flux-system 2>/dev/null || \
  kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml 2>/dev/null || \
  warn "FluxCD: installazione manuale necessaria"

kubectl create namespace havel-east --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/cnpe/17/havel-west /tmp/cnpe/17/havel-east

for dir in havel-west havel-east; do
  cat > /tmp/cnpe/17/$dir/kustomization.yaml << EOF
resources:
  - deployment.yaml
EOF
  cat > /tmp/cnpe/17/$dir/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $dir
  namespace: $dir
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $dir
  template:
    metadata:
      labels:
        app: $dir
    spec:
      containers:
      - name: app
        image: nginx:alpine
EOF
done

# Kustomization havel-west (sospesa — da riprendere nella domanda)
kubectl apply -n flux-system -f - << 'EOF' 2>/dev/null || true
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: havel-west
  namespace: flux-system
spec:
  suspend: true
  interval: 5m
  path: ./havel-west
  prune: true
  sourceRef:
    kind: GitRepository
    name: havel-west
EOF

log "Q17 setup completato (FluxCD, havel-west sospeso, havel-east da deployare)"

# ─── Q18: Kyverno ────────────────────────────────────────────────────────────
section "🔐 Q18 — Kyverno"

helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --wait --timeout=300s

kubectl create namespace caribbean --dry-run=client -o yaml | kubectl apply -f -
log "Q18 setup completato (Kyverno, namespace caribbean)"

# ─── Q19: Crossplane ─────────────────────────────────────────────────────────
section "☁️  Q19 — Crossplane"

helm upgrade --install crossplane crossplane/crossplane \
  --namespace crossplane-system \
  --wait --timeout=300s

kubectl create namespace danau --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/cnpe/19

cat > /tmp/cnpe/19/composition.yaml << 'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: redis-composition
spec:
  compositeTypeRef:
    apiVersion: cache.killer.sh/v1alpha1
    kind: Redis
  resources:
  - name: statefulset
    base:
      apiVersion: apps/v1
      kind: StatefulSet
      spec:
        selector:
          matchLabels:
            app: redis
        serviceName: redis
        template:
          metadata:
            labels:
              app: redis
          spec:
            containers:
            - name: redis
              image: redis:7-alpine
              ports:
              - containerPort: 6379
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.size
      toFieldPath: spec.replicas
      transforms:
      - type: map
        map:
          small: "1"
          medium: "2"
          large: "3"
  readinessChecks:
  - type: MatchTrue
    fieldPath: status.readyReplicas
  # TODO: aggiungere Service (domanda Q19)
EOF

log "Q19 setup completato (Crossplane, composition in /tmp/cnpe/19/)"

# ─── Q20: Linkerd, Gateway API ────────────────────────────────────────────────
section "🔗 Q20 — Linkerd, Gateway API"

# Install Linkerd CLI
if ! command -v linkerd &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh 2>/dev/null || \
    warn "Linkerd CLI: installazione manuale da https://linkerd.io/getting-started/"
fi
export PATH="$PATH:$HOME/.linkerd2/bin"

if ! linkerd install --crds 2>/dev/null | kubectl apply -f - 2>/dev/null; then
  warn "Linkerd CRDs via CLI non disponibili, provo fallback Helm"
  helm upgrade --install linkerd-crds linkerd/linkerd-crds \
    --namespace linkerd \
    --create-namespace \
    --wait --timeout=300s 2>/dev/null || warn "Linkerd CRDs: installazione manuale necessaria"
fi

if ! linkerd install 2>/dev/null | kubectl apply -f - 2>/dev/null; then
  warn "Linkerd control-plane via CLI non disponibile, provo fallback Helm"
  helm upgrade --install linkerd-control-plane linkerd/linkerd-control-plane \
    --namespace linkerd \
    --wait --timeout=300s 2>/dev/null || warn "Linkerd: installazione manuale necessaria"
fi

kubectl create namespace saltlake-app --dry-run=client -o yaml | kubectl apply -f -

# Annotate namespace for linkerd
kubectl annotate namespace saltlake-app linkerd.io/inject=enabled --overwrite 2>/dev/null || true

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml 2>/dev/null || \
  warn "Gateway API: installazione manuale da https://gateway-api.sigs.k8s.io/guides/"

kubectl apply -n saltlake-app -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: saltlake-app
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
        image: stefanprodan/podinfo:6.7.0
        ports:
        - containerPort: 9898
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v1
  namespace: saltlake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.6.0
        ports:
        - containerPort: 9898
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v2
  namespace: saltlake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v2
  template:
    metadata:
      labels:
        app: backend
        version: v2
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.7.0
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: saltlake-app
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: saltlake-app
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: backend-v1
  namespace: saltlake-app
spec:
  selector:
    app: backend
    version: v1
  ports:
  - port: 80
    targetPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: backend-v2
  namespace: saltlake-app
spec:
  selector:
    app: backend
    version: v2
  ports:
  - port: 80
    targetPort: 9898
EOF

if kubectl get crd authorizationpolicies.policy.linkerd.io >/dev/null 2>&1; then
  kubectl apply -n saltlake-app -f - << 'EOF'
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: saltlake-app
spec:
  targetRef:
    group: core
    kind: Service
    name: backend
  requiredAuthenticationRefs:
  - name: frontend
    kind: ServiceAccount
    namespace: saltlake-app
EOF
else
  warn "Linkerd AuthorizationPolicy CRD non presente: skip creazione frontend-to-backend"
fi

log "Q20 setup completato (Linkerd, Gateway API, saltlake-app namespace)"

# ─── Riepilogo finale ─────────────────────────────────────────────────────────
section "🎉 Setup completato!"

echo -e "${BOLD}Cluster:${NC}       $CLUSTER_NAME"
echo -e "${BOLD}Kubernetes:${NC}    $MINIKUBE_K8S_VERSION"
echo -e "${BOLD}CPU/RAM:${NC}       4 CPU / 18GB"
echo ""
echo -e "${BOLD}${CYAN}Servizi esposti (port-forward su 0.0.0.0):${NC}"
SERVICE_HOST="0.0.0.0"
echo -e "  ${GREEN}Prometheus${NC}         http://$SERVICE_HOST:30020"
echo -e "  ${GREEN}Argo CD${NC}            http://$SERVICE_HOST:30030    (admin/admin)"
echo -e "  ${GREEN}Flagger app1${NC}       http://$SERVICE_HOST:30041"
echo -e "  ${GREEN}Flagger app2${NC}       http://$SERVICE_HOST:30042"
echo -e "  ${GREEN}OpenCost${NC}           http://$SERVICE_HOST:30070"
echo -e "  ${GREEN}Grafana${NC}            http://$SERVICE_HOST:30080    (admin/admin)"
echo -e "  ${GREEN}Argo Workflows${NC}     http://$SERVICE_HOST:30110"
echo -e "  ${GREEN}Tekton Dashboard${NC}   http://$SERVICE_HOST:30120"
echo -e "  ${GREEN}Argo Rollouts${NC}      http://$SERVICE_HOST:30160"
echo -e "  ${GREEN}Webapp Canary${NC}      http://$SERVICE_HOST:30161"
echo -e "  ${GREEN}Jaeger${NC}             http://$SERVICE_HOST:30014"
echo ""
echo -e "${BOLD}${CYAN}File di lavoro:${NC}"
echo -e "  /tmp/cnpe/1/  — CRD, Kustomize, Git"
echo -e "  /tmp/cnpe/3/  — Argo CD web-client"
echo -e "  /tmp/cnpe/5/  — OPA Gatekeeper, Helm chart"
echo -e "  /tmp/cnpe/6/  — OpenTofu configs"
echo -e "  /tmp/cnpe/7/  — OpenCost results"
echo -e "  /tmp/cnpe/9/  — Kustomize Prometheus overlays"
echo -e "  /tmp/cnpe/10/ — ResourceQuota, Git history"
echo -e "  /tmp/cnpe/11/ — Argo Workflows templates"
echo -e "  /tmp/cnpe/12/ — Tekton pipelines"
echo -e "  /tmp/cnpe/13/ — Pod Security workloads"
echo -e "  /tmp/cnpe/14/ — Jaeger traces"
echo -e "  /tmp/cnpe/15/ — VPA etcd.yaml"
echo -e "  /tmp/cnpe/16/ — Argo Rollouts analysis template"
echo -e "  /tmp/cnpe/17/ — FluxCD havel-west/east"
echo -e "  /tmp/cnpe/19/ — Crossplane composition"
echo ""
echo -e "${YELLOW}⚠️  Nota: alcuni componenti (Linkerd, OpenCost, VPA) potrebbero${NC}"
echo -e "${YELLOW}   richiedere configurazione aggiuntiva post-install.${NC}"
echo -e "${YELLOW}   Verifica con: kubectl get pods --all-namespaces${NC}"

echo ""
echo "=== BEGIN_EXERCISE_ENDPOINT_SUMMARY ==="
echo "Endpoint e credenziali per esercizio (Batteria 01)"
echo "- Q1  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q2  | Endpoint: http://0.0.0.0:30020                    | Credenziali: n/a"
echo "- Q3  | Endpoint: http://0.0.0.0:30030                    | Credenziali: admin/admin"
echo "- Q4  | Endpoint: http://0.0.0.0:30041, http://0.0.0.0:30042 | Credenziali: n/a"
echo "- Q5  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q6  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q7  | Endpoint: http://0.0.0.0:30070, http://0.0.0.0:30020 | Credenziali: n/a"
echo "- Q8  | Endpoint: http://0.0.0.0:30080                    | Credenziali: admin/admin"
echo "- Q9  | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q10 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q11 | Endpoint: http://0.0.0.0:30110                    | Credenziali: n/a"
echo "- Q12 | Endpoint: http://0.0.0.0:30120                    | Credenziali: n/a"
echo "- Q13 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q14 | Endpoint: http://0.0.0.0:30014                    | Credenziali: n/a"
echo "- Q15 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q16 | Endpoint: http://0.0.0.0:30160, http://0.0.0.0:30161 | Credenziali: n/a"
echo "- Q17 | Endpoint: n/a                                      | Credenziali: n/a"
echo "- Q18 | Endpoint: n/a                                      | Credenziali: n/a"
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
