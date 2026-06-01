#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATTERY="$(basename "$SCRIPT_DIR" | sed -E 's/[^0-9]//g')"
PROFILE="cnpe-b${BATTERY}"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_API="${GITEA_URL%/}/api/v1"
GITEA_OWNER="organization"

init_gitea_owner() {
  [[ -n "$GITEA_OWNER" ]] && return 0
  if [[ -z "$GITEA_TOKEN" ]]; then
    warn "GITEA_TOKEN is empty, skipping remote repo seed"
    return 1
  fi

  GITEA_OWNER="$(curl -fsS -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "$GITEA_OWNER" ]]; then
    warn "Unable to resolve Gitea user login from API"
    return 1
  fi
  return 0
}

create_gitea_repo_if_missing() {
  local repo_name="$1"
  local status post_status

  init_gitea_owner || return 1

  status="$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/repos/$GITEA_OWNER/$repo_name" || true)"
  if [[ "$status" == "200" ]]; then
    return 0
  fi

  post_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" -d "{\"name\":\"$repo_name\",\"private\":false,\"auto_init\":false}" "$GITEA_API/orgs/$GITEA_OWNER/repos" || true)"
  if [[ "$post_status" != "201" && "$post_status" != "409" ]]; then
    warn "Gitea repo create failed for $repo_name (HTTP $post_status)"
    return 1
  fi
  return 0
}

seed_git_repo_to_gitea() {
  local repo_path="$1"
  local repo_name="$2"
  local commit_message="$3"
  local push_base push_url

  git -C "$repo_path" init -b main >/dev/null 2>&1 || true
  git -C "$repo_path" config user.name "CNPE Setup"
  git -C "$repo_path" config user.email "cnpe-setup@example.local"
  git -C "$repo_path" add . >/dev/null 2>&1 || true
  git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true

  create_gitea_repo_if_missing "$repo_name" || return 0

  push_base="${GITEA_URL%/}"
  push_url="${push_base/\/\//\/\/$GITEA_OWNER:$GITEA_TOKEN@}/$GITEA_OWNER/$repo_name.git"
  git -C "$repo_path" remote remove origin >/dev/null 2>&1 || true
  git -C "$repo_path" remote add origin "$push_url" >/dev/null 2>&1 || true
  git -C "$repo_path" push -u origin main --force >/dev/null 2>&1 || warn "Push to Gitea failed for $repo_name"
}

for c in minikube kubectl helm git curl jq docker; do
  command -v "$c" >/dev/null 2>&1 || { echo "[ERR] missing command: $c"; exit 1; }
done

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using $COURSE_ROOT"
fi

info "Resetting Minikube profile $PROFILE (delete + recreate)"
echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=16384 \
  --disk-size=20g \
  --addons=ingress,metrics-server

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null
ok "Cluster ready"

for ns in \
  monitoring monitor argocd flux-system builder checkout \
  market shared-apps malawi planet-apps opencost \
  dev-platform platform-ops team-lake tracing retail ops-lab \
  argo-rollouts argo-workflows crossplane-system finance; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

for q in $(seq -w 1 20); do
  kubectl create namespace "ns-b${BATTERY}-q${q}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl create namespace "ns-b${BATTERY}-q${q}-testing" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl create namespace "ns-b${BATTERY}-q${q}-client" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

helm repo add prometheus https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null 2>&1 || true
helm repo add crossplane https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo add opencost https://opencost.github.io/opencost-helm-chart >/dev/null 2>&1 || true
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

