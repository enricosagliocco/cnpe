#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-delivery-ops}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-delivery-ops-lab}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        info "Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
        info "Creating kind cluster: $KIND_CLUSTER_NAME"
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=6 --memory=12288
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

for ns in delivery-dev delivery-staging flux-staging cicd-lab metrics-lab \
  logging-lab tracing; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || { echo "helm is required with INSTALL_TOOLS=true"; exit 1; }
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait
  helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts \
    --create-namespace --set dashboard.enabled=true --wait
  helm upgrade --install prometheus prometheus-community/prometheus -n prometheus --create-namespace --wait
  helm upgrade --install loki grafana/loki -n monitoring --create-namespace \
    --set deploymentMode=SingleBinary \
    --set singleBinary.replicas=1 \
    --set backend.replicas=0 --set read.replicas=0 --set write.replicas=0 \
    --set loki.auth_enabled=false \
    --set loki.commonConfig.replication_factor=1 \
    --set loki.useTestSchema=true --wait
  helm upgrade --install grafana grafana/grafana -n monitoring \
    --set adminPassword=admin \
    --set sidecar.datasources.enabled=true --wait
  helm upgrade --install promtail grafana/promtail -n monitoring \
    --set "config.clients[0].url=http://loki.monitoring.svc:3100/loki/api/v1/push" \
    --wait
  kubectl apply -f https://github.com/fluxcd/flux2/releases/download/v2.8.8/install.yaml
  kubectl apply -f https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.9.0/release.yaml
  kubectl apply -f https://infra.tekton.dev/tekton-releases/dashboard/latest/release.yaml
  kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook --timeout=300s
  kubectl -n tekton-pipelines patch configmap feature-flags --type merge \
    -p '{"data":{"enable-api-fields":"beta"}}' >/dev/null
  kubectl -n tekton-pipelines rollout status deploy/tekton-dashboard --timeout=300s
  kubectl -n flux-system rollout status deploy/source-controller --timeout=300s
  kubectl -n flux-system rollout status deploy/kustomize-controller --timeout=300s
  kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: tracing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
        - name: jaeger
          image: jaegertracing/all-in-one:1.75.0
          ports:
            - name: otlp-grpc
              containerPort: 4317
            - name: query
              containerPort: 16686
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: tracing
spec:
  selector:
    app: jaeger
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
    - name: query
      port: 16686
      targetPort: 16686
YAML
fi

cat > "$COURSE_DIR/01/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storefront
  namespace: argocd
spec:
  project: default
  source:
    repoURL: TODO
    path: TODO
    targetRevision: TODO
  destination:
    server: https://kubernetes.default.svc
    namespace: TODO
  syncPolicy: {} # TODO
YAML
cp "$COURSE_DIR/01/application.yaml" "$COURSE_DIR/02/application.yaml"

cat > "$COURSE_DIR/03/source.yaml" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-source
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/fluxcd/flux2-kustomize-helm-example
  ref:
    branch: develop
YAML
cat > "$COURSE_DIR/04/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-staging
  namespace: flux-system
spec: {} # TODO
YAML
cat > "$COURSE_DIR/05/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drift-demo
  namespace: delivery-dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: drift-demo
  template:
    metadata:
      labels:
        app: drift-demo
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
kubectl apply -f "$COURSE_DIR/05/deployment.yaml" >/dev/null

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traffic-api
  namespace: metrics-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: traffic-api
      metrics: "true"
  template:
    metadata:
      labels:
        app: traffic-api
        metrics: "true"
      annotations:
        prometheus.io/port: "8080"
        prometheus.io/path: /metrics
    spec:
      containers:
        - name: metrics
          image: python:3.12-alpine
          command:
            - python
            - -u
            - -c
          args:
            - |
              from http.server import BaseHTTPRequestHandler, HTTPServer
              class H(BaseHTTPRequestHandler):
                def do_GET(self):
                  body=b'http_requests_total{namespace="metrics-lab",app="traffic-api",status="200"} 100\n'
                  self.send_response(200); self.end_headers(); self.wfile.write(body)
              HTTPServer(("0.0.0.0",8080),H).serve_forever()
          ports:
            - name: metrics
              containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-heavy
  namespace: logging-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-heavy
  template:
    metadata:
      labels:
        app: log-heavy
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command:
            - sh
            - -c
          args:
            - 'while true; do echo "ERROR payment timeout"; sleep 2; done'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-light
  namespace: logging-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-light
  template:
    metadata:
      labels:
        app: log-light
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command:
            - sh
            - -c
          args:
            - 'while true; do echo "ERROR retry"; sleep 10; done'
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-stable
  namespace: delivery-dev
spec:
  selector:
    app: checkout
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-canary
  namespace: delivery-dev
spec:
  selector:
    app: checkout
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

cat > "$COURSE_DIR/06/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ordered-build
  namespace: cicd-lab
spec:
  workspaces:
    - name: source
  tasks:
    - name: clone
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              echo source > $(workspaces.source.path)/app
    - name: test
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: test
            image: alpine:3.20
            script: |
              test -f $(workspaces.source.path)/app
      # TODO runAfter/workspace
    - name: package
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: package
            image: alpine:3.20
            script: |
              echo packaged
      # TODO runAfter/workspace
YAML
cat > "$COURSE_DIR/06/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ordered-build-
  namespace: cicd-lab
spec:
  pipelineRef:
    name: ordered-build
  workspaces:
    - name: source
      emptyDir: {}
YAML
cat > "$COURSE_DIR/07/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: parallel-quality
  namespace: cicd-lab
