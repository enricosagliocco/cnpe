#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-observability-incident}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-observability}"
PROMETHEUS_STACK_VERSION="${PROMETHEUS_STACK_VERSION:-86.2.0}"
LOKI_VERSION="${LOKI_VERSION:-6.55.0}"
PROMTAIL_VERSION="${PROMTAIL_VERSION:-6.17.1}"
JAEGER_VERSION="${JAEGER_VERSION:-1.76.0}"
OTEL_COLLECTOR_VERSION="${OTEL_COLLECTOR_VERSION:-0.134.0}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
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
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_tools() {
  command -v helm >/dev/null || die "helm is required"
  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts \
    --force-update >/dev/null
  helm repo add grafana https://grafana.github.io/helm-charts \
    --force-update >/dev/null
  helm repo update >/dev/null

  info "Installing kube-prometheus-stack ${PROMETHEUS_STACK_VERSION}"
  helm upgrade --install monitoring \
    prometheus-community/kube-prometheus-stack \
    --version "$PROMETHEUS_STACK_VERSION" \
    --namespace monitoring \
    --create-namespace \
    --set grafana.adminPassword=admin \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
    --wait \
    --timeout 10m >/dev/null

  info "Installing Loki ${LOKI_VERSION}"
  helm upgrade --install loki grafana/loki \
    --version "$LOKI_VERSION" \
    --namespace monitoring \
    --set deploymentMode=SingleBinary \
    --set singleBinary.replicas=1 \
    --set backend.replicas=0 \
    --set read.replicas=0 \
    --set write.replicas=0 \
    --set loki.auth_enabled=false \
    --set loki.commonConfig.replication_factor=1 \
    --set loki.storage.type=filesystem \
    --set loki.useTestSchema=true \
    --wait \
    --timeout 10m >/dev/null

  info "Installing Promtail ${PROMTAIL_VERSION}"
  helm upgrade --install promtail grafana/promtail \
    --version "$PROMTAIL_VERSION" \
    --namespace monitoring \
    --set "config.clients[0].url=http://loki.monitoring.svc:3100/loki/api/v1/push" \
    --wait \
    --timeout 5m >/dev/null
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  install_tools
else
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1 ||
    die "Prometheus Operator CRDs are required"
  kubectl -n monitoring get service loki >/dev/null 2>&1 ||
    die "Loki service is required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  kubectl delete namespace observability-app tracing-lab \
    --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done
for namespace in observability-app tracing-lab; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: tracing-lab
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
          image: jaegertracing/all-in-one:${JAEGER_VERSION}
          env:
            - name: COLLECTOR_OTLP_ENABLED
              value: "true"
          ports:
            - name: query
              containerPort: 16686
            - name: zipkin
              containerPort: 9411
            - name: otlp-grpc
              containerPort: 4317
            - name: otlp-http
              containerPort: 4318
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: tracing-lab
spec:
  selector:
    app: jaeger
  ports:
    - name: query
      port: 16686
      targetPort: query
    - name: zipkin
      port: 9411
      targetPort: zipkin
    - name: otlp-grpc
      port: 4317
      targetPort: otlp-grpc
    - name: otlp-http
      port: 4318
      targetPort: otlp-http
YAML

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-api-code
  namespace: observability-app
data:
  app.py: |
    import json
    import os
    import random
    import time
    import urllib.request
    from http.server import BaseHTTPRequestHandler, HTTPServer

    requests = 0
    failures = 0

    def probe_backend(trace_id):
        global failures
        started = int(time.time() * 1000000)
        endpoint = os.environ["BACKEND_URL"]
        ok = True
        try:
            urllib.request.urlopen(endpoint, timeout=1).read()
        except Exception as exc:
            ok = False
            failures += 1
            print(json.dumps({
                "level": "ERROR",
                "service": "incident-api",
                "trace_id": trace_id,
                "message": str(exc),
                "backend": endpoint
            }), flush=True)
        span = [{
            "traceId": trace_id,
            "id": ("%016x" % random.getrandbits(64)),
            "name": "backend.request",
            "timestamp": started,
            "duration": max(1, int(time.time() * 1000000) - started),
            "localEndpoint": {"serviceName": "incident-api"},
            "tags": {"error": str(not ok).lower(), "backend": endpoint}
        }]
        try:
            request = urllib.request.Request(
                os.environ["ZIPKIN_ENDPOINT"],
                data=json.dumps(span).encode(),
                headers={"Content-Type": "application/json"}
            )
            urllib.request.urlopen(request, timeout=1).read()
        except Exception:
            pass
        return ok

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            global requests
            if self.path == "/metrics":
                body = (
                    "# TYPE platform_http_requests_total counter\n"
                    f"platform_http_requests_total{{service=\"incident-api\"}} {requests}\n"
                    "# TYPE platform_http_failures_total counter\n"
                    f"platform_http_failures_total{{service=\"incident-api\"}} {failures}\n"
                    "platform_deployments_total{service=\"incident-api\"} 20\n"
                    "platform_measurement_window_days{service=\"incident-api\"} 30\n"
                    "platform_deployment_failures_total{service=\"incident-api\"} 4\n"
                    "platform_deployment_lead_time_seconds_sum{service=\"incident-api\"} 14400\n"
                    "platform_deployment_lead_time_seconds_count{service=\"incident-api\"} 20\n"
                    "platform_incident_recovery_seconds_sum{service=\"incident-api\"} 5400\n"
                    "platform_incident_recovery_seconds_count{service=\"incident-api\"} 3\n"
                ).encode()
                self.send_response(200)
            else:
                requests += 1
                trace_id = "%032x" % random.getrandbits(128)
                ok = probe_backend(trace_id)
                body = json.dumps({"ready": ok, "trace_id": trace_id}).encode()
                self.send_response(200 if ok else 503)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def log_message(self, *_):
            return

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-api-config
  namespace: observability-app
data:
  BACKEND_URL: http://missing-database:8080
  ZIPKIN_ENDPOINT: http://jaeger-collector.tracing-lab.svc:9411/api/v2/spans
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-database
  namespace: observability-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: incident-database
  template:
    metadata:
      labels:
        app: incident-database
    spec:
      containers:
        - name: database
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: incident-database
  namespace: observability-app
spec:
  selector:
    app: incident-database
  ports:
    - name: http
      port: 8080
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-api
  namespace: observability-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: incident-api
  template:
    metadata:
      labels:
        app: incident-api
        observability: enabled
    spec:
      containers:
        - name: api
          image: python:3.12-alpine
          command:
            - python
            - /app/app.py
          envFrom:
            - configMapRef:
                name: incident-api-config
          ports:
            - name: metrics
              containerPort: 8080
          volumeMounts:
            - name: code
              mountPath: /app
          readinessProbe:
            httpGet:
              path: /metrics
              port: metrics
            periodSeconds: 5
      volumes:
        - name: code
          configMap:
            name: incident-api-code
---
apiVersion: v1
kind: Service
metadata:
  name: incident-api
  namespace: observability-app
  labels:
    app: incident-api
spec:
  selector:
    app: incident-api
  ports:
    - name: metrics
      port: 8080
      targetPort: metrics
YAML

cat > "$COURSE_DIR/01/monitoring.yaml" <<'YAML'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: incident-api
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
      - wrong-namespace # TODO observability-app
  selector:
    matchLabels:
      app: wrong-label # TODO incident-api
  endpoints:
    - port: http # TODO metrics
      path: /metrics
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: incident-api
  namespace: monitoring
spec:
  groups:
    - name: incident-api
      rules:
        - alert: IncidentApiHighErrorRate
          expr: TODO
          for: 0m # TODO 5m
          labels:
            severity: info # TODO critical
          annotations:
            summary: TODO
YAML
kubectl apply -f "$COURSE_DIR/01/monitoring.yaml" >/dev/null
touch "$COURSE_DIR/01/monitoring-check.txt"

cat > "$COURSE_DIR/02/loki-datasource.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        uid: loki
        type: loki
        access: direct # TODO proxy
        url: http://wrong-loki:3100
        isDefault: false
YAML
kubectl apply -f "$COURSE_DIR/02/loki-datasource.yaml" >/dev/null
cat > "$COURSE_DIR/02/queries.txt" <<'TXT'
# ERROR logs for incident-api:
# ERROR count over 5m grouped by pod:
# Extract trace_id from JSON:
TXT
touch "$COURSE_DIR/02/logging-check.txt"

cat > "$COURSE_DIR/03/otel-collector.yaml" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector
  namespace: tracing-lab
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 127.0.0.1:4317 # TODO 0.0.0.0:4317
    exporters:
      otlp:
        endpoint: wrong-jaeger:4317
        tls:
          insecure: true
    service:
      pipelines: {} # TODO traces pipeline
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: tracing-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:${OTEL_COLLECTOR_VERSION}
          args:
            - --config=/etc/otel/config.yaml
          ports:
            - name: otlp-grpc
              containerPort: 4317
          volumeMounts:
            - name: config
              mountPath: /etc/otel
      volumes:
        - name: config
          configMap:
            name: otel-collector
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: tracing-lab
spec:
  selector:
    app: otel-collector
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: otlp-grpc
YAML
kubectl apply -f "$COURSE_DIR/03/otel-collector.yaml" >/dev/null
cat > "$COURSE_DIR/03/trace-generator.yaml" <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  generateName: checkout-traces-
  namespace: tracing-lab
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: telemetrygen
          image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:${OTEL_COLLECTOR_VERSION}
          args:
            - traces
            - --otlp-endpoint=otel-collector.tracing-lab.svc:4317
            - --otlp-insecure
            - --service=checkout-api
            - --traces=10
  backoffLimit: 2
YAML
touch "$COURSE_DIR/03/tracing-check.txt"

cat > "$COURSE_DIR/04/platform-kpis.yaml" <<'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: platform-kpis
  namespace: monitoring
spec:
  groups:
    - name: platform-kpis
      interval: 1m
      rules:
        - record: platform:deployment_frequency_per_day
          expr: TODO
        - record: platform:change_failure_rate:ratio
          expr: TODO
        - record: platform:deployment_lead_time_seconds:avg
          expr: TODO
        - record: platform:mttr_seconds:avg
          expr: TODO
YAML
cat > "$COURSE_DIR/04/baseline.md" <<'MD'
# Platform baseline

| Indicator | Current | Target |
|---|---:|---:|
| Deployment frequency | TODO | >= 1/day |
| Change failure rate | TODO | < 15% |
| Lead time | TODO | < 10m |
| MTTR | TODO | < 20m |
| API availability | TODO | >= 99.9% |

## Improvement actions

- TODO
MD
touch "$COURSE_DIR/04/kpi-check.txt"

cat > "$COURSE_DIR/05/incident-api-config.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-api-config
  namespace: observability-app
data:
  BACKEND_URL: http://missing-database:8080
  ZIPKIN_ENDPOINT: http://jaeger-collector.tracing-lab.svc:9411/api/v2/spans
YAML
cat > "$COURSE_DIR/05/runbook.md" <<'MD'
# Incident report

## Detection

TODO

## Timeline and blast radius

TODO

## Correlation

- Prometheus evidence: TODO
- Loki evidence and trace ID: TODO
- Jaeger evidence: TODO

## Root cause

TODO

## Remediation and verification

TODO

## Rollback and prevention

TODO
MD
touch "$COURSE_DIR/05/incident-check.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Observability and incident lab ready: $COURSE_DIR"
info "Grafana: kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
info "Prometheus: kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"
info "Jaeger: kubectl -n tracing-lab port-forward svc/jaeger-collector 16686:16686"
kubectl -n observability-app get deployment,pods,services
