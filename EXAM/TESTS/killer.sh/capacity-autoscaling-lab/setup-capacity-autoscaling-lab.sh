#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-capacity-autoscaling}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-capacity}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.1}"
VPA_CHART_VERSION="${VPA_CHART_VERSION:-0.9.0}"
KEDA_CHART_VERSION="${KEDA_CHART_VERSION:-2.18.1}"

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
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kind started, but kubectl cannot reach the cluster"
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_metrics_server() {
  info "Installing Metrics Server ${METRICS_SERVER_VERSION}"
  kubectl apply -f \
    "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" \
    >/dev/null

  if [ "$CLUSTER_PROVIDER" = "kind" ]; then
    if ! kubectl -n kube-system get deployment metrics-server \
      -o jsonpath='{.spec.template.spec.containers[0].args}' |
      grep -q -- '--kubelet-insecure-tls'; then
      kubectl -n kube-system patch deployment metrics-server --type json \
        -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
        >/dev/null
    fi
  fi

  kubectl -n kube-system rollout status deployment/metrics-server \
    --timeout=300s
}

install_vpa() {
  info "Installing VPA Helm chart ${VPA_CHART_VERSION}"
  helm repo add autoscaler https://kubernetes.github.io/autoscaler \
    --force-update >/dev/null
  helm upgrade --install vpa autoscaler/vertical-pod-autoscaler \
    --version "$VPA_CHART_VERSION" \
    --namespace vpa-system \
    --create-namespace \
    --wait \
    --timeout 5m >/dev/null
  kubectl wait --for=condition=Established \
    crd/verticalpodautoscalers.autoscaling.k8s.io --timeout=180s
}

install_keda() {
  info "Installing KEDA Helm chart ${KEDA_CHART_VERSION}"
  helm repo add kedacore https://kedacore.github.io/charts \
    --force-update >/dev/null
  helm upgrade --install keda kedacore/keda \
    --version "$KEDA_CHART_VERSION" \
    --namespace keda \
    --create-namespace \
    --wait \
    --timeout 5m >/dev/null
  kubectl wait --for=condition=Established \
    crd/scaledobjects.keda.sh --timeout=180s
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || die "helm is required when INSTALL_TOOLS=true"
  install_metrics_server
  install_vpa
  install_keda
else
  kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 ||
    die "Metrics API is required"
  kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1 ||
    die "VPA CRD is required"
  kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1 ||
    die "KEDA CRD is required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  for namespace in quota-lab limits-lab vpa-lab hpa-lab keda-lab; do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=true
  done
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done

for namespace in quota-lab limits-lab vpa-lab hpa-lab keda-lab; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

cat > "$COURSE_DIR/01/resourcequota.yaml" <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-capacity
  namespace: quota-lab
spec:
  hard:
    requests.cpu: 300m
    requests.memory: 256Mi
    limits.cpu: "1"
    limits.memory: 1Gi
    pods: "2"
YAML

kubectl apply -f "$COURSE_DIR/01/resourcequota.yaml" >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-api
  namespace: quota-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: quota-api
  template:
    metadata:
      labels:
        app: quota-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: 200m
              memory: 192Mi
            limits:
              cpu: 500m
              memory: 384Mi
YAML
touch "$COURSE_DIR/01/diagnosi.txt"

cat > "$COURSE_DIR/02/limitrange.yaml" <<'YAML'
apiVersion: v1
kind: LimitRange
metadata:
  name: application-defaults
  namespace: limits-lab
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 600m
        memory: 768Mi
      default:
        cpu: 800m
        memory: 1Gi
      max:
        cpu: "1"
        memory: 2Gi
YAML

cat > "$COURSE_DIR/02/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: defaults-demo
  namespace: limits-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  containers:
    - name: app
      image: nginx:1.27-alpine
YAML

kubectl apply -f "$COURSE_DIR/02/limitrange.yaml" >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-capacity
  namespace: limits-lab
spec:
  hard:
    requests.cpu: 500m
    requests.memory: 512Mi
    limits.cpu: "1"
    limits.memory: 2Gi
YAML
kubectl apply -f "$COURSE_DIR/02/pod.yaml" >/dev/null 2>&1 || true
touch "$COURSE_DIR/02/diagnosi.txt"

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendation-api
  namespace: vpa-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: recommendation-api
  template:
    metadata:
      labels:
        app: recommendation-api
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
          args:
            - |
              while true; do
                i=0
                while [ "${i}" -lt 150000 ]; do
                  i=$((i + 1))
                done
                sleep 0.1
              done
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 250m
              memory: 128Mi
YAML

cat > "$COURSE_DIR/03/vpa.yaml" <<'YAML'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: recommendation-api
  namespace: vpa-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: recommendation-api-wrong
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
      - containerName: worker
        minAllowed:
          cpu: 25m
          memory: 32Mi
        maxAllowed:
          cpu: 300m
          memory: 256Mi
        controlledResources:
          - cpu
          - memory
YAML
kubectl apply -f "$COURSE_DIR/03/vpa.yaml" >/dev/null
touch "$COURSE_DIR/03/recommendation.txt"

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-api
  namespace: hpa-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hpa-api
  template:
    metadata:
      labels:
        app: hpa-api
    spec:
      containers:
        - name: server
          image: registry.k8s.io/hpa-example
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 32Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hpa-api
  namespace: hpa-lab
spec:
  selector:
    app: hpa-api
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

cat > "$COURSE_DIR/04/hpa.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-api
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-api-wrong
  minReplicas: 1
  maxReplicas: 1
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 90
YAML

cat > "$COURSE_DIR/04/load-generator.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  namespace: hpa-lab
spec:
  restartPolicy: Never
  containers:
    - name: load
      image: busybox:1.36
      command:
        - /bin/sh
        - -c
      args:
        - |
          while sleep 0.01; do
            wget -q -O- http://hpa-api >/dev/null
          done
YAML
touch "$COURSE_DIR/04/result.txt"

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: queue-worker
  namespace: keda-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 0
  selector:
    matchLabels:
      app: queue-worker
  template:
    metadata:
      labels:
        app: queue-worker
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
          args:
            - |
              while true; do
                echo "processing scheduled workload"
                sleep 30
              done
          resources:
            requests:
              cpu: 20m
              memory: 16Mi
            limits:
              cpu: 100m
              memory: 64Mi
YAML

cat > "$COURSE_DIR/05/scaledobject.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: queue-worker
  namespace: keda-lab
spec:
  scaleTargetRef:
    name: queue-worker-wrong
  minReplicaCount: 0
  maxReplicaCount: 4
  pollingInterval: 10
  cooldownPeriod: 30
  triggers:
    - type: cron
      metadata:
        timezone: Europe/Rome
        start: "0 0 * * *"
        end: "59 23 * * *"
        desiredReplicas: "3"
YAML
kubectl apply -f "$COURSE_DIR/05/scaledobject.yaml" >/dev/null 2>&1 || true
touch "$COURSE_DIR/05/status.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Capacity and autoscaling lab ready: $COURSE_DIR"
kubectl get resourcequota -n quota-lab
kubectl get limitrange -n limits-lab
kubectl get vpa -n vpa-lab
kubectl get deployment -n hpa-lab
kubectl get deployment -n keda-lab
