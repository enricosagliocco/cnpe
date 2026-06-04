#!/usr/bin/env bash
# ============================================================
#  FluxCD Lab Setup  –  standalone
#  Copre: Kustomization, HelmRelease, Image Automation, OCI,
#         Notification/Alert, Receiver, multi-tenant, drift
#
#  Usage:
#    export GITEA_URL="http://192.168.1.56:3000/"
#    export GITEA_TOKEN="d2fcd54b7a8e2762920d929bfd4456db208659e4"
#    export GITEA_ORG="organization"
#    chmod +x setup-fluxcd-lab.sh && ./setup-fluxcd-lab.sh
# ============================================================
set -euo pipefail

export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"
GITEA_USER="cnpe-user"

# Use caller's home directory to avoid permission issues
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course/flux}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-cnpe}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-8192}"

# ── colours ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"; \
            echo -e "${BOLD}${GREEN}║  $*${NC}"; \
            echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}\n"; }

# ── helpers ────────────────────────────────────────────────
have_cmd()  { command -v "$1" &>/dev/null; }
as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

gitea_api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}

GITEA_AUTH_USER="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" 2>/dev/null \
  | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"
[ -n "${GITEA_AUTH_USER}" ] || GITEA_AUTH_USER="${GITEA_USER}"

ensure_org_repo() {
  local repo=$1 code
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${repo}")
  if [ "$code" = "200" ]; then return 0; fi
  gitea_api -X POST "${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos" \
    -d "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}" >/dev/null
}

build_auth_url() {
  local repo_path=$1
  case "${GITEA_URL}" in
    http://*)  echo "http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#http://}/${repo_path}" ;;
    https://*) echo "https://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#https://}/${repo_path}" ;;
    *)         echo "${GITEA_URL}/${repo_path}" ;;
  esac
}

git_push_dir() {
  local dir=$1 repo=$2
  ensure_org_repo "$repo"
  (
    cd "$dir"
    git init -b main 2>/dev/null || (git init && git checkout -b main 2>/dev/null || true)
    git config user.email "lab@cnpe.local"
    git config user.name "CNPE Lab"
    git add -A
    git commit -m "init: lab setup" --allow-empty 2>/dev/null || true
    local remote_url
    remote_url="$(build_auth_url "${GITEA_ORG}/${repo}.git")"
    git remote remove origin 2>/dev/null || true
    git remote add origin "$remote_url"
    git push -u origin main --force
  )
}

# ============================================================
section "0. Prerequisites"
# ============================================================
have_cmd kubectl  || die "kubectl not found"
have_cmd helm     || die "helm not found"
have_cmd git      || die "git not found"
have_cmd curl     || die "curl not found"
have_cmd minikube || die "minikube not found"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# flux CLI
if ! have_cmd flux; then
  info "Installing flux CLI..."
  curl -s https://fluxcd.io/install.sh | as_root bash
fi

# yq (needed for some manifest edits)
if ! have_cmd yq; then
  info "Installing yq..."
  curl -sSL "https://github.com/mikefarah/yq/releases/latest/download/yq_${OS}_${ARCH}" \
    -o /tmp/yq && chmod +x /tmp/yq && as_root mv /tmp/yq /usr/local/bin/yq
fi

success "Prerequisites OK (flux $(flux version --client 2>/dev/null | head -1))"

# ============================================================
section "0.5 Ensure Minikube"
# ============================================================
if minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\s*\"${MINIKUBE_PROFILE}\""; then
  info "Minikube profile '${MINIKUBE_PROFILE}' already exists"
else
  info "Creating Minikube profile '${MINIKUBE_PROFILE}' (${MINIKUBE_CPUS} CPUs / ${MINIKUBE_MEMORY}MB RAM)..."
  minikube start -p "${MINIKUBE_PROFILE}" --cpus="${MINIKUBE_CPUS}" --memory="${MINIKUBE_MEMORY}"
fi

if minikube -p "${MINIKUBE_PROFILE}" status 2>/dev/null | grep -q "host: Running"; then
  info "Minikube profile '${MINIKUBE_PROFILE}' is running"
else
  info "Starting existing Minikube profile '${MINIKUBE_PROFILE}'"
  minikube start -p "${MINIKUBE_PROFILE}"
fi

kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
success "Minikube ready (${MINIKUBE_PROFILE})"

# ============================================================
section "1. Namespaces"
# ============================================================
for ns in flux-system havel-west havel-east caribbean caribbean-oci; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
success "Namespaces ready"

# ============================================================
section "2. Install FluxCD"
# ============================================================
if ! kubectl get ns flux-system &>/dev/null || \
   ! kubectl -n flux-system get deploy kustomize-controller &>/dev/null; then
  info "Installing Flux controllers..."
  flux install \
    --components=source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller \
    2>/dev/null || \
  kubectl apply -f \
    https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
  kubectl -n flux-system wait deploy \
    --selector='app.kubernetes.io/part-of=flux' \
    --for=condition=Available --timeout=180s 2>/dev/null || true
else
  info "FluxCD already installed"
fi
success "FluxCD controllers ready"

# ============================================================
section "2.5 Flux Git auth (Gitea)"
# ============================================================
kubectl -n flux-system create secret generic gitea-auth \
  --from-literal=username="${GITEA_AUTH_USER}" \
  --from-literal=password="${GITEA_TOKEN}" \
  --type=kubernetes.io/basic-auth \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
success "Flux Git auth secret ready (flux-system/gitea-auth)"

# ============================================================
section "3. Q1 + Q2 – havel-west and havel-east repos"
# ============================================================
mkdir -p "$COURSE_DIR/havel-west" "$COURSE_DIR/havel-east"

# ── havel-west manifests ────────────────────────────────────
cat > "$COURSE_DIR/havel-west/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logger
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command: ["/bin/sh", "-c", "while true; do echo log; sleep 5; done"]
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
YAML

cat > "$COURSE_DIR/havel-west/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: logger-config
data:
  log-format: json
  log-level: info
  retention-days: "30"
YAML

cat > "$COURSE_DIR/havel-west/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - configmap.yaml
YAML

# ── havel-east manifests ────────────────────────────────────
cat > "$COURSE_DIR/havel-east/statefulset.yaml" <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cache
spec:
  serviceName: cache
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: cache
          image: redis:7-alpine
          resources:
            requests:
              cpu: 10m
              memory: 20Mi
YAML

cat > "$COURSE_DIR/havel-east/secret-api.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
type: Opaque
stringData:
  api-key: "placeholder-api-key"
YAML

cat > "$COURSE_DIR/havel-east/secret-db.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  password: "placeholder-db-pass"
YAML

cat > "$COURSE_DIR/havel-east/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - statefulset.yaml
  - secret-api.yaml
  - secret-db.yaml
YAML

# Push to Gitea
git_push_dir "$COURSE_DIR/havel-west" "havel-west"
git_push_dir "$COURSE_DIR/havel-east" "havel-east"

HW_URL="${GITEA_URL}/${GITEA_ORG}/havel-west.git"
HE_URL="${GITEA_URL}/${GITEA_ORG}/havel-east.git"

# ── Flux GitRepository + Kustomization: havel-west ──────────
kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: havel-west
  namespace: flux-system
spec:
  interval: 1m
  url: ${HW_URL}
  secretRef:
    name: gitea-auth
  ref:
    branch: main
YAML

kubectl apply -f - <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: havel-west
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: havel-west
  path: ./
  prune: true
  targetNamespace: havel-west
  suspend: false
YAML

# Wait for initial sync, then introduce drift and suspend (Q1 scenario)
info "Waiting 25s for havel-west initial sync..."
sleep 25

kubectl -n havel-west scale deploy logger --replicas=2 2>/dev/null || true
kubectl -n havel-west patch cm logger-config \
  --type merge -p '{"data":{"log-level":"debug"}}' 2>/dev/null || true

# Suspend – candidate must resume it (Q1)
kubectl -n flux-system patch kustomization havel-west \
  --type merge -p '{"spec":{"suspend":true}}'
info "havel-west Kustomization suspended with drift – candidate must resume (Q1)"

# havel-east GitRepository only, no Kustomization yet (Q2 task)
kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: havel-east
  namespace: flux-system
spec:
  interval: 1m
  url: ${HE_URL}
  secretRef:
    name: gitea-auth
  ref:
    branch: main
YAML
info "havel-east GitRepository created – candidate must create the Kustomization (Q2)"

success "Q1 + Q2 ready"

