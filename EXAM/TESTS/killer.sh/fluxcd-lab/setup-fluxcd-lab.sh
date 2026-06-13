#!/usr/bin/env bash
set -euo pipefail

FLUX_VERSION="${FLUX_VERSION:-v2.8.8}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-fluxcd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-fluxcd-lab}"

export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"

GIT_REPO_NAME="${GIT_REPO_NAME:-flux-platform}"
GIT_REPO_URL="${GITEA_URL}/${GITEA_ORG}/${GIT_REPO_NAME}.git"

HEADLAMP_REPO_URL="https://kubernetes-sigs.github.io/headlamp/"
METRICS_SERVER_REPO_URL="https://kubernetes-sigs.github.io/metrics-server/"
PROMETHEUS_REPO_URL="https://prometheus-community.github.io/helm-charts"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

gitea_status() {
  local method=$1 path=$2 data=${3:-}
  local args=(
    -sS -o /dev/null -w "%{http_code}" -X "$method"
    -H "Authorization: token ${GITEA_TOKEN}"
    -H "Content-Type: application/json"
  )
  [ -z "$data" ] || args+=(-d "$data")
  curl "${args[@]}" "${GITEA_URL}${path}"
}

ensure_gitea_org() {
  local code
  code="$(gitea_status GET "/api/v1/orgs/${GITEA_ORG}")"
  if [ "$code" != "200" ]; then
    code="$(gitea_status POST "/api/v1/orgs" \
      "{\"username\":\"${GITEA_ORG}\",\"full_name\":\"${GITEA_ORG}\"}")"
    [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "409" ] ||
      die "Cannot create/access Gitea organization ${GITEA_ORG} (HTTP ${code})"
  fi
}

ensure_gitea_repo() {
  local code
  code="$(gitea_status GET "/api/v1/repos/${GITEA_ORG}/${GIT_REPO_NAME}")"
  if [ "$code" != "200" ]; then
    code="$(gitea_status POST "/api/v1/orgs/${GITEA_ORG}/repos" \
      "{\"name\":\"${GIT_REPO_NAME}\",\"private\":false,\"auto_init\":false}")"
    [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "409" ] ||
      die "Cannot create/access Gitea repository ${GITEA_ORG}/${GIT_REPO_NAME} (HTTP ${code})"
  fi
}

gitea_authenticated_url() {
  local login
  login="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/user" |
    sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [ -n "$login" ] || die "Cannot determine the Gitea user for GITEA_TOKEN"
  case "$GITEA_URL" in
    http://*) printf 'http://%s:%s@%s/%s/%s.git\n' \
      "$login" "$GITEA_TOKEN" "${GITEA_URL#http://}" \
      "$GITEA_ORG" "$GIT_REPO_NAME" ;;
    https://*) printf 'https://%s:%s@%s/%s/%s.git\n' \
      "$login" "$GITEA_TOKEN" "${GITEA_URL#https://}" \
      "$GITEA_ORG" "$GIT_REPO_NAME" ;;
    *) die "GITEA_URL must start with http:// or https://" ;;
  esac
}

