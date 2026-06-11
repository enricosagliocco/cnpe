#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-hpa-keda}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-hpa-keda}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    minikube)
      command -v minikube >/dev/null || die "minikube is required"
      if minikube status >/dev/null 2>&1; then
        info "Using existing minikube cluster"
      else
        info "Creating minikube cluster"
        minikube start --cpus=4 --memory=6144
      fi
      minikube update-context >/dev/null
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
    existing)
      info "Using the current kubectl context"
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac

  kubectl cluster-info >/dev/null 2>&1 ||
    die "kubectl cannot reach the selected Kubernetes cluster"
  kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
}

install_tools() {
  command -v helm >/dev/null || die "helm is required when INSTALL_TOOLS=true"

  info "Installing or updating Metrics Server"
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ \
    --force-update >/dev/null
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set 'args[0]=--kubelet-insecure-tls' \
    --wait --timeout 5m >/dev/null

  info "Installing or updating KEDA"
  helm repo add kedacore https://kedacore.github.io/charts \
    --force-update >/dev/null
  helm upgrade --install keda kedacore/keda \
    --namespace keda \
    --create-namespace \
    --wait --timeout 8m >/dev/null
}

verify_tools() {
  kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 ||
    die "Metrics Server APIService is not installed"
  kubectl wait apiservice/v1beta1.metrics.k8s.io \
    --for=condition=Available --timeout=180s >/dev/null
  kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1 ||
    die "KEDA ScaledObject CRD is not installed"
  kubectl -n keda rollout status deployment/keda-operator \
    --timeout=180s >/dev/null
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  install_tools
fi
verify_tools

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  info "Removing previously generated files"
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  directory="$COURSE_DIR/q$number"
  namespace="autoscale-q$number"
  mkdir -p "$directory"
  touch "$directory/evidence.txt"

  cat > "$directory/namespace.yaml" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
YAML

  cat > "$directory/workload.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: registry.k8s.io/hpa-example:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: $namespace
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
YAML

  cat > "$directory/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
rm -f setup-error.txt
kubectl apply -f namespace.yaml
kubectl apply -f workload.yaml
if [ -f supporting-resources.yaml ]; then
  kubectl apply -f supporting-resources.yaml
fi
if ! kubectl apply -f scenario.yaml 2>setup-error.txt; then
  echo "[INFO] scenario.yaml was rejected as intended; inspect setup-error.txt"
fi
kubectl -n "$(kubectl create --dry-run=client -f namespace.yaml -o jsonpath='{.metadata.name}')" \
  rollout status deployment/web --timeout=120s
SCRIPT

  cat > "$directory/remove-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
namespace="$(kubectl create --dry-run=client -f namespace.yaml -o jsonpath='{.metadata.name}')"
kubectl delete namespace "$namespace" --ignore-not-found --wait=true
rm -f setup-error.txt
SCRIPT
  chmod +x "$directory/create-resources.sh" "$directory/remove-resources.sh"
done

cat > "$COURSE_DIR/q01/workload.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: autoscale-q01
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
        - name: web
          image: registry.k8s.io/hpa-example:latest
          ports: [{containerPort: 80}]
          resources:
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata: {name: web, namespace: autoscale-q01}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
YAML

cat > "$COURSE_DIR/q01/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
  namespace: autoscale-q01
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
YAML

cat > "$COURSE_DIR/q02/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
  namespace: autoscale-q02
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 100m}
YAML

cat > "$COURSE_DIR/q03/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
  namespace: autoscale-q03
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: AverageValue
          averageUtilization: 60
YAML

cat > "$COURSE_DIR/q04/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q04}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 6
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 100m}
YAML

cat > "$COURSE_DIR/q05/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q05}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: memory
        target: {type: Utilization, averageUtilization: 70}
YAML

cat > "$COURSE_DIR/q06/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q06}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 100m}
    - type: Resource
      resource:
        name: memori
        target: {type: AverageValue, averageValue: 64Mi}
YAML

cat > "$COURSE_DIR/q07/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q07}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 8
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 100m}
YAML

cat > "$COURSE_DIR/q08/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q08}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 50m}
YAML

cat > "$COURSE_DIR/q09/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q09}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 50m}
YAML

cat > "$COURSE_DIR/q10/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: autoscale-q10}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 2
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: Utilization, averageUtilization: 90}
YAML
cat > "$COURSE_DIR/q10/load-generator.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: load-generator, namespace: autoscale-q10}
spec:
  containers:
    - name: load
      image: busybox:1.36
      command: [sh, -c, "while sleep 0.01; do wget -q -O- http://web; done"]
