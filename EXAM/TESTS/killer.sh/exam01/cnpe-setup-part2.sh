#!/usr/bin/env bash
# ============================================================
# CNPE Lab Setup - Part 2: Q6-Q12
# ============================================================
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="cnpe-user"
GITEA_PASS="cnpe-pass"
GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"

# Use caller's home directory instead of /course to avoid permission issues.
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

gitea_api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}

GITEA_AUTH_USER="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" 2>/dev/null | jq -r '.login // empty' || true)"
[ -n "${GITEA_AUTH_USER}" ] || GITEA_AUTH_USER="${GITEA_USER}"

ensure_org_repo() {
  local repo=$1
  local code

  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${repo}")

  if [ "$code" = "200" ]; then
    return 0
  fi

  gitea_api -X POST "${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos" \
    -d "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}" >/dev/null

  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${repo}")

  [ "$code" = "200" ] || die "Cannot create/access ${GITEA_ORG}/${repo} (HTTP ${code}). Check org permissions for token."
}

# ============================================================
section "6. Q6 – OpenTofu / Terraform"
# ============================================================
if ! command -v tofu &>/dev/null && ! command -v terraform &>/dev/null; then
  warn "tofu not found – skipping Q6 filesystem setup"
fi

# Namespace baikal
kubectl create ns baikal --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Create some pre-existing resources that OpenTofu will manage
kubectl apply -n baikal -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: black-bean
  namespace: baikal
  labels:
    app: black-bean
spec:
  replicas: 1
  selector:
    matchLabels:
      app: black-bean
  template:
    metadata:
      labels:
        app: black-bean
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green-curry
  namespace: baikal
  labels:
    app: green-curry
spec:
  replicas: 0
  selector:
    matchLabels:
      app: green-curry
  template:
    metadata:
      labels:
        app: green-curry
    spec:
      containers:
        - name: nginx
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: red-velvet
  namespace: baikal
  labels:
    app: red-velvet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: red-velvet
  template:
    metadata:
      labels:
        app: red-velvet
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: baikal
  labels:
    app: test
spec:
  selector:
    app: test
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: green-curry
  namespace: baikal
spec:
  selector:
    app: green-curry
  ports:
    - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: red-velvet
  namespace: baikal
spec:
  selector:
    app: red-velvet
  ports:
    - port: 80
YAML

# Install Terraform/OpenTofu kubernetes provider config
# We use a kubeconfig-based local state approach
KUBE_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KUBE_CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
KUBE_CERT=$(kubectl config view --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}')
KUBE_KEY=$(kubectl config view --minify --raw -o jsonpath='{.users[0].user.client-key-data}')

write_tofu_provider() {
  cat << EOF
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  host = "${KUBE_HOST}"
  cluster_ca_certificate = base64decode("${KUBE_CA}")
  client_certificate     = base64decode("${KUBE_CERT}")
  client_key             = base64decode("${KUBE_KEY}")
}

locals {
  namespace = "baikal"
}
EOF
}

# service-black-bean
mkdir -p "$COURSE_DIR/6/service-black-bean"
cat > "$COURSE_DIR/6/service-black-bean/main.tf" << EOF
$(write_tofu_provider)