prepare_gitea_repository() {
  local directory auth_url
  directory="$(mktemp -d)"
  trap 'rm -rf "$directory"' RETURN
  mkdir -p \
    "$directory/apps/catalog" \
    "$directory/apps/web/base" \
    "$directory/apps/web/overlays/dev" \
    "$directory/apps/web/overlays/prod" \
    "$directory/apps/substitution" \
    "$directory/infrastructure/namespaces" \
    "$directory/infrastructure/config"

  cat > "$directory/apps/catalog/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
        - name: catalog
          image: nginx:1.27-alpine
          env:
            - name: APP_NAME
              value: catalog
          ports:
            - name: http
              containerPort: 80
YAML
  cat > "$directory/apps/catalog/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: catalog
spec:
  selector:
    app: catalog
  ports:
    - name: http
      port: 80
      targetPort: http
YAML
  cat > "$directory/apps/catalog/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
YAML

  cp "$directory/apps/catalog/deployment.yaml" \
    "$directory/apps/web/base/deployment.yaml"
  cp "$directory/apps/catalog/service.yaml" \
    "$directory/apps/web/base/service.yaml"
  sed -i 's/catalog/web/g' "$directory/apps/web/base/"*.yaml
  cat > "$directory/apps/web/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
YAML

  for environment in dev prod; do
    replicas=1
    [ "$environment" = "prod" ] && replicas=3
    cat > "$directory/apps/web/overlays/$environment/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-${environment}
namePrefix: ${environment}-
resources:
  - ../../base
replicas:
  - name: web
    count: ${replicas}
images:
  - name: nginx
    newName: nginx
    newTag: 1.27-alpine
commonLabels:
  environment: ${environment}
YAML
  done

  cat > "$directory/apps/substitution/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: runtime-settings
data:
  message: ${APP_MESSAGE:=default}
  owner: ${APP_OWNER:=unknown}
YAML
  cat > "$directory/apps/substitution/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
YAML

  cat > "$directory/infrastructure/namespaces/namespaces.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: flux-dev
---
apiVersion: v1
kind: Namespace
metadata:
  name: flux-prod
---
apiVersion: v1
kind: Namespace
metadata:
  name: flux-apps
YAML
  cat > "$directory/infrastructure/namespaces/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces.yaml
YAML

  cat > "$directory/infrastructure/config/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-config
data:
  managed-by: flux
  tier: platform
YAML
  cat > "$directory/infrastructure/config/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
YAML
  cat > "$directory/.sourceignore" <<'EOF'
*.md
tmp/
EOF

  ensure_gitea_org
  ensure_gitea_repo
  auth_url="$(gitea_authenticated_url)"
  git -C "$directory" init --quiet --initial-branch=main
  git -C "$directory" config user.name "CNPE Flux Lab"
  git -C "$directory" config user.email "cnpe-flux@local"
  git -C "$directory" add .
  git -C "$directory" commit --quiet -m "Initialize Flux platform manifests"
  git -C "$directory" tag -f v1.0.0
  git -C "$directory" tag -f v1.1.0
  git -C "$directory" push --quiet --force "$auth_url" HEAD:main
  git -C "$directory" push --quiet --force "$auth_url" \
    refs/tags/v1.0.0 refs/tags/v1.1.0
  trap - RETURN
  rm -rf "$directory"
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if ! kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a Kubernetes cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

write_git_source() {
  local question=$1
  cat > "$COURSE_DIR/$question/source.yaml" <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: q${question}-platform
  namespace: flux-system
spec:
  interval: 1m
  url: __GIT_REPO_URL__
  ref:
    branch: main
YAML
}

write_helm_repository() {
  local question=$1 name=$2 url=$3
  cat > "$COURSE_DIR/$question/helmrepository.yaml" <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: q${question}-${name}
  namespace: flux-system
spec:
  interval: 10m
  url: ${url}
YAML
}

for command_name in kubectl curl git sed; do
  command -v "$command_name" >/dev/null || die "$command_name is required"
done

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

prepare_gitea_repository
ensure_cluster

if [ "$LAB_FORCE" = "true" ]; then
  for namespace in \
    flux-apps flux-dev flux-prod headlamp metrics-server monitoring \
    q20-headlamp
  do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=true
  done
  rm -rf "$COURSE_DIR"
fi

info "Installing Flux CD ${FLUX_VERSION}"
kubectl apply -f \
  "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/install.yaml" \
  >/dev/null
for controller in source-controller kustomize-controller helm-controller; do
  kubectl -n flux-system rollout status "deployment/${controller}" --timeout=300s
done
for namespace in flux-apps flux-dev flux-prod; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

mkdir -p "$COURSE_DIR"
for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done

# Q1-Q10: GitRepository and Kustomization over the Gitea manifest repository.
for question in $(seq -w 1 10); do write_git_source "$question"; done
sed -i \
  -e 's|__GIT_REPO_URL__|https://invalid.example/platform.git|' \
  -e 's/branch: main/branch: missing/' \
  "$COURSE_DIR/01/source.yaml"

cat > "$COURSE_DIR/02/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q02-catalog
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q02-platform
  path: ./missing
  targetNamespace: flux-apps
  prune: false
  wait: false
YAML

cat > "$COURSE_DIR/03/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q03-dev
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q03-platform
  path: ./apps/web/overlays/dev
  prune: true
  wait: true
  commonMetadata: {} # TODO labels and annotations
YAML

cat > "$COURSE_DIR/04/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q04-prod
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q04-platform
  path: ./apps/web/overlays/dev # TODO production overlay
  prune: true
  wait: true
YAML

cat > "$COURSE_DIR/05/variables.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: q05-values
  namespace: flux-system
data:
  APP_MESSAGE: configured-by-flux
  APP_OWNER: platform-team
YAML
cat > "$COURSE_DIR/05/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q05-substitution
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q05-platform
  path: ./apps/substitution
  targetNamespace: flux-apps
  prune: true
  postBuild: {} # TODO substituteFrom q05-values
YAML

cat > "$COURSE_DIR/06/kustomizations.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q06-namespaces
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q06-platform
  path: ./infrastructure/namespaces
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q06-application
  namespace: flux-system
spec:
  interval: 5m
  dependsOn: [] # TODO q06-namespaces
  sourceRef:
    kind: GitRepository
    name: q06-platform
  path: ./apps/web/overlays/prod
  prune: true
  wait: true
YAML

cat > "$COURSE_DIR/07/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q07-health
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: q07-platform
  path: ./apps/catalog
  targetNamespace: flux-apps
  prune: true
  wait: false
  timeout: 30s
  healthChecks: [] # TODO catalog Deployment
YAML

cat > "$COURSE_DIR/08/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q08-suspend
  namespace: flux-system
spec:
  interval: 1m
  suspend: true
  sourceRef:
    kind: GitRepository
    name: q08-platform
  path: ./apps/catalog
  targetNamespace: flux-apps
  prune: true
YAML

cat > "$COURSE_DIR/09/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q09-drift
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: q09-platform
  path: ./apps/web/overlays/dev
  prune: true
  wait: true
YAML

cat > "$COURSE_DIR/10/kustomizations.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q10-infrastructure
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: q10-platform
  path: ./infrastructure/namespaces
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q10-production
  namespace: flux-system
spec:
  interval: 2m
  dependsOn: [] # TODO q10-infrastructure
  sourceRef:
    kind: GitRepository
    name: q10-platform
  path: ./apps/web/overlays/prod
  prune: false # TODO true
  wait: false # TODO true
YAML

# Q11-Q19: official Helm repositories and standalone tools.
write_helm_repository 11 headlamp "https://invalid.example/headlamp"
write_helm_repository 12 headlamp "$HEADLAMP_REPO_URL"
write_helm_repository 13 headlamp "$HEADLAMP_REPO_URL"
write_helm_repository 14 metrics "$METRICS_SERVER_REPO_URL"
write_helm_repository 15 metrics "$METRICS_SERVER_REPO_URL"
write_helm_repository 16 prometheus "$PROMETHEUS_REPO_URL"
write_helm_repository 17 prometheus "$PROMETHEUS_REPO_URL"
write_helm_repository 18 headlamp "$HEADLAMP_REPO_URL"
write_helm_repository 19 headlamp "$HEADLAMP_REPO_URL"

cat > "$COURSE_DIR/12/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q12-headlamp
  namespace: flux-system
spec:
  interval: 5m
  releaseName: q12-headlamp
  targetNamespace: headlamp
  chart:
    spec:
      chart: missing
      version: "9.x"
      sourceRef:
        kind: HelmRepository
        name: q12-headlamp
YAML

cat > "$COURSE_DIR/13/values.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: q13-headlamp-values
  namespace: flux-system
data:
  values.yaml: |
    replicaCount: 2
    service:
      type: ClusterIP
      port: 8080
    clusterRoleBinding:
      create: false
    config:
      baseURL: /headlamp
YAML
cat > "$COURSE_DIR/13/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q13-headlamp
  namespace: flux-system
spec:
  interval: 5m
  releaseName: q13-headlamp
  targetNamespace: headlamp
  chart:
    spec:
      chart: headlamp
      version: "0.42.x"
      sourceRef:
        kind: HelmRepository
        name: q13-headlamp
  install:
    createNamespace: true
  valuesFrom: [] # TODO q13-headlamp-values values.yaml
YAML

cat > "$COURSE_DIR/14/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q14-metrics-server
  namespace: flux-system
spec:
  interval: 5m
  releaseName: metrics-server
  targetNamespace: metrics-server
  chart:
    spec:
      chart: metrics-server
      version: "3.13.x"
      sourceRef:
        kind: HelmRepository
        name: q14-metrics
  install: {} # TODO createNamespace
  values:
    replicas: 1 # TODO 2
    args: [] # TODO --kubelet-insecure-tls
YAML

cat > "$COURSE_DIR/15/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q15-metrics-server
  namespace: flux-system
spec:
  interval: 5m
  releaseName: q15-metrics-server
  targetNamespace: metrics-server
  chart:
    spec:
      chart: metrics-server
      version: "3.13.x"
      sourceRef:
        kind: HelmRepository
        name: q15-metrics
  install:
    createNamespace: true
  values:
    metrics:
      enabled: false # TODO true
    service:
      type: ClusterIP
      labels: {} # TODO app.kubernetes.io/part-of platform-observability
    resources: {} # TODO requests cpu 100m memory 200Mi
YAML

cat > "$COURSE_DIR/16/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q16-kube-state-metrics
  namespace: flux-system
spec:
  interval: 5m
  releaseName: kube-state-metrics
  targetNamespace: monitoring
  chart:
    spec:
      chart: kube-state-metrics
      version: "7.4.x"
      sourceRef:
        kind: HelmRepository
        name: q16-prometheus
  install: {} # TODO createNamespace
  values:
    replicas: 1 # TODO 2
    customLabels: {} # TODO team platform
YAML

cat > "$COURSE_DIR/17/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q17-kube-state-metrics
  namespace: flux-system
spec:
  interval: 5m
  releaseName: q17-kube-state-metrics
  targetNamespace: monitoring
  chart:
    spec:
      chart: kube-state-metrics
      version: "7.4.x"
      sourceRef:
        kind: HelmRepository
        name: q17-prometheus
  install:
    createNamespace: true
  values:
    service:
      type: ClusterIP
      port: 8080
    resources: {} # TODO requests and limits
    selfMonitor:
      enabled: false
YAML

cat > "$COURSE_DIR/18/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q18-headlamp
  namespace: flux-system
spec:
  interval: 5m
  releaseName: q18-headlamp
  targetNamespace: headlamp
  chart:
    spec:
      chart: headlamp
      version: "0.42.x"
      sourceRef:
        kind: HelmRepository
        name: q18-headlamp
  install:
    createNamespace: true
    remediation: {} # TODO retries 3
  upgrade: {} # TODO remediation retries 3 rollback
  driftDetection: {} # TODO enabled
YAML

cat > "$COURSE_DIR/19/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q19-headlamp
  namespace: flux-system
spec:
  interval: 1m
  suspend: true
  releaseName: q19-headlamp
  targetNamespace: headlamp
  chart:
    spec:
      chart: headlamp
      version: "0.42.x"
      sourceRef:
        kind: HelmRepository
        name: q19-headlamp
  install:
    createNamespace: true
  values:
    replicaCount: 2
    service:
      type: ClusterIP
  driftDetection:
    mode: enabled
YAML

# Q20: one Git workload and one standalone Helm tool.
write_git_source 20
write_helm_repository 20 headlamp "$HEADLAMP_REPO_URL"
cat > "$COURSE_DIR/20/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: q20-platform
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: q20-platform
  path: ./apps/web/overlays/prod
  prune: false # TODO true
  wait: false # TODO true
YAML
cat > "$COURSE_DIR/20/helmrelease.yaml" <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: q20-headlamp
  namespace: flux-system
spec:
  interval: 2m
  releaseName: q20-headlamp
  targetNamespace: q20-headlamp
  chart:
    spec:
      chart: headlamp
      version: "0.42.x"
      sourceRef:
        kind: HelmRepository
        name: q20-headlamp
  install: {} # TODO createNamespace
  values:
    replicaCount: 1 # TODO 2
    service:
      type: ClusterIP
      port: 80
    clusterRoleBinding:
      create: true # TODO false
  driftDetection: {} # TODO enabled
YAML
touch "$COURSE_DIR/20/final-report.md"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
find "$COURSE_DIR" -type f \( -name '*.yaml' -o -name '*.md' \) -exec \
  sed -i -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" {} +

source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Flux CD lab ready: $COURSE_DIR"
info "Gitea manifest repository: $GIT_REPO_URL"
info "Headlamp Helm repository: $HEADLAMP_REPO_URL"
info "Metrics Server Helm repository: $METRICS_SERVER_REPO_URL"
info "Prometheus Community Helm repository: $PROMETHEUS_REPO_URL"
kubectl -n flux-system get deployments