YAML
cp "$COURSE_DIR/q10/load-generator.yaml" "$COURSE_DIR/q06/load-generator.yaml"
sed -i 's/autoscale-q10/autoscale-q06/g' "$COURSE_DIR/q06/load-generator.yaml"
cp "$COURSE_DIR/q10/load-generator.yaml" "$COURSE_DIR/q08/load-generator.yaml"
sed -i 's/autoscale-q10/autoscale-q08/g' "$COURSE_DIR/q08/load-generator.yaml"

cat > "$COURSE_DIR/q11/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q11}
spec:
  scaleTargetRef: {name: worker}
  minReplicaCount: 0
  maxReplicaCount: 5
  triggers:
    - type: cpu
      metricType: Utilization
      metadata: {value: "50"}
YAML

cat > "$COURSE_DIR/q12/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q12}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 5
  maxReplicaCount: 2
  cooldownPeriod: 30
  triggers:
    - type: cpu
      metricType: Utilization
      metadata: {value: "50"}
YAML

cat > "$COURSE_DIR/q13/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q13}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 0
  maxReplicaCount: 5
  triggers:
    - type: cron
      metadata:
        timezone: Europe/Roma
        start: "0 * * * *"
        end: "30 * * * *"
        desiredReplicas: "2"
YAML

cat > "$COURSE_DIR/q14/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q14}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 0
  maxReplicaCount: 5
  triggers:
    - type: cron
      metadata:
        timezone: Europe/Rome
        start: "0 * * * *"
        end: "30 * * * *"
YAML

cat > "$COURSE_DIR/q15/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: web
  namespace: autoscale-q15
  annotations:
    autoscaling.keda.sh/paused: "true"
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
    - type: cpu
      metricType: Utilization
      metadata: {value: "50"}
YAML

cat > "$COURSE_DIR/q16/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q16}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 6
  pollingInterval: 5
  fallback:
    failureThreshold: 30
    replicas: 2
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.invalid
        query: sum(http_requests_total)
        threshold: "10"
YAML

cat > "$COURSE_DIR/q17/supporting-resources.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata: {name: prometheus-auth, namespace: autoscale-q17}
type: Opaque
stringData:
  username: autoscaler
  password: training
YAML
cat > "$COURSE_DIR/q17/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata: {name: prometheus-auth, namespace: autoscale-q17}
spec:
  secretTargetRef:
    - parameter: username
      name: prometheus-auth
      key: user
    - parameter: password
      name: prometheus-auth
      key: password
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q17}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.invalid
        query: sum(http_requests_total)
        threshold: "10"
        authModes: basic
      authenticationRef: {name: prometheus-auth}
YAML

for number in 18 19 20; do
  namespace="autoscale-q$number"
  cat > "$COURSE_DIR/q$number/supporting-resources.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata: {name: mock-prometheus, namespace: $namespace}
spec:
  replicas: 1
  selector: {matchLabels: {app: mock-prometheus}}
  template:
    metadata: {labels: {app: mock-prometheus}}
    spec:
      containers:
        - name: server
          image: python:3.12-alpine
          command:
            - python
            - -c
            - |
              import json
              from http.server import BaseHTTPRequestHandler, HTTPServer
              class H(BaseHTTPRequestHandler):
                def do_GET(self):
                  value = "25" if "queue_depth" in self.path else "0"
                  body = json.dumps({"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[0,value]}]}}).encode()
                  self.send_response(200); self.send_header("Content-Type","application/json")
                  self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
                def log_message(self, *_): pass
              HTTPServer(("0.0.0.0", 9090), H).serve_forever()
          ports: [{containerPort: 9090}]
---
apiVersion: v1
kind: Service
metadata: {name: mock-prometheus, namespace: $namespace}
spec:
  selector: {app: mock-prometheus}
  ports: [{port: 9090, targetPort: 9090}]
YAML
done

cat > "$COURSE_DIR/q18/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q18}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.autoscale-q18.svc:9090
        query: queue_depth
        threshold: "10"
YAML

cat > "$COURSE_DIR/q19/scenario.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q19}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 5
  pollingInterval: 5
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://mock-prometheus.autoscale-q19.svc:9090
        query: missing_metric
        threshold: "10"
YAML

cat > "$COURSE_DIR/q20/scenario.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: manual-web, namespace: autoscale-q20}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: AverageValue, averageValue: 200m}
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: web, namespace: autoscale-q20}
spec:
  scaleTargetRef: {name: web}
  minReplicaCount: 1
  maxReplicaCount: 5
  pollingInterval: 5
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://mock-prometheus.autoscale-q20.svc:9090
        query: queue_depth
        threshold: "10"
YAML

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
cp "$SCRIPT_DIR/README.md" "$COURSE_DIR/README.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "HPA and KEDA lab ready: $COURSE_DIR"
info "Kubernetes cluster ready using provider: $CLUSTER_PROVIDER"
info "No question resources were applied; use qNN/create-resources.sh"
