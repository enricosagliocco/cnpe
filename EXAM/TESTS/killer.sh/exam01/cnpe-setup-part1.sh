#!/usr/bin/env bash
# ============================================================
# CNPE Lab Setup - Part 1: Base infra + Q1-Q5
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

# ── colours ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

# ── helpers ────────────────────────────────────────────────
require_cmd() { command -v "$1" &>/dev/null || die "Required: $1"; }
have_cmd() { command -v "$1" &>/dev/null; }
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}
install_binary_file() {
  local name=$1
  local url=$2
  local tmp_file
  tmp_file="/tmp/${name}-dl"

  info "Installing ${name} ..."
  curl -fsSL "$url" -o "$tmp_file"
  chmod +x "$tmp_file"
  as_root mv "$tmp_file" "/usr/local/bin/${name}"
  success "${name} installed"
}
install_pkg() {
  local pkg=$1
  if have_cmd dnf; then
    as_root dnf -y install "$pkg"
  elif have_cmd apt-get; then
    as_root apt-get update
    as_root apt-get -y install "$pkg"
  else
    die "Cannot install package '${pkg}': unsupported package manager"
  fi
}
ensure_base_cli() {
  local os arch k8s_ver
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"

  # Ensure common install path is visible in non-login shells.
  export PATH="/usr/local/bin:/usr/bin:/bin:${PATH}"

  if ! have_cmd curl; then
    info "curl not found; installing"
    install_pkg curl
  fi
  if ! have_cmd git; then
    info "git not found; installing"
    install_pkg git
  fi
  if ! have_cmd jq; then
    info "jq not found; installing"
    install_pkg jq
  fi

  if ! have_cmd kubectl; then
    info "kubectl not found; installing"
    k8s_ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    install_binary_file kubectl "https://dl.k8s.io/release/${k8s_ver}/bin/${os}/${arch}/kubectl"
  fi

  if ! have_cmd helm; then
    info "helm not found; installing"
    if ! curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | as_root bash; then
      warn "Helm installer returned non-zero exit code; verifying binary presence"
    fi
    hash -r 2>/dev/null || true
    if ! have_cmd helm && [ -x /usr/local/bin/helm ]; then
      export PATH="/usr/local/bin:${PATH}"
      hash -r 2>/dev/null || true
    fi
    have_cmd helm || die "Helm install failed: helm not found in PATH"
    success "helm installed"
  fi

  if ! have_cmd minikube; then
    info "minikube not found; installing"
    install_binary_file minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-${os}-${arch}"
  fi
}
wait_pod() {
  local ns=$1 label=$2
  info "Waiting for pods -n $ns -l $label ..."
  kubectl wait pod -n "$ns" -l "$label" \
    --for=condition=Ready --timeout=300s 2>/dev/null || true
}
gitea_api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}
gitea_create_repo() {
  local repo=$1
  gitea_api -X POST "${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos" \
    -d "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}" \
    | grep -q '"id"' || warn "Repo ${repo} may already exist"
}

# ============================================================
section "0. Prerequisites"
# ============================================================
ensure_base_cli
require_cmd minikube
require_cmd kubectl
require_cmd helm
require_cmd git
require_cmd curl
require_cmd jq

# ============================================================
section "0.1 Install CLI tools"
# ============================================================

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

install_binary() {
  local name=$1
  local url=$2
  local dest="/usr/local/bin/${name}"
  if ! command -v "$name" &>/dev/null; then
    info "Installing $name ..."
    curl -sSL "$url" -o /tmp/"${name}-dl"
    chmod +x /tmp/"${name}-dl"
    as_root mv /tmp/"${name}-dl" "$dest"
    success "$name installed"
  else
    info "$name already present"
  fi
}

# flux CLI
if ! command -v flux &>/dev/null; then
  info "Installing flux CLI ..."
  curl -s https://fluxcd.io/install.sh | as_root bash
fi

