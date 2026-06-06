#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-delivery-ops}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  echo "$COURSE_DIR already initialized; use LAB_FORCE=true"; exit 1
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
  helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace --wait
  helm upgrade --install prometheus prometheus-community/prometheus -n prometheus --create-namespace --wait
  helm upgrade --install loki grafana/loki -n monitoring --create-namespace \
    --set deploymentMode=SingleBinary \
    --set singleBinary.replicas=1 \
    --set backend.replicas=0 --set read.replicas=0 --set write.replicas=0 \
    --set loki.auth_enabled=false \
    --set loki.commonConfig.replication_factor=1 \
    --set loki.useTestSchema=true --wait
  kubectl apply -f https://github.com/fluxcd/flux2/releases/download/v2.8.8/install.yaml
  kubectl apply -f https://infra.tekton.dev/releases/pipeline/previous/v1.9.0/release.yaml
  kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
  kubectl -n flux-system rollout status deploy/source-controller --timeout=300s
  kubectl -n flux-system rollout status deploy/kustomize-controller --timeout=300s
  kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: jaeger, namespace: tracing}
spec:
  replicas: 1
  selector: {matchLabels: {app: jaeger}}
  template:
    metadata: {labels: {app: jaeger}}
    spec:
      containers:
        - name: jaeger
          image: jaegertracing/all-in-one:1.75.0
          ports:
            - {name: otlp-grpc, containerPort: 4317}
            - {name: query, containerPort: 16686}
---
apiVersion: v1
kind: Service
metadata: {name: jaeger-collector, namespace: tracing}
spec:
  selector: {app: jaeger}
  ports:
    - {name: otlp-grpc, port: 4317, targetPort: 4317}
    - {name: query, port: 16686, targetPort: 16686}
YAML
fi

cat > "$COURSE_DIR/01/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: storefront, namespace: argocd}
spec:
  project: default
  source: {repoURL: TODO, path: TODO, targetRevision: TODO}
  destination: {server: https://kubernetes.default.svc, namespace: TODO}
  syncPolicy: {} # TODO
YAML
cp "$COURSE_DIR/01/application.yaml" "$COURSE_DIR/02/application.yaml"

cat > "$COURSE_DIR/03/source.yaml" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata: {name: platform-source, namespace: flux-system}
spec:
  interval: 10m
  url: https://github.com/fluxcd/flux2-kustomize-helm-example
  ref: {branch: develop}
YAML
cat > "$COURSE_DIR/04/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: {name: platform-staging, namespace: flux-system}
spec: {} # TODO
YAML
cat > "$COURSE_DIR/05/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: drift-demo, namespace: delivery-dev}
spec:
  replicas: 2
  selector: {matchLabels: {app: drift-demo}}
  template:
    metadata: {labels: {app: drift-demo}}
    spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
kubectl apply -f "$COURSE_DIR/05/deployment.yaml" >/dev/null

cat > "$COURSE_DIR/06/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: ordered-build, namespace: cicd-lab}
spec:
  workspaces: [{name: source}]
  tasks:
    - name: clone
      taskSpec:
        workspaces: [{name: source}]
        steps: [{name: clone, image: alpine:3.20, script: "echo source > $(workspaces.source.path)/app"}]
    - name: test
      taskSpec:
        workspaces: [{name: source}]
        steps: [{name: test, image: alpine:3.20, script: "test -f $(workspaces.source.path)/app"}]
      # TODO runAfter/workspace
    - name: package
      taskSpec:
        workspaces: [{name: source}]
        steps: [{name: package, image: alpine:3.20, script: "echo packaged"}]
      # TODO runAfter/workspace
YAML
cp "$COURSE_DIR/06/pipeline.yaml" "$COURSE_DIR/07/pipeline.yaml"
cat > "$COURSE_DIR/08/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: calculate-version, namespace: cicd-lab}
spec:
  results: [{name: version}]
  steps:
    - name: calculate
      image: alpine:3.20
      script: 'echo -n TODO > $(results.version.path)'
YAML

cat > "$COURSE_DIR/09/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata: {name: checkout, namespace: delivery-dev}
spec:
  replicas: 4
  strategy:
    canary:
      stableService: TODO
      canaryService: TODO
      steps: [] # TODO
  selector: {matchLabels: {app: checkout}}
  template:
    metadata: {labels: {app: checkout}}
    spec: {containers: [{name: app, image: nginx:1-alpine}]}
YAML
cat > "$COURSE_DIR/10/analysis.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata: {name: checkout-success-rate, namespace: delivery-dev}
spec:
  metrics:
    - name: success-rate
      successCondition: TODO
      provider: {prometheus: {address: TODO, query: TODO}}
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
        labels: {severity: TODO}
        annotations: {summary: TODO}
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
metadata: {name: orders-api, namespace: tracing}
spec:
  replicas: 1
  selector: {matchLabels: {app: orders-api}}
  template:
    metadata: {labels: {app: orders-api}}
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: [sh, -c, "sleep 3600"]
          env:
            - {name: OTEL_EXPORTER_OTLP_ENDPOINT, value: "http://wrong:4317"}
            - {name: OTEL_SERVICE_NAME, value: "TODO"}
YAML
cat > "$COURSE_DIR/18/log.json" <<'JSON'
{"level":"ERROR","service":"orders-api","trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","message":"payment timeout"}
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

touch "$COURSE_DIR/.initialized"
echo "Delivery and Operations lab ready: $COURSE_DIR"
