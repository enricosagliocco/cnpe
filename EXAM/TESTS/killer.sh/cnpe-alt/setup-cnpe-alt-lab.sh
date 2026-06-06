#!/usr/bin/env bash
# ============================================================
# CNPE Alternative Full Lab Setup
# - Runs the already validated base CNPE Minikube setup
# - Adds an alternative scenario set mapped to all CNPE domains
# ============================================================
set -euo pipefail

export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_USER="${GITEA_USER:-cnpe-user}"
export GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
export GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
export COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course-alt}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info(){ echo -e "${CYAN}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERR]${NC} $*"; exit 1; }
section(){ echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

require(){ command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }
gitea_status(){
  local method="$1" path="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" "${GITEA_URL}${path}" -d "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL}${path}"
  fi
}
gitea_api(){ curl -sS -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" "$@"; }
ensure_org(){
  local code
  code="$(gitea_status GET "/api/v1/orgs/${GITEA_ORG}")"
  [ "$code" = "200" ] && return 0
  code="$(gitea_status POST "/api/v1/orgs" "{\"username\":\"${GITEA_ORG}\",\"full_name\":\"${GITEA_ORG}\"}")"
  [ "$code" = "201" ] || [ "$code" = "409" ] || warn "Cannot create org ${GITEA_ORG} HTTP ${code}"
}
ensure_repo(){
  local repo="$1" code
  code="$(gitea_status GET "/api/v1/repos/${GITEA_ORG}/${repo}")"
  [ "$code" = "200" ] && return 0
  code="$(gitea_status POST "/api/v1/orgs/${GITEA_ORG}/repos" "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}")"
  [ "$code" = "201" ] || [ "$code" = "409" ] || die "Cannot create repo ${GITEA_ORG}/${repo} HTTP ${code}"
}
auth_url(){
  local repo="$1" login
  login="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" | jq -r '.login // empty')"
  [ -n "$login" ] || login="$GITEA_USER"
  case "$GITEA_URL" in
    http://*) echo "http://${login}:${GITEA_TOKEN}@${GITEA_URL#http://}/${GITEA_ORG}/${repo}.git" ;;
    https://*) echo "https://${login}:${GITEA_TOKEN}@${GITEA_URL#https://}/${GITEA_ORG}/${repo}.git" ;;
    *) echo "${GITEA_URL}/${GITEA_ORG}/${repo}.git" ;;
  esac
}
init_git_repo(){
  local repo="$1" dir="$2"
  ensure_repo "$repo"
  git -C "$dir" init -b main >/dev/null 2>&1 || git -C "$dir" init >/dev/null
  git -C "$dir" config user.email "cnpe-user@simulator.local"
  git -C "$dir" config user.name "CNPE User"
  git -C "$dir" add .
  git -C "$dir" commit -m init >/dev/null 2>&1 || true
  git -C "$dir" remote remove origin >/dev/null 2>&1 || true
  git -C "$dir" remote add origin "$(auth_url "$repo")"
  git -C "$dir" push -u origin main --force >/dev/null 2>&1 || warn "Push failed for ${repo}; local repo still ready in ${dir}"
}

section "0. Run base setup"
for f in cnpe-setup-part1.sh cnpe-setup-part2.sh cnpe-setup-part3.sh; do
  [ -f "${SCRIPT_DIR}/${f}" ] || die "Missing ${f}"
  bash "${SCRIPT_DIR}/${f}"
done

section "1. Alternative CNPE scenario overlay"
require kubectl; require git; require curl; require jq
mkdir -p "$COURSE_DIR"
ensure_org

# Namespaces
for ns in atlas baltic cicd-alt delivery-alt selfservice-alt obs-alt security-alt cost-alt mesh-alt data-alt; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

# Q1/Q8 self-service CRD repo
mkdir -p "$COURSE_DIR/1/platform-service" "$COURSE_DIR/8/platform-api"
cat > "$COURSE_DIR/1/platform-service/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformservices.platform.cnpe.io
spec:
  group: platform.cnpe.io
  scope: Namespaced
  names:
    plural: platformservices
    singular: platformservice
    kind: PlatformService
    shortNames: [psvc]
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              owner:
                type: string
              runtime:
                type: string
YAML
cat > "$COURSE_DIR/1/platform-service/kustomization.yaml" <<'YAML'
resources:
- crd.yaml
YAML
kubectl apply -k "$COURSE_DIR/1/platform-service" >/dev/null
init_git_repo platform-service "$COURSE_DIR/1/platform-service"

# Q2 Prometheus apps with proxy missing scrape target
kubectl apply -n atlas -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: checkout, labels: {app: checkout}}
spec:
  replicas: 1
  selector: {matchLabels: {app: checkout}}
  template:
    metadata: {labels: {app: checkout, scrape: "true"}}
    spec:
      containers:
      - name: app
        image: nginx:1-alpine
        ports: [{containerPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: proxy, labels: {app: proxy}}
spec:
  replicas: 1
  selector: {matchLabels: {app: proxy}}
  template:
    metadata: {labels: {app: proxy, scrape: "missing"}}
    spec:
      containers:
      - name: app
        image: nginx:1-alpine
        ports: [{containerPort: 80}]
YAML

# Q3 Argo CD repo
mkdir -p "$COURSE_DIR/3/portal-client/manifests"
cat > "$COURSE_DIR/3/portal-client/manifests/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-client
  namespace: baltic
spec:
  replicas: 1
  selector:
    matchLabels: {app: portal-client}
  template:
    metadata:
      labels: {app: portal-client, version: v1}
    spec:
      containers:
      - name: nginx
        image: nginx:1-alpine
        ports: [{containerPort: 80}]
YAML
cat > "$COURSE_DIR/3/portal-client/manifests/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: portal-client
  namespace: baltic
spec:
  selector: {app: portal-client}
  ports: [{port: 80, targetPort: 80}]
YAML
cat > "$COURSE_DIR/3/portal-client/manifests/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
- service.yaml
YAML
init_git_repo portal-client "$COURSE_DIR/3/portal-client"

# Q4/Q5 Rollouts and Flagger placeholders
kubectl apply -n delivery-alt -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  labels: {app: catalog}
spec:
  replicas: 2
  selector: {matchLabels: {app: catalog}}
  template:
    metadata: {labels: {app: catalog}}
    spec:
      containers:
      - name: app
        image: nginx:1-alpine
        env: [{name: APP_VERSION, value: "1.0.0"}]
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: catalog}
spec:
  selector: {app: catalog}
  ports: [{port: 80, targetPort: 80}]
