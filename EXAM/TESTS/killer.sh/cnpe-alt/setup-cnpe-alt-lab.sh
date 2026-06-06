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
for ns in atlas baltic baltic-staging cicd-alt delivery-alt selfservice-alt obs-alt security-alt cost-alt mesh-alt data-alt flux-platform; do
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

# Q2 Prometheus apps with deterministic request-rate metrics
mkdir -p "$COURSE_DIR/2"
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
        image: python:3.12-alpine
        command: ["/bin/sh", "-c"]
        args:
          - |
            cat >/tmp/metrics.py <<'PY'
            from http.server import BaseHTTPRequestHandler, HTTPServer
            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = 'http_requests_per_minute{namespace="atlas",deployment="checkout"} 75\n'
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain")
                    self.end_headers()
                    self.wfile.write(body.encode())
                def log_message(self, *_):
                    pass
            HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
            PY
            python /tmp/metrics.py
        ports: [{containerPort: 8080}]
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
        image: python:3.12-alpine
        command: ["/bin/sh", "-c"]
        args:
          - |
            cat >/tmp/metrics.py <<'PY'
            from http.server import BaseHTTPRequestHandler, HTTPServer
            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    body = 'http_requests_per_minute{namespace="atlas",deployment="proxy"} 220\n'
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain")
                    self.end_headers()
                    self.wfile.write(body.encode())
                def log_message(self, *_):
                    pass
            HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
            PY
            python /tmp/metrics.py
        ports: [{containerPort: 8080}]
YAML
touch "$COURSE_DIR/2/prometheus-report.txt"

# Q3 Argo CD repo
mkdir -p "$COURSE_DIR/3/portal-client/manifests"
cat > "$COURSE_DIR/3/portal-client/manifests/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-client
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

PORTAL_REPO_URL="${GITEA_URL}/${GITEA_ORG}/portal-client.git"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portal-client
  namespace: argocd
spec:
  project: lagoon
  destination:
    namespace: baltic
    server: https://kubernetes.default.svc
  source:
    repoURL: ${PORTAL_REPO_URL}
    targetRevision: main
    path: manifests
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

# Q4 Flagger Canary with a missing pre-rollout webhook
mkdir -p "$COURSE_DIR/4"
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
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: catalog
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog
  service:
    port: 80
    portDiscovery: true
  analysis:
    interval: 5s
    iterations: 2
    threshold: 5
    metrics: []
YAML
touch "$COURSE_DIR/4/catalog-events.log"

# Q5 Argo Rollouts analysis gate
mkdir -p "$COURSE_DIR/5"
cat > "$COURSE_DIR/5/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: frontend-http-check
  namespace: delivery-alt
spec:
  metrics:
    - name: frontend-http
      interval: 5s
      count: 3
      successCondition: result.ok == true
      provider:
        web:
          url: http://TODO
YAML

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: frontend-rollout
  namespace: delivery-alt
spec:
  selector: {app: frontend-rollout}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-rollout-canary
  namespace: delivery-alt
spec:
  selector: {app: frontend-rollout}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: frontend-rollout
  namespace: delivery-alt
spec:
  replicas: 2
  selector:
    matchLabels: {app: frontend-rollout}
  template:
    metadata:
      labels: {app: frontend-rollout}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo '{"ok":true}' >/usr/share/nginx/html/index.html
              nginx -g 'daemon off;'
          env:
            - name: VERSION
              value: "1.0.0"
          ports:
            - containerPort: 80
  strategy:
    canary:
      stableService: frontend-rollout
      canaryService: frontend-rollout-canary
      steps:
        - setWeight: 50
        - pause: {}
        - setWeight: 100
YAML

# Q6 Tekton repository with complete Tasks and incomplete Pipeline wiring
mkdir -p "$COURSE_DIR/6/tekton-api"
cat > "$COURSE_DIR/6/tekton-api/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: api-git-clone
  namespace: cicd-alt