# argocd CLI
ARGOCD_VER=$(curl -sL https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
install_binary argocd \
  "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VER}/argocd-${OS}-${ARCH}"

# argo workflows CLI
ARGO_WF_VER="v3.5.7"
install_binary argo \
  "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WF_VER}/argo-${OS}-${ARCH}.gz" || true
if ! command -v argo &>/dev/null; then
  curl -sSL "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WF_VER}/argo-${OS}-${ARCH}.gz" \
    | gunzip > /tmp/argo-bin
  chmod +x /tmp/argo-bin && as_root mv /tmp/argo-bin /usr/local/bin/argo
fi

# tekton tkn CLI
TKN_VER="0.37.0"
if ! command -v tkn &>/dev/null; then
  info "Installing tkn ..."
  curl -sSL "https://github.com/tektoncd/cli/releases/download/v${TKN_VER}/tkn_${TKN_VER}_Linux_x86_64.tar.gz" \
    | tar xz -C /tmp tkn
  as_root mv /tmp/tkn /usr/local/bin/tkn
fi

# kyverno CLI
if ! command -v kyverno &>/dev/null; then
  KY_VER=$(curl -sL https://api.github.com/repos/kyverno/kyverno/releases/latest | jq -r .tag_name)
  install_binary kyverno \
    "https://github.com/kyverno/kyverno/releases/download/${KY_VER}/kyverno-cli_${KY_VER}_${OS}_${ARCH}.tar.gz" || true
  curl -sSL "https://github.com/kyverno/kyverno/releases/download/${KY_VER}/kyverno-cli_${KY_VER}_${OS}_${ARCH}.tar.gz" \
    | tar xz -C /tmp kyverno 2>/dev/null || true
  [ -f /tmp/kyverno ] && as_root mv /tmp/kyverno /usr/local/bin/kyverno || true
fi

# yq
if ! command -v yq &>/dev/null; then
  install_binary yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_${OS}_${ARCH}"
fi

# tofu (OpenTofu)
if ! command -v tofu &>/dev/null; then
  info "Installing OpenTofu ..."
  TOFU_VER="${TOFU_VER:-1.8.3}"
  if have_cmd dnf; then
    curl -sSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VER}/tofu_${TOFU_VER}_${OS}_${ARCH}.tar.gz" \
      | tar xz -C /tmp tofu
    as_root mv /tmp/tofu /usr/local/bin/tofu
  elif have_cmd apt-get; then
    curl -sSL https://get.opentofu.org/install-opentofu.sh | as_root bash -s -- --install-method deb || \
    (curl -sSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VER}/tofu_${TOFU_VER}_${OS}_${ARCH}.tar.gz" \
      | tar xz -C /tmp tofu && as_root mv /tmp/tofu /usr/local/bin/tofu)
  else
    curl -sSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VER}/tofu_${TOFU_VER}_${OS}_${ARCH}.tar.gz" \
      | tar xz -C /tmp tofu
    as_root mv /tmp/tofu /usr/local/bin/tofu
  fi
fi

# kubectl cost plugin
if ! kubectl cost --help &>/dev/null 2>&1; then
  OS2=$(uname -s); ARCH2=$(uname -m)
  curl -sSL "https://github.com/kubecost/kubectl-cost/releases/latest/download/kubectl-cost-${OS2}-${ARCH2}.tar.gz" \
    | tar xz -C /tmp 2>/dev/null || true
  [ -f /tmp/kubectl-cost ] && as_root mv /tmp/kubectl-cost /usr/local/bin/ || true
fi

success "CLI tools ready"

# ============================================================
section "0.2 Start Minikube"
# ============================================================
if ! minikube status | grep -q "Running" 2>/dev/null; then
  info "Starting minikube with 4 CPUs / 20GB RAM ..."
  minikube start \
    --cpus=4 \
    --memory=20480 \
    --disk-size=60g \
    --kubernetes-version=v1.31.0 \
    --addons=metrics-server \
    --driver=docker
else
  info "Minikube already running"
fi

# alias k
kubectl() { command kubectl "$@"; }
alias k=kubectl
export KUBECONFIG=$(minikube kubeconfig --no-env 2>/dev/null || echo ~/.kube/config)

# enable ingress
minikube addons enable ingress 2>/dev/null || true

success "Minikube ready"

# ============================================================
section "0.3 Create base Namespaces"
# ============================================================
for ns in \
  pacific kariba lagoon lagoon-testing malawi planet-apps baikal \
  atlantic arctic-workload opencost prometheus eyre ammersee-legacy \
  saltlake-app danau builder havel-west havel-east caribbean \
  sargasso caspian-pipeline1 caspian-pipeline2 caspian-pipeline3 \
  argo kaw flux-system baltic; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
success "Namespaces created"

