#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-platform-efficiency}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-existing}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-efficiency}"
PROMETHEUS_CHART_VERSION="${PROMETHEUS_CHART_VERSION:-29.10.0}"
OPENCOST_CHART_VERSION="${OPENCOST_CHART_VERSION:-2.5.22}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a Kubernetes cluster"
      ;;
    kind)
      command -v kind >/dev/null || die "kind is required"
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        info "Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
        local config
        config="$(mktemp)"
        cat > "$config" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
YAML
        info "Creating three-node kind cluster: $KIND_CLUSTER_NAME"
        kind create cluster --name "$KIND_CLUSTER_NAME" \
          --config "$config" --wait 180s
        rm -f "$config"
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_cost_tools() {
  info "Installing Prometheus chart ${PROMETHEUS_CHART_VERSION}"
  helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts \
    --force-update >/dev/null
  helm upgrade --install prometheus prometheus-community/prometheus \
    --version "$PROMETHEUS_CHART_VERSION" \
    --namespace prometheus-system \
    --create-namespace \
    --set prometheus-pushgateway.enabled=false \
    --set alertmanager.enabled=false \
    --set server.persistentVolume.enabled=false \
    --wait \
    --timeout 8m >/dev/null

  info "Installing OpenCost chart ${OPENCOST_CHART_VERSION}"
  helm repo add opencost https://opencost.github.io/opencost-helm-chart \
    --force-update >/dev/null
  helm upgrade --install opencost opencost/opencost \
    --version "$OPENCOST_CHART_VERSION" \
    --namespace opencost \
    --create-namespace \
    --set opencost.prometheus.internal.namespaceName=prometheus-system \
    --set opencost.prometheus.internal.serviceName=prometheus-server \
    --set opencost.prometheus.internal.port=80 \
    --set opencost.exporter.defaultClusterId=cnpe-efficiency \
    --set opencost.customPricing.enabled=true \
    --set opencost.customPricing.provider=custom \
    --set-string opencost.customPricing.costModel.CPU=0.04 \
    --set-string opencost.customPricing.costModel.RAM=0.005 \
    --set-string opencost.customPricing.costModel.storage=0.0001 \
    --wait \
    --timeout 8m >/dev/null
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

node_count="$(kubectl get nodes --no-headers | wc -l)"
[ "$node_count" -ge 2 ] ||
  die "This lab requires at least two Kubernetes nodes"

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || die "helm is required when INSTALL_TOOLS=true"
  install_cost_tools
else
  kubectl -n opencost get service opencost >/dev/null 2>&1 ||
    die "OpenCost service is required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  for namespace in tenant-a tenant-b shared-services architecture-lab; do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=true
  done
  kubectl delete persistentvolume architecture-data-pv \
    --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done
for namespace in tenant-a tenant-b shared-services architecture-lab; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done
kubectl label namespace tenant-a tenant=tenant-a --overwrite >/dev/null
kubectl label namespace tenant-b tenant=tenant-b --overwrite >/dev/null
kubectl label namespace shared-services platform=shared --overwrite >/dev/null

nodes=($(kubectl get nodes -o name | sed 's#node/##'))
for index in "${!nodes[@]}"; do
  zone="$((index % 2 + 1))"
  kubectl label node "${nodes[$index]}" \
    "topology.kubernetes.io/zone=zone-${zone}" --overwrite >/dev/null
done

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-api
  namespace: shared-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shared-api
  template:
    metadata:
      labels:
        app: shared-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: shared-api
  namespace: shared-services
spec:
  selector:
    app: shared-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: tenant-a-client
  namespace: tenant-a
  labels:
    app: tenant-client
spec:
  containers:
    - name: client
      image: curlimages/curl:8.11.1
      command:
        - /bin/sh
        - -c
      args:
        - sleep 3600
---
apiVersion: v1
kind: Pod
metadata:
  name: tenant-b-client
  namespace: tenant-b
  labels:
    app: tenant-client
spec:
  containers:
    - name: client
      image: curlimages/curl:8.11.1
      command:
        - /bin/sh
        - -c
      args:
        - sleep 3600
YAML

cat > "$COURSE_DIR/01/network-policies.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: shared-api-ingress
  namespace: shared-services
spec:
  podSelector:
    matchLabels:
      app: shared-api
  policyTypes:
    - Ingress
  ingress: [] # TODO allow only tenant-a on TCP 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-a-egress
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress: [] # TODO DNS and shared-api only
YAML
kubectl apply -f "$COURSE_DIR/01/network-policies.yaml" >/dev/null
touch "$COURSE_DIR/01/connectivity.txt"

cat > "$COURSE_DIR/02/storage.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: architecture-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate # TODO WaitForFirstConsumer
reclaimPolicy: Delete # TODO Retain
allowVolumeExpansion: false
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: architecture-data-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: architecture-local
  local:
    path: /tmp/architecture-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - TODO_NODE
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: architecture-data
  namespace: architecture-lab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: architecture-local
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-consumer
  namespace: architecture-lab
spec:
  containers:
    - name: app
      image: busybox:1.36
      command:
        - /bin/sh
        - -c
      args:
        - echo ready > /data/status && sleep 3600
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: architecture-data
YAML
touch "$COURSE_DIR/02/storage-check.txt"

cat > "$COURSE_DIR/03/compute.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resilient-api
  namespace: architecture-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resilient-api
  template:
    metadata:
      labels:
        app: resilient-api
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/rack # TODO zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: resilient-api
      containers:
        - name: api
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 128Mi
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: resilient-api
  namespace: architecture-lab
spec:
  minAvailable: 3 # TODO 2
  selector:
    matchLabels:
      app: resilient-api
YAML
kubectl apply -f "$COURSE_DIR/03/compute.yaml" >/dev/null
touch "$COURSE_DIR/03/scheduling.txt"

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: overprovisioned-api
  namespace: tenant-a
  labels:
    cost-center: payments
spec:
  replicas: 2
  selector:
    matchLabels:
      app: overprovisioned-api
  template:
    metadata:
      labels:
        app: overprovisioned-api
        cost-center: payments
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: "1"
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 2Gi
YAML

cat > "$COURSE_DIR/04/usage.csv" <<'CSV'
sample,cpu_m,memory_mi
1,90,140
2,120,165
3,140,180
4,160,205
5,180,220
6,200,240
CSV
cat > "$COURSE_DIR/04/right-sized-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: overprovisioned-api
  namespace: tenant-a
  labels:
    cost-center: payments
spec:
  replicas: 2
  selector:
    matchLabels:
      app: overprovisioned-api
  template:
    metadata:
      labels:
        app: overprovisioned-api
        cost-center: payments
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          resources: {} # TODO right-size from usage.csv
YAML
touch "$COURSE_DIR/04/allocation-before.json"
touch "$COURSE_DIR/04/allocation-after.json"
touch "$COURSE_DIR/04/calculation.txt"

cat > "$COURSE_DIR/05/tenant-controls.yaml" <<'YAML'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tenant-standard
value: 1000
globalDefault: false
description: Standard tenant workload priority
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-budget
  namespace: tenant-a
spec:
  hard: {} # TODO
---
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-defaults
  namespace: tenant-a
spec:
  limits: [] # TODO
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: priority-budget
  namespace: tenant-a
spec:
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values:
          - tenant-standard
  hard:
    pods: "1" # TODO 4
YAML
kubectl apply -f - <<'YAML'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tenant-standard
value: 1000
globalDefault: false
description: Standard tenant workload priority
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: priority-budget
  namespace: tenant-a
spec:
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values:
          - tenant-standard
  hard:
    pods: "1"
YAML

cat > "$COURSE_DIR/05/workload.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-worker
  namespace: tenant-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tenant-worker
  template:
    metadata:
      labels:
        app: tenant-worker
    spec:
      priorityClassName: tenant-standard
      containers:
        - name: worker
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
          args:
            - sleep 3600
YAML
touch "$COURSE_DIR/05/tenant-checks.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Platform architecture and efficiency lab ready: $COURSE_DIR"
info "OpenCost API: kubectl -n opencost port-forward svc/opencost 9003:9003"
kubectl get nodes -L topology.kubernetes.io/zone
kubectl -n architecture-lab get deploy,pods,pdb