spec:
  params:
    - name: repo-url
      type: string
  workspaces:
    - name: source
  steps:
    - name: clone
      image: alpine/git:2.45.2
      script: |
        rm -rf "$(workspaces.source.path)"/*
        git clone "$(params.repo-url)" "$(workspaces.source.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: api-print-sha
  namespace: cicd-alt
spec:
  workspaces:
    - name: source
  steps:
    - name: print
      image: alpine/git:2.45.2
      workingDir: "$(workspaces.source.path)"
      script: |
        git rev-parse HEAD
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: api-build
  namespace: cicd-alt
spec:
  params:
  - name: repo-url
    type: string
  workspaces:
    - name: source
  tasks: [] # TODO: wire api-git-clone and api-print-sha
YAML
init_git_repo tekton-api "$COURSE_DIR/6/tekton-api"

TEKTON_REPO_URL="${GITEA_URL}/${GITEA_ORG}/tekton-api.git"
cat > "$COURSE_DIR/6/tekton-api/pipelinerun.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: api-build-
  namespace: cicd-alt
spec:
  pipelineRef:
    name: api-build
  params:
    - name: repo-url
      value: ${TEKTON_REPO_URL}
  workspaces:
    - name: source
      emptyDir: {}
YAML

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: cicd-alt
YAML

# Q7 Flux repository with one omitted resource and a broken branch
mkdir -p "$COURSE_DIR/7/flux-platform/clusters/dev/apps/demo"
cat > "$COURSE_DIR/7/flux-platform/clusters/dev/apps/kustomization.yaml" <<'YAML'
resources: []
YAML
cat > "$COURSE_DIR/7/flux-platform/clusters/dev/apps/demo/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels: {app: demo}
  template:
    metadata:
      labels: {app: demo}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/7/flux-platform/clusters/dev/apps/demo/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: demo
spec:
  selector: {app: demo}
  ports: [{port: 80, targetPort: 80}]
YAML
cat > "$COURSE_DIR/7/flux-platform/clusters/dev/apps/demo/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
YAML
init_git_repo flux-platform "$COURSE_DIR/7/flux-platform"

FLUX_REPO_URL="${GITEA_URL}/${GITEA_ORG}/flux-platform.git"
kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-platform
  namespace: flux-system
spec:
  interval: 30s
  url: ${FLUX_REPO_URL}
  ref:
    branch: develop
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-platform
  namespace: flux-system
spec:
  interval: 30s
  sourceRef:
    kind: GitRepository
    name: flux-platform
  path: ./clusters/dev/apps
  prune: true
  targetNamespace: flux-platform
YAML

# Q8 Crossplane XRD skeleton
cat > "$COURSE_DIR/8/platform-api/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: postgresinstances.platform.cnpe.io
spec:
  scope: Namespaced
  group: platform.cnpe.io
  names:
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
    kind: PostgresInstance
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      - name: postgres-config
        base:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: postgres-config
          data: {}
        patches:
        - fromFieldPath: metadata.namespace
          toFieldPath: metadata.namespace
        # TODO: patch spec.databaseName and spec.storageSize into data
        readinessChecks:
        - type: None
YAML
cat > "$COURSE_DIR/8/platform-api/xr.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PostgresInstance
metadata:
  name: orders-db
  namespace: selfservice-alt
spec:
  # TODO: databaseName and storageSize
YAML

# Q9 Backstage/software template skeleton
mkdir -p "$COURSE_DIR/9/backstage-template/skeleton"
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
cat > "$COURSE_DIR/9/backstage-template/skeleton/catalog-info.yaml" <<'YAML'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.serviceName }}
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
YAML

# Q10 OpenTofu provider; team-a already exists and must be imported
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
provider "kubernetes" {
  config_path = "~/.kube/config"
  insecure    = true
}
# TODO: import team-a and add platform-settings plus automation
EOF2
touch "$COURSE_DIR/10/tofu-output.txt"

# Q11/Q12 observability with a deterministic OTLP endpoint and log stream
mkdir -p "$COURSE_DIR/11" "$COURSE_DIR/12"
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: jaeger-otlp
  namespace: eyre
spec:
  selector:
    app: jaeger
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
YAML

kubectl apply -n obs-alt -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
spec:
  type: ExternalName
  externalName: jaeger-otlp.eyre.svc.cluster.local
  ports:
    - name: otlp-grpc
      port: 4317
---
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
        image: busybox:1.36
        command: ["/bin/sh", "-c"]
        args:
          - |
            while true; do
              echo "$(date) INFO telemetry export scheduled"
              echo "$(date) ERROR exporter cannot reach ${OTEL_EXPORTER_OTLP_ENDPOINT}"
              sleep 5
            done
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://wrong-collector:4317"
YAML
touch "$COURSE_DIR/11/otel-check.txt"
touch "$COURSE_DIR/12/log-triage.md"

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-observability-alt
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  observability-alt.json: |
    {
      "title": "observability-alt",
      "panels": [
        {
          "type": "timeseries",
          "title": "Telemetry errors",
          "datasource": "Loki",
          "targets": [
            {
              "expr": "{namespace=\"wrong\"}"
            }
          ],
          "gridPos": {"x": 0, "y": 0, "w": 24, "h": 8}
        }
      ],
      "schemaVersion": 30
    }
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
      validation:
        openAPIV3Schema:
          type: object
          properties:
            label:
              # TODO
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredowner
      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        not input.review.object.metadata.labels[input.parameters.label]
        msg := "CHANGE THIS MESSAGE"
      }
YAML
cat > "$COURSE_DIR/13/gatekeeper/require-owner.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredOwner
metadata:
  name: require-owner
spec:
  enforcementAction: deny
  # TODO: match Deployments only in security-alt and require owner
YAML
cat > "$COURSE_DIR/13/gatekeeper/deployment-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: owner-test-bad
  namespace: security-alt
spec:
  replicas: 1
  selector:
    matchLabels: {app: owner-test-bad}
  template:
    metadata:
      labels: {app: owner-test-bad}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/13/gatekeeper/deployment-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: owner-test-good
  namespace: security-alt
  labels:
    owner: platform
spec:
  replicas: 1
  selector:
    matchLabels: {app: owner-test-good}
  template:
    metadata:
      labels: {app: owner-test-good}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/14/kyverno/policy.yaml" <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: require-run-as-non-root
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["security-alt"]
      exclude:
        any:
          - resources:
              namespaces: [] # TODO: kube-system
      validate:
        message: Pods must set spec.securityContext.runAsNonRoot to true
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
YAML
cat > "$COURSE_DIR/14/kyverno/pod-bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: kyverno-bad
  namespace: security-alt
spec:
  containers:
    - name: app
      image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/14/kyverno/pod-good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: kyverno-good
  namespace: security-alt
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
YAML

cat > "$COURSE_DIR/15/pod-security/legacy-worker.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-worker
  namespace: security-alt
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
kubectl apply -f "$COURSE_DIR/15/pod-security/legacy-worker.yaml"

kubectl create sa report-reader -n security-alt --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "$COURSE_DIR/16/rbac/rbac.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: report-reader
  namespace: security-alt
rules: [] # TODO
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-reader
  namespace: security-alt
subjects: [] # TODO
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: report-reader
YAML
touch "$COURSE_DIR/16/rbac/auth-check.txt"

# Q17 KEDA cron scaling
mkdir -p "$COURSE_DIR/17/keda" "$COURSE_DIR/18/opencost" "$COURSE_DIR/19/linkerd" "$COURSE_DIR/20/final"
helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
helm repo update
helm upgrade --install keda kedacore/keda \
  --version 2.18.1 \
  --namespace keda --create-namespace \
  --wait --timeout=300s

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
  triggers:
    - type: cron
      metadata:
        timezone: TODO
        start: TODO
        end: TODO
        desiredReplicas: TODO
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
touch "$COURSE_DIR/17/keda/status.txt"
touch "$COURSE_DIR/18/opencost/allocation.json"
touch "$COURSE_DIR/18/opencost/access.txt"

# Q19 Linkerd client/server workload before namespace injection
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mesh-server
  namespace: mesh-alt
spec:
  replicas: 1
  selector:
    matchLabels: {app: mesh-server}
  template:
    metadata:
      labels: {app: mesh-server}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo mesh-server-ok >/usr/share/nginx/html/index.html
              nginx -g 'daemon off;'
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: mesh-server
  namespace: mesh-alt
spec:
  selector: {app: mesh-server}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mesh-client
  namespace: mesh-alt
spec:
  replicas: 1
  selector:
    matchLabels: {app: mesh-client}
  template:
    metadata:
      labels: {app: mesh-client}
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["/bin/sh", "-c", "sleep 3600"]
YAML
touch "$COURSE_DIR/19/linkerd/verification.txt"

cat > "$COURSE_DIR/20/final/README.md" <<'EOF2'
Create report.md with command, result and rollback for every Q20 verification item.
EOF2
touch "$COURSE_DIR/20/final/report.md"

cp "${SCRIPT_DIR}/domande-alt.md" "$COURSE_DIR/domande-alt.md" 2>/dev/null || true
ok "Alternative lab ready in ${COURSE_DIR}"
ok "Use domande-alt.md from this package or ${COURSE_DIR}/domande-alt.md"