# ============================================================
section "0.4 Gitea - ensure user & git config"
# ============================================================
# Ensure gitea user exists
gitea_api -X GET "${GITEA_URL}/api/v1/users/${GITEA_USER}" | grep -q '"id"' || \
  gitea_api -X POST "${GITEA_URL}/api/v1/admin/users" \
    -d "{\"username\":\"${GITEA_USER}\",\"password\":\"${GITEA_PASS}\",\"email\":\"cnpe@lab.local\",\"must_change_password\":false}" \
    >/dev/null 2>&1 || true

# Configure git globally
git config --global user.email "cnpe-user@simulator" 2>/dev/null || true
git config --global user.name "CNPE User" 2>/dev/null || true
git config --global credential.helper "store" 2>/dev/null || true
GITEA_AUTH_USER="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" 2>/dev/null | jq -r '.login // empty' || true)"
[ -n "${GITEA_AUTH_USER}" ] || GITEA_AUTH_USER="${GITEA_USER}"
echo "${GITEA_URL/http:\/\//http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@}" > ~/.git-credentials 2>/dev/null || true

# Helper: push local dir to gitea
push_to_gitea() {
  local repo=$1 dir=$2
  gitea_create_repo "$repo"
  (
    cd "$dir"
    git init -b main 2>/dev/null || git init
    git checkout -b main 2>/dev/null || true
    git add -A
    git commit -m "init of project" --allow-empty 2>/dev/null || true
    REMOTE_URL="${GITEA_URL/http:\/\//http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@}/${GITEA_ORG}/${repo}.git"
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REMOTE_URL"
    git push -u origin main --force
  )
}

# ============================================================
section "1. Q1 – Operator Pattern, CRD, Kustomize, Git"
# ============================================================
mkdir -p "$COURSE_DIR/1/team-monitoring"
cat > "$COURSE_DIR/1/team-monitoring/crd.yaml" << 'YAML'
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
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
                target:
                  type: string
                  description: Target service to monitor
            status:
              type: object
YAML

cat > "$COURSE_DIR/1/team-monitoring/kustomization.yaml" << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - crd.yaml
YAML

cat > "$COURSE_DIR/1/team-monitoring/README.md" << 'EOF'
# team-monitoring
CRD for TeamMonitoring custom resource.
EOF

kubectl apply -k "$COURSE_DIR/1/team-monitoring/"
kubectl create ns pacific --dry-run=client -o yaml | kubectl apply -f - >/dev/null

push_to_gitea "team-monitoring" "$COURSE_DIR/1/team-monitoring"
success "Q1 ready"

# ============================================================
section "2. Q2 – Prometheus (standalone)"
# ============================================================
# Deploy Prometheus via ConfigMap + StatefulSet on NodePort 30020
kubectl create ns prometheus --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Application Pods in kariba
for app in frontend backend; do
kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: kariba
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          env:
            - name: APP_NAME
              value: "$app"
          command: ["/bin/sh", "-c"]
          args:
            - |
              cat >/tmp/metrics-server.py <<'PY'
              import os
              from http.server import BaseHTTPRequestHandler, HTTPServer

              app = os.getenv("APP_NAME", "app")
              values = {"frontend": 180, "backend": 130, "proxy": 90}
              value = values.get(app, 50)

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      if self.path != "/metrics":
                          self.send_response(404)
                          self.end_headers()
                          return
                      body = (
                          "# HELP http_requests_per_minute Simulated request rate\\n"
                          "# TYPE http_requests_per_minute gauge\\n"
                          f"http_requests_per_minute{{deployment=\"{app}\"}} {value}\\n"
                      )
                      payload = body.encode("utf-8")
                      self.send_response(200)
                      self.send_header("Content-Type", "text/plain; version=0.0.4")
                      self.send_header("Content-Length", str(len(payload)))
                      self.end_headers()
                      self.wfile.write(payload)

                  def log_message(self, fmt, *args):
                      return

              HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
              PY
              python /tmp/metrics-server.py
          ports:
            - containerPort: 8080
YAML
done

# Prometheus ConfigMap
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server
  namespace: prometheus
data:
  prometheus.rules: 'groups: []'
  prometheus.yml: |
    global:
      scrape_interval: 10s
      evaluation_interval: 10s
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers: []
    scrape_configs:
      - job_name: 'minimal'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: ['kariba']
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            regex: (frontend|backend)
            action: keep
          - source_labels: [__meta_kubernetes_pod_ip]
            target_label: __address__
            replacement: $1:8080
          - target_label: __metrics_path__
            replacement: /metrics
