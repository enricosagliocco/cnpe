#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-flagger-istio"
K8S_VERSION="v1.35.0"
ISTIO_VERSION="${ISTIO_VERSION:-1.26.2}"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }

GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_API="${GITEA_URL%/}/api/v1"
GITEA_OWNER="${GITEA_OWNER:-organization}"

ensure_istioctl() {
  if command -v istioctl >/dev/null 2>&1; then
    return 0
  fi

  info "Installing istioctl ${ISTIO_VERSION}"
  local tmpdir os arch package_url
  tmpdir="$(mktemp -d)"
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "Unsupported architecture for istioctl: $arch"; rm -rf "$tmpdir"; return 1 ;;
  esac

  package_url="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${os}-${arch}.tar.gz"
  if ! curl -fsSL "$package_url" -o "$tmpdir/istio.tgz"; then
    warn "Failed to download istioctl package"
    rm -rf "$tmpdir"
    return 1
  fi

  tar -xzf "$tmpdir/istio.tgz" -C "$tmpdir"

  if [[ -w /usr/local/bin ]]; then
    install -m 0755 "$tmpdir/istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
  else
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmpdir/istio-${ISTIO_VERSION}/bin/istioctl" "$HOME/.local/bin/istioctl"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
  fi

  rm -rf "$tmpdir"
}

gitea_available() {
  curl -fsS --connect-timeout 3 --max-time 5 -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" >/dev/null 2>&1
}

seed_git_repo_to_gitea() {
  local repo_path="$1"
  local repo_name="$2"
  local commit_message="$3"
  local status post_status push_base push_url

  git -C "$repo_path" init -b main >/dev/null 2>&1
  git -C "$repo_path" config user.name "CNPE Setup"
  git -C "$repo_path" config user.email "cnpe-setup@example.local"
  git -C "$repo_path" add .
  git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true

  if ! gitea_available; then
    warn "Gitea non raggiungibile, salto il push per ${repo_name}"
    return 0
  fi

  if [[ -z "$GITEA_OWNER" ]]; then
    if ! GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" | sed -n 's/.*"login":"\([^\"]*\)".*/\1/p' | head -n1)"; then
      warn "Impossibile risolvere l'owner Gitea, salto il push per ${repo_name}"
      return 0
    fi
  fi
  if [[ -z "$GITEA_OWNER" ]]; then
    warn "Unable to resolve Gitea owner, skipping push for ${repo_name}"
    return 0
  fi

  status="$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/repos/${GITEA_OWNER}/${repo_name}" || true)"
  if [[ "$status" != "200" ]]; then
    post_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" -d "{\"name\":\"${repo_name}\",\"private\":false,\"auto_init\":false}" "${GITEA_API}/orgs/${GITEA_OWNER}/repos" || true)"
    if [[ "$post_status" != "201" && "$post_status" != "409" ]]; then
      warn "Gitea repo create failed for ${repo_name} (HTTP ${post_status})"
      return 0
    fi
  fi

  push_base="${GITEA_URL%/}"
  push_url="${push_base/\/\//\/\/${GITEA_OWNER}:${GITEA_TOKEN}@}/${GITEA_OWNER}/${repo_name}.git"
  git -C "$repo_path" remote remove origin >/dev/null 2>&1 || true
  git -C "$repo_path" remote add origin "$push_url" >/dev/null 2>&1 || true
  git -C "$repo_path" push -u origin main --force >/dev/null 2>&1 || warn "Push to Gitea failed for ${repo_name}"
}

for cmd in minikube kubectl git curl docker jq helm; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERR] missing command: $cmd"; exit 1; }
done

ensure_istioctl || warn "istioctl install failed; Istio setup may fail"

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using ${COURSE_ROOT}"
fi

for i in $(seq 1 12); do
  mkdir -p "$COURSE_ROOT/$i"
done

info "Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true

info "Starting minikube profile ${PROFILE}"
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=12288 \
  --addons=ingress,metrics-server

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

info "Installing Istio (demo profile)"
istioctl install -y --set profile=demo >/dev/null
kubectl -n istio-system rollout status deploy/istiod --timeout=300s >/dev/null || warn "istiod not ready yet"
kubectl -n istio-system rollout status deploy/istio-ingressgateway --timeout=300s >/dev/null || warn "istio ingressgateway not ready yet"

kubectl create namespace flagger-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace flagger-lab istio-injection=enabled --overwrite >/dev/null

info "Installing Flagger for Istio"
if ! helm repo add flagger https://flagger.app --force-update >/dev/null 2>&1; then
  warn "Flagger helm repo add failed"
fi
if ! helm repo update >/dev/null 2>&1; then
  warn "Flagger helm repo update failed"
fi
if ! helm upgrade -i flagger flagger/flagger \
  --namespace istio-system \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus.istio-system:9090 \
  --wait \
  --timeout 10m >/dev/null 2>&1; then
  warn "Flagger helm install failed"
fi

kubectl -n istio-system rollout status deploy/flagger --timeout=300s >/dev/null || warn "flagger deployment not ready yet"

info "Installing Flagger loadtester"
if ! helm upgrade -i flagger-loadtester flagger/loadtester \
  --namespace flagger-lab \
  --wait \
  --timeout 5m >/dev/null 2>&1; then
  warn "Flagger loadtester install failed"
fi

mkdir -p "$COURSE_ROOT/2/repo-flagger-istio/apps/web"

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: flagger-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/svc.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: flagger-lab
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
YAML

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/hpa.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
  namespace: flagger-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
YAML

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/gateway.yaml" <<'YAML'
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: web-gateway
  namespace: flagger-lab
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - web.flagger.local
YAML

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: web
  namespace: flagger-lab
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: web
  progressDeadlineSeconds: 120
  service:
    port: 80
    gateways:
    - web-gateway
    hosts:
    - web.flagger.local
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      type: rollout
      url: http://flagger-loadtester.flagger-lab/
      timeout: 5s
      metadata:
        cmd: "hey -z 45s -q 10 -c 2 -host web.flagger.local http://istio-ingressgateway.istio-system/"
YAML

cat > "$COURSE_ROOT/2/repo-flagger-istio/apps/web/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
- svc.yaml
- hpa.yaml
- gateway.yaml
- canary.yaml
YAML

seed_git_repo_to_gitea "$COURSE_ROOT/2/repo-flagger-istio" "cnpe-specific-flagger-istio-repo" "init flagger istio repo"

cat > "$COURSE_ROOT/README-flagger-istio.txt" <<'TXT'
CNPE Batteria Specifica Flagger + Istio (app non instrumentata)

Namespace controller mesh: istio-system
Namespace laboratorio: flagger-lab

Repo seedato su Gitea:
- cnpe-specific-flagger-istio-repo

Working copy locale:
- /course/2/repo-flagger-istio

Nota:
- Il workload usa nginx senza metriche applicative esposte.
- Flagger usa metriche del service mesh Istio (Envoy/Prometheus).
TXT

ok "Setup batteria Flagger Istio completato"
echo "Course root: $COURSE_ROOT"