# ============================================================
section "4. Q3 + Q4 – HelmRelease podinfo"
# ============================================================
# HelmRepository + basic HelmRelease are NOT pre-created – candidate creates them.
# We only create the namespace and a Secret for Q4.

kubectl create ns caribbean --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: podinfo-secret
  namespace: flux-system
type: Opaque
stringData:
  api-key: "super-secret-token-42"
YAML

info "Q3: candidate must create HelmRepository + HelmRelease for podinfo in caribbean"
info "Q4: podinfo-secret is ready in flux-system; candidate must wire valuesFrom"
success "Q3 + Q4 scaffolding ready"

# ============================================================
section "5. Q5 – Dependency ordering: infra-certs -> infra-ingress"
# ============================================================
mkdir -p "$COURSE_DIR/q5/infra-certs" "$COURSE_DIR/q5/infra-ingress"

# infra-certs: a trivial ConfigMap
cat > "$COURSE_DIR/q5/infra-certs/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ca-bundle
  namespace: havel-west
data:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIFAKE...
    -----END CERTIFICATE-----
YAML
cat > "$COURSE_DIR/q5/infra-certs/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
YAML

# infra-ingress: depends on infra-certs in Git sense only; Flux dep is the task
cat > "$COURSE_DIR/q5/infra-ingress/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-config
  namespace: havel-west
data:
  tls-enabled: "true"
YAML
cat > "$COURSE_DIR/q5/infra-ingress/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
YAML

git_push_dir "$COURSE_DIR/q5/infra-certs"   "infra-certs"
git_push_dir "$COURSE_DIR/q5/infra-ingress" "infra-ingress"

CERTS_URL="${GITEA_URL}/${GITEA_ORG}/infra-certs.git"
INGRESS_URL="${GITEA_URL}/${GITEA_ORG}/infra-ingress.git"

kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infra-certs
  namespace: flux-system
spec:
  interval: 1m
  url: ${CERTS_URL}
  secretRef:
    name: gitea-auth
  ref:
    branch: main
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: infra-ingress
  namespace: flux-system
spec:
  interval: 1m
  url: ${INGRESS_URL}
  secretRef:
    name: gitea-auth
  ref:
    branch: main
YAML

# Both Kustomizations WITHOUT dependsOn – candidate adds it (Q5)
kubectl apply -f - <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infra-certs
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: infra-certs
  path: ./
  prune: true
  targetNamespace: havel-west
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infra-ingress
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: infra-ingress
  path: ./
  prune: true
  targetNamespace: havel-west
YAML

info "Q5: candidate must add dependsOn to infra-ingress and test with suspend/resume"
success "Q5 ready"

# ============================================================
section "6. Q6 – Image Automation scaffolding"
# ============================================================
# ImageRepository, ImagePolicy, ImageUpdateAutomation – NOT pre-created (candidate's task).
# We only annotate a note in the course dir.
mkdir -p "$COURSE_DIR/q6"
cat > "$COURSE_DIR/q6/README.txt" <<'EOF'
Image Automation task (Q6):
- Observe docker.io/library/busybox
- Create ImageRepository, ImagePolicy (semver 1.x)
- Annotate havel-west/deployment.yaml
- Create ImageUpdateAutomation for havel-west repo
EOF
success "Q6 scaffolding ready"

# ============================================================
section "7. Q7 – OCI Repository (no secret needed for public ghcr.io)"
# ============================================================
kubectl create ns caribbean-oci --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# OCIRepository + HelmRelease NOT pre-created – candidate's task
mkdir -p "$COURSE_DIR/q7"
cat > "$COURSE_DIR/q7/README.txt" <<'EOF'
OCI task (Q7):
- Create OCIRepository for oci://ghcr.io/stefanprodan/charts/podinfo tag 6.7.0
- Create HelmRelease podinfo-oci in caribbean-oci using that OCIRepository
EOF
success "Q7 scaffolding ready"

# ============================================================
section "8. Q8 – Notification: fake webhook receiver"
# ============================================================
# Deploy a simple echo server as the webhook target
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-receiver
  namespace: flux-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook-receiver
  template:
    metadata:
      labels:
        app: webhook-receiver
    spec:
      containers:
        - name: receiver
          image: hashicorp/http-echo:latest
          args:
            - "-text=webhook-received"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: webhook-receiver
  namespace: flux-system