helm upgrade --install kube-prom-stack prometheus/kube-prometheus-stack -n monitor --create-namespace --set grafana.enabled=false --set prometheus-node-exporter.enabled=false --wait --timeout=600s >/dev/null 2>&1 || warn "kube-prometheus-stack install failed"
helm upgrade --install loki grafana/loki -n monitor --create-namespace --set loki.auth_enabled=false --wait --timeout=600s >/dev/null 2>&1 || warn "loki install failed"
helm upgrade --install grafana grafana/grafana -n monitor --create-namespace --set adminPassword=admin --set service.type=ClusterIP --wait --timeout=600s >/dev/null 2>&1 || warn "grafana install failed"
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --set configs.params."server\\.insecure"=true --set server.service.type=ClusterIP --wait --timeout=600s >/dev/null 2>&1 || warn "argo-cd install failed"
helm upgrade --install kyverno kyverno/kyverno -n finance --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "kyverno install failed"
helm upgrade --install crossplane crossplane/crossplane -n crossplane-system --create-namespace --wait --timeout=600s >/dev/null 2>&1 || warn "crossplane install failed"
helm upgrade --install opencost opencost/opencost -n opencost --create-namespace --set prometheus.internal.enabled=true --wait --timeout=600s >/dev/null 2>&1 || warn "opencost install failed"
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector -n tracing --create-namespace --set mode=deployment --wait --timeout=600s >/dev/null 2>&1 || warn "otel-collector install failed"

kubectl create -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml >/dev/null 2>&1 || warn "gatekeeper install failed"
kubectl create -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml >/dev/null 2>&1 || warn "tekton pipeline install failed"
kubectl create -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "argo rollouts install failed"
kubectl create -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "argo workflows install failed"
kubectl create -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1 || warn "flux install failed"
kubectl create -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.24.0.yaml >/dev/null 2>&1 || warn "cloudnative-pg install failed"

if command -v linkerd >/dev/null 2>&1; then
  linkerd install --crds | kubectl apply -f - >/dev/null 2>&1 || warn "linkerd CRDs install failed"
  linkerd install | kubectl apply -f - >/dev/null 2>&1 || warn "linkerd control plane install failed"
else
  warn "linkerd CLI not found, skipping Linkerd install"
fi

if command -v istioctl >/dev/null 2>&1; then
  istioctl install -y --set profile=minimal >/dev/null 2>&1 || warn "istio install failed"
else
  warn "istioctl not found, skipping Istio install"
fi

kubectl -n market apply -f - <<'YAML' >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
spec:
  replicas: 2
  selector:
    matchLabels: {app: market-api}
  template:
    metadata:
      labels: {app: market-api}
    spec:
      containers:
      - name: api
        image: nginx:1.25
        resources:
          requests: {cpu: "500m", memory: "256Mi"}
          limits: {cpu: "1000m", memory: "512Mi"}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-worker
spec:
  replicas: 2
  selector:
    matchLabels: {app: market-worker}
  template:
    metadata:
      labels: {app: market-worker}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo worker; sleep 3; done"]
YAML

kubectl -n ops-lab apply -f - <<'YAML' >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-crashy
spec:
  replicas: 1
  selector:
    matchLabels: {app: demo-crashy}
  template:
    metadata:
      labels: {app: demo-crashy}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
YAML

for q in $(seq -w 1 20); do
  ns="ns-b${BATTERY}-q${q}"
  app="app-b${BATTERY}-q${q}"
  kubectl -n "$ns" apply -f - <<YAML >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app}
spec:
  replicas: 1
  selector:
    matchLabels: {app: ${app}}
  template:
    metadata:
      labels: {app: ${app}, version: v1}
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ${app}
spec:
  selector: {app: ${app}}
  ports:
  - name: http
    port: 80
    targetPort: 80
YAML
done

for i in $(seq 1 20); do
  mkdir -p "$COURSE_ROOT/$i/repo-b${BATTERY}"
done

cat > "$COURSE_ROOT/1/repo-b${BATTERY}/crd.yaml" <<'YAML'
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
              target:
                type: string
YAML
cat > "$COURSE_ROOT/1/repo-b${BATTERY}/kustomization.yaml" <<'YAML'
resources:
- crd.yaml
YAML

mkdir -p "$COURSE_ROOT/3/repo-b${BATTERY}/manifests"
cat > "$COURSE_ROOT/3/repo-b${BATTERY}/manifests/web-client.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
spec:
  replicas: 1
  selector:
    matchLabels: {app: web-client}
  template:
    metadata:
      labels: {app: web-client, version: v1}
    spec:
      containers:
      - name: app
        image: nginx:1.25