resource "kubernetes_deployment" "black-bean" {
  metadata {
    name      = "black-bean"
    namespace = local.namespace
    labels    = { app = "black-bean" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "black-bean" } }
    template {
      metadata { labels = { app = "black-bean" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1-alpine"
          port { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service" "black-bean" {
  metadata {
    name      = "black-bean"
    namespace = local.namespace
    labels    = { app = "black-bean" }
  }
  spec {
    selector = { app = "black-bean" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
EOF

# service-green-curry
mkdir -p "$COURSE_DIR/6/service-green-curry"
cat > "$COURSE_DIR/6/service-green-curry/main.tf" << EOF
$(write_tofu_provider)

resource "kubernetes_deployment" "green-curry" {
  metadata {
    name      = "green-curry"
    namespace = local.namespace
    labels    = { app = "green-curry" }
  }
  spec {
    replicas = 0
    selector { match_labels = { app = "green-curry" } }
    template {
      metadata { labels = { app = "green-curry" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1-alpine"
          port { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service" "green-curry" {
  metadata {
    name      = "green-curry"
    namespace = local.namespace
    labels    = { app = "green-curry" }
  }
  spec {
    selector = { app = "green-curry" }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}
EOF

# service-red-velvet
mkdir -p "$COURSE_DIR/6/service-red-velvet"
cat > "$COURSE_DIR/6/service-red-velvet/main.tf" << EOF
$(write_tofu_provider)

resource "kubernetes_deployment" "red-velvet" {
  metadata {
    name      = "red-velvet"
    namespace = local.namespace
    labels    = { app = "red-velvet" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "red-velvet" } }
    template {
      metadata { labels = { app = "red-velvet" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1-alpine"
          port { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service" "red-velvet" {
  metadata {
    name      = "red-velvet"
    namespace = local.namespace
    labels    = { app = "red-velvet" }
  }
  spec {
    selector = { app = "red-velvet" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
EOF

# Init tofu state for all three
for dir in service-black-bean service-green-curry service-red-velvet; do
  (
    cd "$COURSE_DIR/6/$dir"
    tofu init -input=false >/dev/null 2>&1 && \
    tofu apply -auto-approve -input=false >/dev/null 2>&1 || \
    warn "tofu apply failed for $dir (may be normal if resources exist)"
  ) || true
done

success "Q6 ready"

# ============================================================
section "7. Q7 – OpenCost + Prometheus"
# ============================================================
helm repo add opencost https://opencost.github.io/opencost-helm-chart 2>/dev/null || true
helm repo update

kubectl create ns opencost --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Custom pricing ConfigMap
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-pricing-model
  namespace: opencost
data:
  default.json: |-
    {
      "CPU": "1.25",
      "GPU": "0.95",
      "RAM": "0.5",
      "cpu": "0.03",
      "description": "Modified pricing configuration.",
      "gpu": "0.90",
      "internetNetworkEgress": "0.12",
      "nodes": "map[default:map[hourlyCost:0.10 storagePerGiB:20.00]]",
      "ram": "10.00",
      "regionNetworkEgress": "0.01",
      "spot": "map[enabled:false]",
      "spotCPU": "0.008",
      "spotRAM": "0.000892",
      "storage": "20.00",
      "zoneNetworkEgress": "0.01",
      "provider": "custom"
    }
YAML

# Install opencost pointing at our prometheus
helm upgrade --install opencost opencost/opencost \
  --namespace opencost \
  --set opencost.prometheus.internal.enabled=false \
  --set opencost.prometheus.external.enabled=true \
  --set opencost.prometheus.external.url=http://prometheus-server.prometheus:9090 \
  --wait --timeout=240s 2>/dev/null || warn "OpenCost install may need manual attention"

# Expose opencost UI
kubectl -n opencost patch svc opencost \
  -p '{"spec":{"type":"NodePort"}}' 2>/dev/null || true
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: opencost-nodeport
  namespace: opencost
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: opencost
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30070
      name: ui
    - port: 9003
      targetPort: 9003
      nodePort: 30077
      name: metrics
YAML

# atlantic namespace with pods
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: translator
  namespace: atlantic
spec:
  replicas: 2
  selector:
    matchLabels:
      app: translator
  template:
    metadata:
      labels:
        app: translator
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
          ports:
            - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: repository
  namespace: atlantic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: repository
  template:
    metadata:
      labels:
        app: repository
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: datastore
  namespace: atlantic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: datastore
  template:
    metadata:
      labels:
        app: datastore
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

mkdir -p $COURSE_DIR/7
success "Q7 ready"

# ============================================================
section "8. Q8 – Grafana + Loki"
# ============================================================
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Install Loki (single binary mode)
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --wait --timeout=300s 2>/dev/null || \
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --wait --timeout=300s

# Install Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=admin \
  --set service.type=NodePort \
  --set 'service.nodePort=30080' \
  --set "grafana\.ini.auth.anonymous.enabled=true" \
  --set "grafana\.ini.auth.anonymous.org_role=Admin" \
  --set 'datasources.datasources\.yaml.apiVersion=1' \
  --set 'datasources.datasources\.yaml.datasources[0].name=Loki' \
  --set 'datasources.datasources\.yaml.datasources[0].type=loki' \
  --set 'datasources.datasources\.yaml.datasources[0].url=http://loki:3100' \
  --set 'datasources.datasources\.yaml.datasources[0].access=proxy' \
  --set 'datasources.datasources\.yaml.datasources[0].isDefault=true' \
  --wait --timeout=240s

# Arctic workload – apps that produce logs
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: connection-uplift
  namespace: arctic-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: connection-uplift
  template:
    metadata:
      labels:
        app: connection-uplift
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do
                echo "$(date) INFO normal operation";
                sleep 5;
              done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: verification
  namespace: arctic-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: verification
  template:
    metadata:
      labels:
        app: verification
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do
                echo "$(date) ERROR verification failed";
                sleep 3;
              done
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: workflow-engine
  namespace: arctic-workload
spec:
  serviceName: workflow-engine
  replicas: 1
  selector:
    matchLabels:
      app: workflow-engine
  template:
    metadata:
      labels:
        app: workflow-engine
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do echo "$(date) INFO workflow processing"; sleep 5; done
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: resource-limiter
  namespace: arctic-workload
spec:
  serviceName: resource-limiter
  replicas: 1
  selector:
    matchLabels:
      app: resource-limiter
  template:
    metadata:
      labels:
        app: resource-limiter
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args:
            - while true; do
                echo "$(date) ERROR resource limit exceeded";
                sleep 4;
              done
YAML

# Grafana Dashboard for logging
DASHBOARD_JSON='{"title":"logging","panels":[{"type":"logs","title":"App Logs","datasource":"Loki","targets":[{"expr":"{namespace=\"arctic-workload\"}"}],"gridPos":{"x":0,"y":0,"w":24,"h":8}}],"schemaVersion":30}'
success "Q8 ready"

# ============================================================
section "9. Q9 – Kustomize + Prometheus Operator CRDs"
# ============================================================
mkdir -p $COURSE_DIR/9/prom-config/base/prometheus-operator
mkdir -p $COURSE_DIR/9/prom-config/overlays/staging
mkdir -p $COURSE_DIR/9/prom-config/overlays/production

# Download Prometheus Operator CRDs
PO_VER="v0.75.0"
curl -sSL "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PO_VER}/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml" \
  -o $COURSE_DIR/9/prom-config/base/prometheus-operator/crd-podmonitors.yaml 2>/dev/null || \
cat > $COURSE_DIR/9/prom-config/base/prometheus-operator/crd-podmonitors.yaml << 'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: podmonitors.monitoring.coreos.com
spec:
  group: monitoring.coreos.com
  names:
    kind: PodMonitor
    listKind: PodMonitorList
    plural: podmonitors
    singular: podmonitor
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                attachMetadata:
                  type: object
                  properties:
                    node:
                      type: boolean
                sampleLimit:
                  type: integer
                labelLimit:
                  type: integer
                targetLimit:
                  type: integer
                namespaceSelector:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                selector:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                podMetricsEndpoints:
                  type: array
                  items:
                    type: object
                    x-kubernetes-preserve-unknown-fields: true
YAML

curl -sSL "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PO_VER}/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml" \
  -o $COURSE_DIR/9/prom-config/base/prometheus-operator/crd-prometheusrules.yaml 2>/dev/null || \
cat > $COURSE_DIR/9/prom-config/base/prometheus-operator/crd-prometheusrules.yaml << 'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: prometheusrules.monitoring.coreos.com
spec:
  group: monitoring.coreos.com
  names:
    kind: PrometheusRule
    listKind: PrometheusRuleList
    plural: prometheusrules
    shortNames:
      - promrule
    singular: prometheusrule
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML

cat > $COURSE_DIR/9/prom-config/base/config.yaml << 'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: operator-config
data:
  operator_mode: "passive"
  reconcile_interval_seconds: "60"
  controller.settings: |
    enableMetrics=true
    maxConcurrentReconciles=4
    featureGates=ExperimentalChecks
  alerting.rules: |
    alert.lowDiskSpace=true
    alert.restartCountThreshold=10
    alert.latencyThresholdMs=250
YAML

cat > $COURSE_DIR/9/prom-config/base/monitors.yaml << 'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: proxy-monitor
  labels:
    app: proxy
    team: edge-proxy
spec:
  namespaceSelector:
    matchNames:
      - proxy
  selector:
    matchLabels:
      app: proxy
      component: http-proxy
  podMetricsEndpoints:
    - port: metrics
      path: /metrics
      scheme: http
      interval: 60s
      scrapeTimeout: 10s
      honorLabels: true
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_node_name]
          targetLabel: node
  sampleLimit: 5000
  labelLimit: 10
  targetLimit: 100
YAML

cat > $COURSE_DIR/9/prom-config/base/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - prometheus-operator/crd-podmonitors.yaml
  - monitors.yaml
  - config.yaml

transformers:
  - |-
    apiVersion: builtin
    kind: NamespaceTransformer
    metadata:
      name: notImportantHere
      namespace: NAMESPACE_REPLACE
YAML

# Staging overlay
cat > $COURSE_DIR/9/prom-config/overlays/staging/config.yaml << 'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: operator-config
data:
  operator_mode: "idle"
YAML

cat > $COURSE_DIR/9/prom-config/overlays/staging/monitors.yaml << 'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: proxy-monitor
spec:
  namespaceSelector:
    matchNames:
      - atlantic-staging
  labelLimit: 25
YAML

cat > $COURSE_DIR/9/prom-config/overlays/staging/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - path: monitors.yaml
  - path: config.yaml

transformers:
  - |-
    apiVersion: builtin
    kind: NamespaceTransformer
    metadata:
      name: notImportantHere
      namespace: atlantic-staging
YAML

# Production overlay
cat > $COURSE_DIR/9/prom-config/overlays/production/monitors.yaml << 'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: proxy-monitor
spec:
  namespaceSelector:
    matchNames:
      - atlantic-production
  labelLimit: 50
YAML

cat > $COURSE_DIR/9/prom-config/overlays/production/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - path: monitors.yaml

transformers:
  - |-
    apiVersion: builtin
    kind: NamespaceTransformer
    metadata:
      name: notImportantHere
      namespace: atlantic-production
YAML

for ns in atlantic-staging atlantic-production; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

kubectl apply -k $COURSE_DIR/9/prom-config/overlays/staging 2>/dev/null || true
kubectl apply -k $COURSE_DIR/9/prom-config/overlays/production 2>/dev/null || true

success "Q9 ready"

# ============================================================
section "10. Q10 – ResourceQuota + Git"
# ============================================================
mkdir -p $COURSE_DIR/10/pipelines-repo

for i in 1 2 3; do
  kubectl create ns "caspian-pipeline${i}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

# pipeline1.yaml
cat > $COURSE_DIR/10/pipelines-repo/pipeline1.yaml << 'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: caspian-pipeline1
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-ae76c
  namespace: caspian-pipeline1
  labels:
    app: gitlab-runner-ae76c
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Mi
  storageClassName: standard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner-ae76c
  namespace: caspian-pipeline1
  labels:
    app: gitlab-runner-ae76c
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab-runner-ae76c
  template:
    metadata:
      labels:
        app: gitlab-runner-ae76c
    spec:
      terminationGracePeriodSeconds: 3
      containers:
        - name: runner
          image: nginx:1-alpine
          volumeMounts:
            - name: runner-data-volume
              mountPath: /mnt/runner-cache
      volumes:
        - name: runner-data-volume
          persistentVolumeClaim:
            claimName: gitlab-runner-ae76c
YAML

# pipeline2.yaml – the one that requested 100Gi (now reverted)
cat > $COURSE_DIR/10/pipelines-repo/pipeline2.yaml << 'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: caspian-pipeline2
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-2d60t
  namespace: caspian-pipeline2
  labels:
    app: gitlab-runner-2d60t
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
  storageClassName: standard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner-2d60t
  namespace: caspian-pipeline2
  labels:
    app: gitlab-runner-2d60t
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab-runner-2d60t
  template:
    metadata:
      labels:
        app: gitlab-runner-2d60t
    spec:
      terminationGracePeriodSeconds: 3
      containers:
        - name: runner
          image: nginx:1-alpine
          volumeMounts:
            - name: runner-data-volume
              mountPath: /mnt/runner-cache
      volumes:
        - name: runner-data-volume
          persistentVolumeClaim:
            claimName: gitlab-runner-2d60t
YAML

# pipeline3.yaml
cat > $COURSE_DIR/10/pipelines-repo/pipeline3.yaml << 'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: caspian-pipeline3
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-runner-98p8e
  namespace: caspian-pipeline3
  labels:
    app: gitlab-runner-98p8e
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Mi
  storageClassName: standard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner-98p8e
  namespace: caspian-pipeline3
  labels:
    app: gitlab-runner-98p8e
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab-runner-98p8e
  template:
    metadata:
      labels:
        app: gitlab-runner-98p8e
    spec:
      terminationGracePeriodSeconds: 3
      containers:
        - name: runner
          image: nginx:1-alpine
          volumeMounts:
            - name: runner-data-volume
              mountPath: /mnt/runner-cache
      volumes:
        - name: runner-data-volume
          persistentVolumeClaim:
            claimName: gitlab-runner-98p8e
YAML

# Apply PVCs and deployments
kubectl apply -f $COURSE_DIR/10/pipelines-repo/pipeline1.yaml 2>/dev/null || true
kubectl apply -f $COURSE_DIR/10/pipelines-repo/pipeline2.yaml 2>/dev/null || true
kubectl apply -f $COURSE_DIR/10/pipelines-repo/pipeline3.yaml 2>/dev/null || true

# Build git history with the 100Gi commit
ensure_org_repo "pipelines-repo"

(
  cd "$COURSE_DIR/10/pipelines-repo"
  git init -b main 2>/dev/null || git init
  git checkout -b main 2>/dev/null || true

  # Commit 1: first pipeline
  cp pipeline1.yaml /tmp/p1_tmp.yaml
  git add pipeline1.yaml
  git commit -m "added first pipeline" 2>/dev/null || true

  # Commit 2: add pipelines 2 and 3
  git add pipeline2.yaml pipeline3.yaml
  git commit -m "added two more pipelines" 2>/dev/null || true

  # Commit 3: bump pipeline2 storage to 100Gi (the offending commit)
  sed -i 's/storage: 10Mi/storage: 100Gi/' pipeline2.yaml
  git add pipeline2.yaml
  git commit -m "updated pipelines" 2>/dev/null || true

  # Commit 4: revert back to 10Mi
  sed -i 's/storage: 100Gi/storage: 10Mi/' pipeline2.yaml
  git add pipeline2.yaml
  git commit -m "fixed pipelines" 2>/dev/null || true

  REMOTE_URL="${GITEA_URL/http:\/\//http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@}/${GITEA_ORG}/pipelines-repo.git"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE_URL"
  git push -u origin main --force
)

success "Q10 ready"

# ============================================================
section "11. Q11 – Argo Workflows"
# ============================================================
kubectl create ns argo --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Install Argo Workflows
kubectl apply -n argo -f \
  https://github.com/argoproj/argo-workflows/releases/download/v3.5.7/install.yaml

# Wait for Argo core components before patching/configuring resources.
if ! kubectl -n argo rollout status deploy/workflow-controller --timeout=300s; then
  kubectl -n argo get pods -o wide || true
  kubectl -n argo logs deploy/workflow-controller --tail=120 || true
  die "workflow-controller is not healthy"
fi
kubectl -n argo rollout status deploy/argo-server --timeout=300s 2>/dev/null || \
  warn "argo-server not ready yet"

# Expose UI on NodePort 30110
kubectl -n argo patch svc argo-server \
  -p '{"spec":{"type":"NodePort","ports":[{"port":2746,"targetPort":2746,"nodePort":30110,"protocol":"TCP","name":"web"}]}}' \
  2>/dev/null || true

# Disable auth for lab on argo-server (not on workflow-controller configmap).
if ! kubectl -n argo get deploy argo-server -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null | grep -q -- '--auth-mode='; then
  kubectl -n argo patch deploy argo-server --type='json' \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--auth-mode=server"}]' \
    2>/dev/null || true
fi

# ServiceAccount for workflows
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo
  namespace: argo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-workflows-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: argo
    namespace: argo
YAML

# WorkflowTemplate greeter WITH the bug (eccho)
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: greeter
  namespace: argo
spec:
  arguments: {}
  entrypoint: greet
  serviceAccountName: argo
  templates:
    - container:
        args:
          - eccho 'hello there, have a wonderful day!'
        command:
          - sh
          - -c
        image: alpine:3
        name: ""
        resources: {}
      name: greet
YAML

# Submit a workflow that will FAIL (to simulate the pre-existing failed run)
kubectl create -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: greeter-
  namespace: argo
spec:
  workflowTemplateRef:
    name: greeter
YAML

mkdir -p $COURSE_DIR/11

cat > $COURSE_DIR/11/configurator.yaml << 'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: configurator
  namespace: argo
  annotations:
    description: "Generates certain ConfigMaps in passed Namespace"
spec:
  entrypoint: chain
  serviceAccountName: argo

  arguments:
    parameters:
      - name: target_namespace
        value: "default"

  templates:
    - name: chain
      steps:
        - - name: config1
            template: create-config1
            arguments:
              parameters:
                - name: ns
                  value: "{{workflow.parameters.target_namespace}}"

    - name: create-config1
      inputs:
        parameters:
          - name: ns
      container:
        image: alpine/kubectl:latest
        command: ["/bin/sh","-c", "kubectl -n {{inputs.parameters.ns}} create configmap cm1 --from-literal=debug=true -o yaml --dry-run=client | kubectl apply -f -"]
YAML

kubectl apply -f $COURSE_DIR/11/configurator.yaml
kubectl create ns kaw --dry-run=client -o yaml | kubectl apply -f - >/dev/null

success "Q11 ready"

# ============================================================
section "12. Q12 – Tekton"
# ============================================================
# Install Tekton Pipelines
kubectl apply -f \
  https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml \
  2>/dev/null || \
kubectl apply -f \
  https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.59.0/release.yaml

# Install Tekton Dashboard
kubectl apply -f \
  https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml \
  2>/dev/null || true

# Wait for Tekton admission webhook before creating v1beta1 Task/Pipeline resources.
kubectl -n tekton-pipelines wait deploy/tekton-pipelines-webhook \
  --for=condition=Available --timeout=240s 2>/dev/null || true
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook \
  --timeout=240s 2>/dev/null || true
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller \
  --timeout=240s 2>/dev/null || true
kubectl -n tekton-pipelines rollout status deploy/tekton-dashboard \
  --timeout=240s 2>/dev/null || true

# Expose dashboard on NodePort 30120
kubectl -n tekton-pipelines patch svc tekton-dashboard \
  -p '{"spec":{"type":"NodePort","ports":[{"port":9097,"targetPort":9097,"nodePort":30120,"protocol":"TCP","name":"http"}]}}' \
  2>/dev/null || true

mkdir -p $COURSE_DIR/12/p1-team-onboarding
mkdir -p $COURSE_DIR/12/p2-team-scanner

# RBAC for builder namespace
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo
  namespace: builder
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tekton-builder-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: argo
    namespace: builder
YAML

cat > $COURSE_DIR/12/p1-team-onboarding/pipeline.yaml << 'YAML'
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: p1-create-namespace
  namespace: builder
spec:
  params:
    - name: ns-name
      type: string
  steps:
    - name: create
      image: alpine/kubectl:latest
      script: |
        echo "Creating namespace $(params.ns-name)..."
        kubectl create ns $(params.ns-name) --dry-run=client -o yaml | kubectl apply -f -
        until kubectl get sa default -n $(params.ns-name); do sleep 1; done
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: p1-create-roles
  namespace: builder
spec:
  params:
    - name: ns-name
      type: string
  steps:
    - name: create-role
      image: alpine/kubectl:latest
      script: |
        echo "Creating roles in namespace $(params.ns-name)..."
        kubectl create rolebinding view-access \
          --clusterrole=view \
          --serviceaccount=$(params.ns-name):default \
          -n $(params.ns-name) \
          --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: p1-team-onboarding
  namespace: builder
spec:
  params:
    - name: team-name
      type: string
  tasks:
    - name: create-namespace
      taskRef:
        name: p1-create-namespace
      params:
        - name: ns-name
          value: "team-$(params.team-name)"
    - name: create-roles
      taskRef:
        name: p1-create-roles
      runAfter:
        - create-namespace
      params:
        - name: ns-name
          value: "team-$(params.team-name)"
YAML

cat > $COURSE_DIR/12/p2-team-scanner/pipeline.yaml << 'YAML'
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: p2-scan
  namespace: builder
spec:
  params:
    - name: ns-name
      type: string
    - name: forbidden
      type: string
  steps:
    - name: scan
      image: alpine/kubectl:latest
      script: |
        echo "Scanning in namespace $(params.ns-name) for $(params.forbidden)..."
        kubectl get pods -n $(params.ns-name) -oyaml | grep $(params.forbidden) && \
        echo "Forbidden resource $(params.forbidden) found in namespace $(params.ns-name)! Alert sent" || \
        echo "No forbidden resources found in namespace $(params.ns-name)."
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: p2-team-scanner
  namespace: builder
spec:
  params:
    - name: team-name
      type: string
    - name: forbidden1
      type: string
    - name: forbidden2
      type: string
  tasks:
    - name: scan1
      taskRef:
        name: p2-scan
      params:
        - name: ns-name
          value: "team-$(params.team-name)"
        - name: forbidden
          value: "$(params.forbidden1)"
    - name: scan2
      taskRef:
        name: p2-scan
      params:
        - name: ns-name
          value: "team-$(params.team-name)"
        - name: forbidden
          value: "$(params.forbidden2)"
YAML

apply_with_retry() {
  local file=$1
  local attempts=20
  local i
  for i in $(seq 1 "$attempts"); do
    if kubectl apply -f "$file" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  kubectl apply -f "$file"
}

apply_with_retry "$COURSE_DIR/12/p1-team-onboarding/pipeline.yaml"
apply_with_retry "$COURSE_DIR/12/p2-team-scanner/pipeline.yaml"
mkdir -p $COURSE_DIR/12
touch $COURSE_DIR/12/p2.log

# Create team-bread namespace with a miner pod for scanning
kubectl create ns team-bread --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: suspicious-worker
  namespace: team-bread
spec:
  replicas: 1
  selector:
    matchLabels:
      app: suspicious-worker
  template:
    metadata:
      labels:
        app: suspicious-worker
    spec:
      containers:
        - name: miner
          image: busybox:1.36
          command: ["/bin/sh", "-c", "while true; do sleep 60; done"]
          env:
            - name: PROCESS
              value: miner
YAML

success "Q12 ready"