spec:
  selector:
    app: webhook-receiver
  ports:
    - port: 80
      targetPort: 8080
YAML

info "Q8: candidate must create Provider + Alert for Kustomization error events"
success "Q8 scaffolding ready"

# ============================================================
section "9. Q9 – Receiver for Git webhook"
# ============================================================
# No pre-creation; candidate creates Secret + Receiver + NodePort Service
mkdir -p "$COURSE_DIR/q9"
cat > "$COURSE_DIR/q9/README.txt" <<'EOF'
Receiver task (Q9):
- Create Secret gitea-webhook-token
- Create Receiver gitea-receiver (type: generic) targeting GitRepository/havel-west
- Expose via NodePort 30095
- Save endpoint URL to /course/flux/q9-receiver-url.txt
EOF
success "Q9 scaffolding ready"

# ============================================================
section "10. Q10 – Multi-tenant ServiceAccount for havel-east"
# ============================================================
# Candidate must create SA, Role, RoleBinding and patch the Kustomization
info "Q10: candidate must create RBAC + patch havel-east Kustomization"
success "Q10 scaffolding ready"

# ============================================================
section "11. Q11 – Broken StatefulSet (readinessProbe)"
# ============================================================
mkdir -p "$COURSE_DIR/q11"

# Create a broken havel-east variant
cat > "$COURSE_DIR/q11/statefulset.yaml" <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cache-broken
  namespace: havel-east
spec:
  serviceName: cache-broken
  replicas: 1
  selector:
    matchLabels:
      app: cache-broken
  template:
    metadata:
      labels:
        app: cache-broken
    spec:
      containers:
        - name: cache
          image: redis:7-alpine
          readinessProbe:
            httpGet:
              path: /healthz    # Redis doesn't have an HTTP healthz – intentionally wrong
              port: 6379
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: 10m
              memory: 20Mi
YAML

cat > "$COURSE_DIR/q11/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - statefulset.yaml
YAML

git_push_dir "$COURSE_DIR/q11" "q11-broken"

Q11_URL="${GITEA_URL}/${GITEA_ORG}/q11-broken.git"

kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: q11-broken
  namespace: flux-system
spec:
  interval: 1m
  url: ${Q11_URL}
  secretRef:
    name: gitea-auth
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q11-broken
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: q11-broken
  path: ./
  prune: true
  healthChecks:
    - apiVersion: apps/v1
      kind: StatefulSet
      name: cache-broken
      namespace: havel-east
  timeout: 2m
YAML

info "Q11: cache-broken StatefulSet has a wrong readinessProbe – will fail health check"
success "Q11 ready"

# ============================================================
section "12. Q12 – Kustomize patches inline"
# ============================================================
# havel-west Kustomization is already deployed (replicas: 1).
# Candidate must add a patches block to the Flux Kustomization to override to 3.
info "Q12: candidate must add spec.patches to havel-west Kustomization (replicas 1→3)"
success "Q12 scaffolding ready"

# ============================================================
section "Final summary"
# ============================================================
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  FluxCD Lab – Task map${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "  Q1   Resume havel-west Kustomization + fix drift"
echo -e "  Q2   Create Kustomization for havel-east"
echo -e "  Q3   Create HelmRepository + HelmRelease (podinfo) in caribbean"
echo -e "  Q4   Add valuesFrom (ConfigMap + Secret) to HelmRelease"
echo -e "  Q5   Add dependsOn: infra-ingress waits for infra-certs"
echo -e "  Q6   Image Automation for busybox in havel-west"
echo -e "  Q7   OCIRepository + HelmRelease in caribbean-oci"
echo -e "  Q8   Provider + Alert for Kustomization error events"
echo -e "  Q9   Receiver (generic) + NodePort 30095 for Git webhook"
echo -e "  Q10  Multi-tenant RBAC + serviceAccountName in havel-east Kustomization"
echo -e "  Q11  Fix broken readinessProbe in q11-broken (health check timeout)"
echo -e "  Q12  Inline patches in Flux Kustomization (replicas 1→3)"
echo -e ""
echo -e "  Course dir : ${COURSE_DIR}"
echo -e "  Gitea      : ${GITEA_URL}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}FluxCD lab setup complete!${NC}"
