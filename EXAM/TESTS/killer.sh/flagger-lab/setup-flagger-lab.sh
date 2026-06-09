#!/usr/bin/env bash
set -euo pipefail

FLAGGER_VERSION="${FLAGGER_VERSION:-1.43.0}"
LOADTESTER_VERSION="${LOADTESTER_VERSION:-0.37.0}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-flagger}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-flagger-lab}"
LAB_NAMESPACE="${LAB_NAMESPACE:-flagger-lab}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        info "Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
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
      kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

command -v kubectl >/dev/null || die "kubectl is required"
command -v helm >/dev/null || die "Helm 3 is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi
if [ "$LAB_FORCE" = "true" ]; then
  kubectl delete namespace "$LAB_NAMESPACE" --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

info "Installing Flagger ${FLAGGER_VERSION}"
helm repo add flagger https://flagger.app >/dev/null 2>&1 || true
helm repo update flagger >/dev/null
helm upgrade --install flagger flagger/flagger \
  --version "$FLAGGER_VERSION" \
  --namespace flagger-system \
  --create-namespace \
  --set meshProvider=kubernetes \
  --wait --timeout=5m
helm upgrade --install flagger-loadtester flagger/loadtester \
  --version "$LOADTESTER_VERSION" \
  --namespace flagger-system \
  --wait --timeout=5m

kubectl create namespace "$LAB_NAMESPACE" --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null
kubectl -n flagger-system rollout status deployment/flagger --timeout=300s
kubectl -n flagger-system rollout status deployment/flagger-loadtester --timeout=300s

for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done

cat > "$COURSE_DIR/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  minReadySeconds: 3
  progressDeadlineSeconds: 60
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.9.1
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
YAML

for q in $(seq -w 1 20); do
  cp "$COURSE_DIR/deployment.yaml" "$COURSE_DIR/$q/deployment.yaml"
done

cat > "$COURSE_DIR/01/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: TODO
  targetRef: {} # TODO apps/v1 Deployment podinfo
  service: {} # TODO port 9898
  analysis:
    interval: 1m # TODO 10s
    threshold: 3
    iterations: 2
    metrics: []
YAML

cat > "$COURSE_DIR/02/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: v1
    kind: StatefulSet
    name: missing
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 2
    metrics: []
YAML

cat > "$COURSE_DIR/03/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 80 # TODO 9898
    targetPort: wrong
    portDiscovery: false
    timeout: 1s
  analysis:
    interval: 10s
    threshold: 3
    iterations: 2
    metrics: []
YAML

cat > "$COURSE_DIR/04/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
    portDiscovery: true
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 100
    stepWeight: 20
    iterations: 2
    metrics: []
YAML
touch "$COURSE_DIR/04/evidence.txt"

cat > "$COURSE_DIR/05/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 1 # TODO 5
    metrics: []
YAML

for q in 06 07; do
  cat > "$COURSE_DIR/$q/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
    portDiscovery: true
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    metrics: []
YAML
  touch "$COURSE_DIR/$q/evidence.txt"
done

cat > "$COURSE_DIR/08/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    metrics: [] # TODO request-success-rate 99 and request-duration 500
YAML

cat > "$COURSE_DIR/09/metric-template.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: request-count
  namespace: flagger-lab
spec:
  provider:
    type: prometheus
    address: http://prometheus.monitoring:9090
  query: TODO
YAML
cat > "$COURSE_DIR/09/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    metrics:
      - name: request-count
        templateRef:
          name: TODO
        thresholdRange:
          min: 1
YAML

cp "$COURSE_DIR/09/metric-template.yaml" "$COURSE_DIR/10/metric-template.yaml"
cat > "$COURSE_DIR/10/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    metrics:
      - name: request-count
        templateRef:
          name: request-count
        templateVariables: {} # TODO service, namespace, threshold
        thresholdRange: {} # TODO
YAML

cat > "$COURSE_DIR/11/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    metrics: []
    webhooks:
      - name: pre-rollout-check
        type: pre-rollout
        url: TODO
        timeout: 5s
        metadata: {} # TODO command and type
YAML

cat > "$COURSE_DIR/12/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    metrics: []
    webhooks:
      - name: load-test
        type: rollout
        url: http://flagger-loadtester.flagger-system/
        timeout: 5s
        metadata:
          cmd: TODO
YAML

cat > "$COURSE_DIR/13/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    metrics: []
    webhooks:
      - name: promotion-gate
        type: TODO
        url: http://flagger-loadtester.flagger-system/gate/approve
        timeout: 5s # TODO 30s
YAML

cat > "$COURSE_DIR/14/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    metrics: []
    webhooks: [] # TODO post-rollout
YAML
touch "$COURSE_DIR/14/evidence.txt"

cat > "$COURSE_DIR/15/alert-provider.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: AlertProvider
metadata:
  name: local-receiver
  namespace: flagger-lab
spec:
  type: TODO
  address: TODO
  secretRef: {} # TODO optional credentials
YAML
cat > "$COURSE_DIR/15/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    metrics: []
    alerts: [] # TODO info and error using local-receiver
YAML

cat > "$COURSE_DIR/16/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 3
    stepWeight: 10 # TODO 100
    metrics: []
    webhooks: [] # TODO confirmation gate
YAML

cat > "$COURSE_DIR/17/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: nginx # TODO supported A/B provider
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    match: [] # TODO x-canary=insider
    metrics: []
YAML

cat > "$COURSE_DIR/18/httproute.yaml" <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  parentRefs: [] # TODO Gateway
  hostnames: [] # TODO
  rules: [] # TODO backend podinfo
YAML
cat > "$COURSE_DIR/18/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: flagger-lab
spec:
  provider: gatewayapi:v1
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
    gatewayRefs: [] # TODO HTTPRoute reference
  analysis:
    interval: 10s
    threshold: 3
    maxWeight: 50
    stepWeight: 10
    metrics: []
YAML
touch "$COURSE_DIR/18/evidence.txt"

cat > "$COURSE_DIR/19/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: broken
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: v1
    kind: Service
    name: missing
  service:
    port: 0
    targetPort: absent
  analysis:
    interval: invalid
    threshold: -1
    iterations: 0
    metrics: []
YAML
touch "$COURSE_DIR/19/report.md"

cat > "$COURSE_DIR/20/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: final-api
  namespace: flagger-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: final-api
  template:
    metadata:
      labels:
        app: final-api
    spec:
      containers:
        - name: api
          image: ghcr.io/stefanprodan/podinfo:6.9.1
          ports:
            - name: http
              containerPort: 9898
YAML
cat > "$COURSE_DIR/20/metric-template.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: final-health
  namespace: flagger-lab
spec:
  provider: {} # TODO
  query: TODO
YAML
cat > "$COURSE_DIR/20/alert-provider.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: AlertProvider
metadata:
  name: final-alerts
  namespace: flagger-lab
spec: {} # TODO
YAML
cat > "$COURSE_DIR/20/canary.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: final-api
  namespace: flagger-lab
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: final-api
  service:
    port: 9898
  analysis:
    interval: 10s
    threshold: 3
    iterations: 5
    metrics: [] # TODO custom metric
    webhooks: [] # TODO load and promotion gate
    alerts: [] # TODO
YAML
touch "$COURSE_DIR/20/final-report.md"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/../lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Flagger lab ready: $COURSE_DIR"
info "Controller logs: kubectl -n flagger-system logs deploy/flagger -f"
info "Canaries: kubectl -n $LAB_NAMESPACE get canaries"