YAML

# Prometheus RBAC
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: [""]
    resources: [nodes, nodes/proxy, services, endpoints, pods]
    verbs: [get, list, watch]
  - nonResourceURLs: [/metrics]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: prometheus
YAML

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus-server
  namespace: prometheus
spec:
  serviceName: prometheus-server
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --web.enable-lifecycle
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-server
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-server
  namespace: prometheus
spec:
  type: NodePort
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30020
YAML

# Fake metric-exporting pods for kariba (proxy)
kubectl apply -f - <<'YAML'
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
          image: python:3.12-alpine
          env:
            - name: APP_NAME
              value: proxy
          command: ["/bin/sh", "-c"]
          args:
            - |
              cat >/tmp/metrics-server.py <<'PY'
              import os
              from http.server import BaseHTTPRequestHandler, HTTPServer

              app = os.getenv("APP_NAME", "app")
              values = {"frontend": 180, "backend": 130, "proxy": 90}
              value = values.get(app, 50)

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      if self.path != "/metrics":
                          self.send_response(404)
                          self.end_headers()
                          return
                      body = (
                          "# HELP http_requests_per_minute Simulated request rate\\n"
                          "# TYPE http_requests_per_minute gauge\\n"
                          f"http_requests_per_minute{{deployment=\"{app}\"}} {value}\\n"
                      )
                      payload = body.encode("utf-8")
                      self.send_response(200)
                      self.send_header("Content-Type", "text/plain; version=0.0.4")
                      self.send_header("Content-Length", str(len(payload)))
                      self.end_headers()
                      self.wfile.write(payload)

                  def log_message(self, fmt, *args):
                      return

              HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
              PY
              python /tmp/metrics-server.py
          ports:
            - containerPort: 8080
YAML

success "Q2 ready"

# ============================================================
section "3. Q3 – Argo CD"
# ============================================================
# Install Argo CD
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if ! kubectl get deploy -n argocd argocd-server >/dev/null 2>&1; then
  # Use create (not apply) to avoid oversized last-applied annotation on CRDs.
  kubectl create -n argocd -f \
    https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
  info "Argo CD already present, skipping create"
fi
wait_pod argocd "app.kubernetes.io/name=argocd-server"

# Expose on NodePort 30030
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30030,"protocol":"TCP","name":"https"}]}}'

# Set admin password to "admin"
BCRYPT='$2a$10$mivhwttXM0U5Os27RNNpkuigLMpmVqgFbGOYN4BJ5QiNPjLt0X.jm'
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\":{\"admin.password\":\"${BCRYPT}\",\"admin.passwordMtime\":\"$(date +%FT%T%Z)\"}}"

# Create AppProject lagoon
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: lagoon
  namespace: argocd
spec:
  description: Lagoon project
  sourceRepos:
    - '*'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
YAML