YAML

# Q6 Tekton repo skeleton
mkdir -p "$COURSE_DIR/6/tekton-api"
cat > "$COURSE_DIR/6/tekton-api/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: api-build
  namespace: cicd-alt
spec:
  params:
  - name: repo-url
    type: string
  tasks: [] # TODO: add git-clone and build task
YAML
init_git_repo tekton-api "$COURSE_DIR/6/tekton-api"

# Q7 Flux repo skeleton
mkdir -p "$COURSE_DIR/7/flux-platform/clusters/dev/apps"
cat > "$COURSE_DIR/7/flux-platform/clusters/dev/apps/kustomization.yaml" <<'YAML'
resources: []
YAML
init_git_repo flux-platform "$COURSE_DIR/7/flux-platform"

# Q8 Crossplane XRD skeleton
cat > "$COURSE_DIR/8/platform-api/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresinstances.platform.cnpe.io
spec:
  group: platform.cnpe.io
  names:
    kind: XPostgresInstance
    plural: xpostgresinstances
  claimNames:
    kind: PostgresInstance
    plural: postgresinstances
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties: {}
YAML
cat > "$COURSE_DIR/8/platform-api/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgres-configmap
spec:
  compositeTypeRef:
    apiVersion: platform.cnpe.io/v1alpha1
    kind: XPostgresInstance
  resources: []
YAML

# Q9 Backstage/software template skeleton
mkdir -p "$COURSE_DIR/9/backstage-template"
cat > "$COURSE_DIR/9/backstage-template/template.yaml" <<'YAML'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: service-onboarding
  title: Service Onboarding
spec:
  owner: platform-team
  type: service
  parameters: []
  steps: []
  output: {}
YAML

# Q10 OpenTofu skeleton
mkdir -p "$COURSE_DIR/10/tofu-k8s"
cat > "$COURSE_DIR/10/tofu-k8s/main.tf" <<'EOF2'
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
provider "kubernetes" { config_path = "~/.kube/config" }
resource "kubernetes_namespace" "team" {
  metadata { name = "team-a" }
}
EOF2

# Q11/Q12 observability
kubectl apply -n obs-alt -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: telemetry-api, labels: {app: telemetry-api}}
spec:
  replicas: 1
  selector: {matchLabels: {app: telemetry-api}}
  template:
    metadata: {labels: {app: telemetry-api}}
    spec:
      containers:
      - name: app
        image: ghcr.io/open-telemetry/demo:latest
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://wrong-collector:4317"
YAML

# Q13-Q16 security/policy inputs
mkdir -p "$COURSE_DIR/13/gatekeeper" "$COURSE_DIR/14/kyverno" "$COURSE_DIR/15/pod-security" "$COURSE_DIR/16/rbac"
cat > "$COURSE_DIR/13/gatekeeper/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredowner
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredOwner
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredowner
      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        not input.review.object.metadata.labels.owner
        msg := "TODO"
      }
YAML
cat > "$COURSE_DIR/14/kyverno/policy.yaml" <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationFailureAction: Audit
  rules: []
YAML
kubectl label ns security-alt pod-security.kubernetes.io/enforce=baseline --overwrite >/dev/null
kubectl apply -n security-alt -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: legacy-worker}
spec:
  replicas: 1
  selector: {matchLabels: {app: legacy-worker}}
  template:
    metadata: {labels: {app: legacy-worker}}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sleep","3600"]
        securityContext:
          privileged: true
YAML
kubectl create sa report-reader -n security-alt --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Q17-Q20 ops/platform tasks
mkdir -p "$COURSE_DIR/17/keda" "$COURSE_DIR/18/opencost" "$COURSE_DIR/19/linkerd" "$COURSE_DIR/20/final"
cat > "$COURSE_DIR/17/keda/scaledobject.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: queue-worker
  namespace: data-alt
spec:
  scaleTargetRef:
    name: queue-worker
  minReplicaCount: 0
  maxReplicaCount: 5
  triggers: []
YAML
kubectl apply -n data-alt -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: queue-worker}
spec:
  replicas: 1
  selector: {matchLabels: {app: queue-worker}}
  template:
    metadata: {labels: {app: queue-worker}}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sleep","3600"]
YAML
cat > "$COURSE_DIR/20/final/README.md" <<'EOF2'
Final task: create a short operational report in this directory after fixing GitOps, policy and observability issues.
EOF2

cp "${SCRIPT_DIR}/domande-alt.md" "$COURSE_DIR/domande-alt.md" 2>/dev/null || true
ok "Alternative lab ready in ${COURSE_DIR}"
ok "Use domande-alt.md from this package or ${COURSE_DIR}/domande-alt.md"