YAML

mkdir -p "$COURSE_ROOT/5/repo-b${BATTERY}/gatekeeper" "$COURSE_ROOT/5/repo-b${BATTERY}/chart/templates"
cat > "$COURSE_ROOT/5/repo-b${BATTERY}/gatekeeper/constraint-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabelsandreplicas
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabelsAndReplicas
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabelsandreplicas
      violation[{"msg": msg}] {
        input.review.kind.kind == "Pod"
        not input.review.object.metadata.labels.owner
        msg := "owner label required"
      }
YAML
cat > "$COURSE_ROOT/5/repo-b${BATTERY}/chart/Chart.yaml" <<'YAML'
apiVersion: v2
name: app-chart
version: 1.0.0
appVersion: "1.0.0"
YAML
cat > "$COURSE_ROOT/5/repo-b${BATTERY}/chart/templates/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-chart
spec:
  replicas: 1
  selector:
    matchLabels: {app: app-chart}
  template:
    metadata:
      labels: {app: app-chart}
    spec:
      containers:
      - name: app
        image: nginx:1.25
YAML

for svc in service-a service-b service-c; do
  mkdir -p "$COURSE_ROOT/6/repo-b${BATTERY}/$svc"
  cat > "$COURSE_ROOT/6/repo-b${BATTERY}/$svc/main.tf" <<'TF'
terraform {
  required_version = ">= 1.6.0"
}
TF
done

mkdir -p "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/base" "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/overlays/dev" "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/overlays/prod"
cat > "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/base/kustomization.yaml" <<'YAML'
resources: []
YAML
cat > "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/overlays/dev/kustomization.yaml" <<'YAML'
resources:
- ../../base
YAML
cat > "$COURSE_ROOT/9/repo-b${BATTERY}/prom-config/overlays/prod/kustomization.yaml" <<'YAML'
resources:
- ../../base
YAML

mkdir -p "$COURSE_ROOT/11/repo-b${BATTERY}/workflows"
cat > "$COURSE_ROOT/11/repo-b${BATTERY}/workflows/workflowtemplate.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-bootstrap
spec:
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:3.20
      command: [sh, -c]
      args: ["echo todo"]
YAML

mkdir -p "$COURSE_ROOT/12/repo-b${BATTERY}"
cat > "$COURSE_ROOT/12/repo-b${BATTERY}/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: app-ci
spec:
  tasks:
  - name: build
    taskSpec:
      steps:
      - image: alpine
        script: echo build
YAML

mkdir -p "$COURSE_ROOT/17/repo-b${BATTERY}/flux-app"
cat > "$COURSE_ROOT/17/repo-b${BATTERY}/flux-app/kustomization.yaml" <<'YAML'
resources: []
YAML

mkdir -p "$COURSE_ROOT/19/repo-b${BATTERY}/crossplane"
cat > "$COURSE_ROOT/19/repo-b${BATTERY}/crossplane/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: app-composition
spec:
  compositeTypeRef:
    apiVersion: platform.example.io/v1alpha1
    kind: XApp
  resources: []
YAML

for q in 1 3 5 9 10 11 17 19; do
  repo="$COURSE_ROOT/$q/repo-b${BATTERY}"
  seed_git_repo_to_gitea "$repo" "cnpe-b${BATTERY}-q${q}" "init battery ${BATTERY} q${q}"
done

cat > "$COURSE_ROOT/README-battery-${BATTERY}.txt" <<TXT
CNPE Battery ${BATTERY} setup completed
Profile: ${PROFILE}
Course root: ${COURSE_ROOT}
Notes:
- Paths /course/<q>/repo-b${BATTERY} pre-created for questions.
- Base workloads app-b${BATTERY}-qNN in namespaces ns-b${BATTERY}-qNN.
- Core CNCF components installed best-effort.
- Use battery question file for exact task details.
TXT

ok "Battery ${BATTERY} ready"
echo "Course root: $COURSE_ROOT"