spec:
  tasks:
    - name: clone
      taskSpec:
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              sleep 1; echo cloned
    - name: lint
      taskSpec:
        steps:
          - name: lint
            image: alpine:3.20
            script: |
              sleep 3; echo lint
      # TODO runAfter clone
    - name: unit-test
      taskSpec:
        steps:
          - name: unit
            image: alpine:3.20
            script: |
              sleep 3; echo unit
      # TODO runAfter clone
    - name: report
      taskSpec:
        steps:
          - name: report
            image: alpine:3.20
            script: |
              echo report
      # TODO runAfter lint and unit-test
YAML
cat > "$COURSE_DIR/07/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: parallel-quality-
  namespace: cicd-lab
spec:
  pipelineRef:
    name: parallel-quality
YAML
touch "$COURSE_DIR/07/result.txt"
cat > "$COURSE_DIR/08/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: calculate-version
  namespace: cicd-lab
spec:
  results:
    - name: version
  steps:
    - name: calculate
      image: alpine:3.20
      script: |
        echo -n TODO > $(results.version.path)
YAML
cat > "$COURSE_DIR/08/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release-version
  namespace: cicd-lab
spec:
  tasks:
    - name: calculate-version
      taskRef:
        name: calculate-version
    - name: print-version
      params: [] # TODO pass calculate-version result
      taskSpec:
        params:
          - name: release
        steps:
          - name: print
            image: alpine:3.20
            script: |
              echo release=$(params.release)
YAML
cat > "$COURSE_DIR/08/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: release-version-
  namespace: cicd-lab
spec:
  pipelineRef:
    name: release-version
YAML

cat > "$COURSE_DIR/09/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: checkout
  namespace: delivery-dev
spec:
  replicas: 4
  strategy:
    canary:
      stableService: TODO
      canaryService: TODO
      steps: [] # TODO
  selector:
    matchLabels:
      app: checkout
  template:
    metadata:
      labels:
        app: checkout
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/10/analysis.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: checkout-success-rate
  namespace: delivery-dev
spec:
  metrics:
    - name: success-rate
      successCondition: TODO
      provider:
        prometheus:
          address: TODO
          query: TODO
YAML
touch "$COURSE_DIR/11/result.txt"

cat > "$COURSE_DIR/12/prometheus-job.yaml" <<'YAML'
  - job_name: metrics-lab
    kubernetes_sd_configs: [] # TODO
    relabel_configs: [] # TODO
YAML
cat > "$COURSE_DIR/13/queries.txt" <<'TXT'
# request rate:
# 5xx percentage:
# availability:
TXT
cat > "$COURSE_DIR/14/rule.yaml" <<'YAML'
groups:
  - name: delivery-ops
    rules:
      - alert: HighErrorRate
        expr: TODO
        for: TODO
        labels:
          severity: TODO
        annotations:
          summary: TODO
YAML
cat > "$COURSE_DIR/15/datasource.yaml" <<'YAML'
apiVersion: 1
datasources:
  - name: Loki
    uid: loki
    type: loki
    access: direct
    url: http://wrong-loki:3100
    isDefault: false
YAML
touch "$COURSE_DIR/15/result.txt"
cat > "$COURSE_DIR/16/queries.txt" <<'TXT'
# ERROR filter:
# count over 5m:
# count by pod:
TXT
touch "$COURSE_DIR/16/result.txt"
cat > "$COURSE_DIR/17/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  namespace: tracing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - "sleep 3600"
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://wrong:4317"
            - name: OTEL_SERVICE_NAME
              value: "TODO"
YAML
kubectl apply -f "$COURSE_DIR/17/deployment.yaml" >/dev/null
kubectl -n tracing delete job orders-api-trace-generator --ignore-not-found >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: orders-api-trace-generator
  namespace: tracing
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: telemetrygen
          image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.134.0
          args:
            - traces
            - --otlp-endpoint=jaeger-collector.tracing.svc:4317
            - --otlp-insecure
            - --service=orders-api
            - --traces=5
  backoffLimit: 3
YAML
kubectl -n tracing wait --for=condition=complete job/orders-api-trace-generator --timeout=180s
sleep 5
TRACE_RESPONSE="$(kubectl get --raw \
  '/api/v1/namespaces/tracing/services/http:jaeger-collector:16686/proxy/api/traces?service=orders-api&limit=1' \
  2>/dev/null || true)"
TRACE_ID="$(printf '%s' "$TRACE_RESPONSE" | sed -n 's/.*"traceID":"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$TRACE_ID" ] || TRACE_ID="trace-not-found-check-jaeger"
cat > "$COURSE_DIR/18/log.json" <<JSON
{"level":"ERROR","service":"orders-api","trace_id":"${TRACE_ID}","message":"payment timeout"}
JSON
touch "$COURSE_DIR/18/result.txt"
cat > "$COURSE_DIR/19/incident.yaml" <<'YAML'
symptoms:
  prometheus: "target traffic-api is down"
  loki: "health check returns HTTP 400 parse error"
  otlp: "wrong-collector:4317 connection refused"
YAML
cp "$COURSE_DIR/12/prometheus-job.yaml" "$COURSE_DIR/19/prometheus-job.yaml"
cp "$COURSE_DIR/15/datasource.yaml" "$COURSE_DIR/19/datasource.yaml"
cp "$COURSE_DIR/17/deployment.yaml" "$COURSE_DIR/19/deployment.yaml"
touch "$COURSE_DIR/19/report.md"
cat > "$COURSE_DIR/20/checklist.md" <<'MD'
# Timed verification
- [ ] Argo Application Synced/Healthy
- [ ] Flux Ready
- [ ] PipelineRun Succeeded
- [ ] Rollout Healthy
- [ ] Prometheus rule valid
- [ ] Loki health HTTP 200
- [ ] OTLP TCP 4317 reachable
MD

source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
echo "Delivery and Operations lab ready: $COURSE_DIR"