# web-client git repo
mkdir -p "$COURSE_DIR/3/web-client/manifests"
cat > "$COURSE_DIR/3/web-client/manifests/web-client.yaml" << 'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-client
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 80;
        location / {
          return 200 'Lagoon Web Client v1';
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
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
          image: nginx:1-alpine
          volumeMounts:
            - name: web-client
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: web-client
          configMap:
            name: web-client
---
apiVersion: v1
kind: Service
metadata:
  name: web-client
spec:
  selector:
    app: web-client
  ports:
    - port: 80
      targetPort: 80
YAML

push_to_gitea "web-client" "$COURSE_DIR/3/web-client"

# ArgoCD Application web-client
REMOTE_URL="${GITEA_URL}/${GITEA_ORG}/web-client.git"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-client
  namespace: argocd
spec:
  destination:
    namespace: lagoon
    server: https://kubernetes.default.svc
  project: lagoon
  source:
    path: manifests
    repoURL: ${REMOTE_URL}
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

success "Q3 ready"

# ============================================================
section "4. Q4 – Flagger"
# ============================================================
# Install Flagger CRDs + controller (kubernetes provider, no mesh)
helm repo add flagger https://flagger.app 2>/dev/null || true
helm repo update

# Create CRDs once; Helm install below skips CRDs to avoid apply conflicts.
if ! kubectl get crd canaries.flagger.app >/dev/null 2>&1; then
  kubectl create -f \
    https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
else
  info "Flagger CRDs already present, skipping create"
fi

helm upgrade --install flagger flagger/flagger \
  --namespace=flagger-system \
  --create-namespace \
  --skip-crds \
  --set meshProvider=kubernetes \
  --set metricsServer=http://prometheus-server.prometheus:9090 \
  --wait --timeout=180s 2>/dev/null || \
helm upgrade --install flagger flagger/flagger \
  --namespace=flagger-system \
  --create-namespace \
  --skip-crds \
  --set meshProvider=kubernetes \
  --wait --timeout=180s

mkdir -p "$COURSE_DIR/4"

# app1 – version 5.3.8
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: malawi
spec:
  replicas: 0
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
          image: httpd:2-alpine
          command: ["/bin/sh","-c"]
          args:
            - |
              echo "app1 version ${APP_VERSION}" > /usr/local/apache2/htdocs/index.html;
              httpd-foreground
          env:
            - name: APP_VERSION
              value: "5.3.8"
---
apiVersion: v1
kind: Service
metadata:
  name: app1-expose
  namespace: malawi
spec:
  type: NodePort
  selector:
    app: app1
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30041
YAML

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: malawi
spec:
  replicas: 0
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
          image: httpd:2-alpine
          command: ["/bin/sh","-c"]
          args:
            - |
              echo "app2 version ${APP_VERSION}" > /usr/local/apache2/htdocs/index.html;
              httpd-foreground
          env:
            - name: APP_VERSION
              value: "1.0.0"
---
apiVersion: v1
kind: Service
metadata:
  name: app2-expose
  namespace: malawi
spec:
  type: NodePort
  selector:
    app: app2
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30042
YAML

# Flagger Canary resources
kubectl apply -f - <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: app1
  namespace: malawi
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app1
  service:
    port: 80
    portDiscovery: true
  analysis:
    interval: 5s
    iterations: 2
    metrics: []
    threshold: 10
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: app2
  namespace: malawi
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app2
  service:
    port: 80
    portDiscovery: true
  analysis:
    interval: 5s
    iterations: 2
    metrics: []
    threshold: 10
YAML

success "Q4 ready"

# ============================================================
section "5. Q5 – OPA Gatekeeper + Helm"
# ============================================================
# Install Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --wait --timeout=240s

mkdir -p "$COURSE_DIR/5/infra-opa"

cat > "$COURSE_DIR/5/infra-opa/constraint_template.yaml" << 'YAML'
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
          not input.review.object.metadata.labels.TODO
          msg := "Pod is missing required label: TODO"
        }

        violation[{"msg": msg}] {
          input.review.kind.kind == "Deployment"
          replicas := input.review.object.spec.replicas
          replicas < 10
          msg := sprintf("Deployment requires at least TODO replicas, found %v", [replicas])
        }
YAML

cat > "$COURSE_DIR/5/infra-opa/constraint.yaml" << 'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PlanetAppConstraint
metadata:
  name: planet-app-constraint
spec:
  match:
    namespaces:
      - TODO_NAMESPACE
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
YAML

# Helm charts – app-earth, app-venus, app-saturn
for APP in app-earth app-venus app-saturn; do
  VERSION="1.10.4"
  [ "$APP" = "app-saturn" ] && VERSION="1.0.1"
  [ "$APP" = "app-venus" ] && VERSION="1.10.2"

  mkdir -p "$COURSE_DIR/5/${APP}/templates"
  cat > "$COURSE_DIR/5/${APP}/Chart.yaml" << YAML
apiVersion: v2
name: ${APP}-chart
description: Minimal application chart
type: application
version: ${VERSION}
YAML
  cat > "$COURSE_DIR/5/${APP}/values.yaml" << 'YAML'
replicaCount: 2
image:
  repository: nginx
  tag: 1-alpine
YAML

  PLANET=${APP#app-}
  cat > "$COURSE_DIR/5/${APP}/templates/app.yaml" << YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${APP}
  template:
    metadata:
      labels:
        planet: ${PLANET}
        app: ${APP}
    spec:
      containers:
        - image: nginx:1-alpine
          name: app
          resources:
            requests:
              cpu: 20m
              memory: 20Mi
YAML
done

# Install all three charts into planet-apps
for APP in app-earth app-venus app-saturn; do
  helm upgrade --install "$APP" "$COURSE_DIR/5/${APP}" \
    --namespace planet-apps --create-namespace 2>/dev/null || true
done

success "Q5 ready"
