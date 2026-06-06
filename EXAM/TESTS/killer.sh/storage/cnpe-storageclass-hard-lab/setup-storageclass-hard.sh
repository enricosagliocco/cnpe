#!/usr/bin/env bash
# =============================================================================
# CNPE Hard Lab — StorageClass / PV / PVC Troubleshooting
# Scenario: storage-hard
#
# Focus CNPE:
#   - Pod Pending / CrashLoopBackOff
#   - PVC Pending
#   - StorageClass errata
#   - PV local con nodeAffinity sbagliata
#   - headless Service per StatefulSet
#   - ConfigMap app per endpoint DB
#   - ConfigMap DB per mount path dati
#   - vincolo: NON modificare Deployment e StatefulSet applicativi
#
# Uso:
#   chmod +x setup-storageclass-hard.sh
#   ./setup-storageclass-hard.sh
#   ./setup-storageclass-hard.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-storage-hard}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

NS="storage-hard"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/storage-hard}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete pv db-local-pv cache-local-pv --ignore-not-found 2>/dev/null || true
  kubectl delete storageclass fast-local broken-local slow-manual --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=35g \
    --kubernetes-version="$K8S_VERSION" \
    --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

NODE_NAME="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

info "preparo path locali nel nodo minikube"
minikube -p "$PROFILE" ssh -- "sudo mkdir -p /mnt/cnpe/db /mnt/cnpe/cache && sudo chmod -R 777 /mnt/cnpe"

kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

cat > "$LAB_DIR/00-storage-broken.yaml" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: broken-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
reclaimPolicy: Retain
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow-manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: db-local-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: fast-local
  local:
    path: /mnt/cnpe/db
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          # BUG: nodo inesistente; il PVC può bindare, ma il Pod resta non schedulabile
          - wrong-node
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cache-local-pv
spec:
  capacity:
    storage: 512Mi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  # BUG: storageClass diversa dal PVC
  storageClassName: slow-manual
  local:
    path: /mnt/cnpe/cache
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${NODE_NAME}
EOF

cat > "$LAB_DIR/01-configmaps-broken.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: storage-hard
data:
  # BUG: app punta a Service inesistente e porta sbagliata
  DB_HOST: "postgres.storage-hard.svc.cluster.local"
  DB_PORT: "5433"
  DB_NAME: "appdb"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: storage-hard
data:
  POSTGRES_DB: "appdb"
  POSTGRES_USER: "app"
  POSTGRES_PASSWORD: "app"
  # BUG: path non coerente col volumeMount dello StatefulSet
  PGDATA: "/var/lib/postgresql/wrong/data"
EOF

cat > "$LAB_DIR/02-db-sts-do-not-edit.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: db-headless-wrong
  namespace: storage-hard
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - name: pg
    port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: storage-hard
  labels:
    app: db
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: pg
        envFrom:
        - configMapRef:
            name: db-config
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-local
      resources:
        requests:
          storage: 1Gi
EOF

cat > "$LAB_DIR/03-app-deploy-do-not-edit.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: storage-hard
  labels:
    app: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      initContainers:
      - name: wait-db
        image: busybox:1.36
        envFrom:
        - configMapRef:
            name: app-config
        command:
        - sh
        - -c
        - |
          echo "checking db ${DB_HOST}:${DB_PORT}"
          for i in $(seq 1 30); do
            nc -z "$DB_HOST" "$DB_PORT" && exit 0
            echo "db not ready"
            sleep 2
          done
          exit 1
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: app-config
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: storage-hard
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30082
EOF

cat > "$LAB_DIR/04-cache-pvc-pod-broken.yaml" <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache-pvc
  namespace: storage-hard
spec:
  accessModes:
  - ReadWriteOnce
  # BUG: nessun PV con questa StorageClass
  storageClassName: fast-cache
  resources:
    requests:
      storage: 512Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: cache-check
  namespace: storage-hard
  labels:
    app: cache-check
spec:
  containers:
  - name: check
    image: busybox:1.36
    command: ["sh", "-c", "echo ok > /cache/ok && sleep 3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    persistentVolumeClaim:
      claimName: cache-pvc
EOF

cat > "$LAB_DIR/99-apply-order.txt" <<'EOF'
Applicazione iniziale:
  00-storage-broken.yaml
  01-configmaps-broken.yaml
  02-db-sts-do-not-edit.yaml
  03-app-deploy-do-not-edit.yaml
  04-cache-pvc-pod-broken.yaml

Vincolo:
  NON modificare:
    - StatefulSet db
    - Deployment webapp

Puoi modificare:
  - StorageClass
  - PV/PVC
  - Service
  - ConfigMap
  - Secret se ne crei di supporto
EOF

kubectl apply -f "$LAB_DIR/00-storage-broken.yaml"
kubectl apply -f "$LAB_DIR/01-configmaps-broken.yaml"
kubectl apply -f "$LAB_DIR/02-db-sts-do-not-edit.yaml"
kubectl apply -f "$LAB_DIR/03-app-deploy-do-not-edit.yaml"
kubectl apply -f "$LAB_DIR/04-cache-pvc-pod-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Scenario: storage-hard
Namespace: storage-hard
Minikube profile: ${PROFILE}
Node name: ${NODE_NAME}

NodePort webapp:
  http://$(minikube -p "$PROFILE" ip 2>/dev/null):30082

File:
  /course/storage-hard/00-storage-broken.yaml
  /course/storage-hard/01-configmaps-broken.yaml
  /course/storage-hard/02-db-sts-do-not-edit.yaml
  /course/storage-hard/03-app-deploy-do-not-edit.yaml
  /course/storage-hard/04-cache-pvc-pod-broken.yaml
  /course/storage-hard/99-apply-order.txt

Vincolo:
  non modificare StatefulSet db e Deployment webapp.
EOF

kubectl -n "$NS" get pod,deploy,sts,svc,pvc
kubectl get pv,sc
ok "Storage hard lab pronto: $LAB_DIR"
