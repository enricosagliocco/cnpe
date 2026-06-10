#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-resource-governance}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-resource-governance}"
NAMESPACE="resource-governance"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=4096
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
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kind started, but kubectl cannot reach the cluster"
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  info "Removing previous lab resources"
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

mkdir -p "$COURSE_DIR/01"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: LimitRange
metadata:
  name: container-policy
  namespace: resource-governance
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 300m
        memory: 256Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: 500m
        memory: 512Mi
      maxLimitRequestRatio:
        cpu: "4"
        memory: "2"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-budget
  namespace: resource-governance
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "5"
    services: "1"
    configmaps: "3"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-settings
  namespace: resource-governance
data:
  mode: stable
---
apiVersion: v1
kind: Service
metadata:
  name: platform-api
  namespace: resource-governance
spec:
  selector:
    app: platform-api
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-api
  namespace: resource-governance
spec:
  replicas: 2
  selector:
    matchLabels:
      app: platform-api
  template:
    metadata:
      labels:
        app: platform-api
    spec:
      containers:
        - name: api
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args:
            - netexec
            - --http-port=8080
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 400m
              memory: 512Mi
YAML

cat > "$COURSE_DIR/01/defaulted-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: defaulted-pod
  namespace: resource-governance
  labels:
    app: defaulted-pod
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
YAML

cat > "$COURSE_DIR/01/oversized-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: oversized-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 600m
          memory: 64Mi
        limits:
          cpu: 700m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/01/burst-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: burst-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/01/batch-worker.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-worker
  namespace: resource-governance
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: batch-worker
  template:
    metadata:
      labels:
        app: batch-worker
    spec:
      containers:
        - name: worker
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: 300m
              memory: 192Mi
            limits:
              cpu: 500m
              memory: 384Mi
YAML

cat > "$COURSE_DIR/01/temporary-settings.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: temporary-settings
  namespace: resource-governance
data:
  purpose: temporary
YAML

cat > "$COURSE_DIR/01/worker-settings.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-settings
  namespace: resource-governance
data:
  concurrency: "2"
YAML

cat > "$COURSE_DIR/01/extra-service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: batch-worker
  namespace: resource-governance
spec:
  selector:
    app: batch-worker
  ports:
    - port: 80
      targetPort: 80
YAML

touch "$COURSE_DIR/01/evidence.txt"
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

kubectl -n "$NAMESPACE" rollout status deployment/platform-api --timeout=120s

info "ResourceQuota and LimitRange lab ready: $COURSE_DIR"
kubectl -n "$NAMESPACE" get deployment,pods,service,configmap
kubectl -n "$NAMESPACE" get resourcequota,limitrange
