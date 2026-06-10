#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-storage-troubleshooting}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-existing}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-storage}"
NAMESPACE="storage-lab"
PV_NAME="cnpe-database-pv"

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
  kubectl delete persistentvolume "$PV_NAME" --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null

cat > "$COURSE_DIR/01/database-config.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: database-config
  namespace: storage-lab
data:
  data-path: /var/lib/postgresql/wrong
YAML

cat > "$COURSE_DIR/01/app-config.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: storage-lab
data:
  DB_HOST: database-wrong
  DB_PORT: "5432"
YAML

cat > "$COURSE_DIR/01/database-pv.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cnpe-database-pv
  labels:
    storage.cnpe.io/database: mysql
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: cnpe-manual
  hostPath:
    path: /tmp/cnpe-storage-lab/postgresql
    type: DirectoryOrCreate
YAML

touch "$COURSE_DIR/01/diagnosi.txt"

kubectl apply -f "$COURSE_DIR/01/database-config.yaml" >/dev/null
kubectl apply -f "$COURSE_DIR/01/app-config.yaml" >/dev/null
kubectl apply -f "$COURSE_DIR/01/database-pv.yaml" >/dev/null

kubectl -n "$NAMESPACE" create secret generic database-secret \
  --from-literal=POSTGRES_DB=orders \
  --from-literal=POSTGRES_USER=orders \
  --from-literal=POSTGRES_PASSWORD=cnpe-training \
  --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: storage-lab
spec:
  selector:
    app: database
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: storage-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      initContainers:
        - name: verify-volume-config
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
          args:
            - |
              configured_path="$(cat /config/data-path)"
              expected_path="/var/lib/postgresql/data"
              echo "configured data path: ${configured_path}"
              echo "mounted volume path: ${expected_path}"
              if [ "${configured_path}" != "${expected_path}" ]; then
                echo "ERROR: database data-path does not point to the mounted PVC"
                exit 1
              fi
              chmod 0777 "${expected_path}"
              test -w "${expected_path}"
          volumeMounts:
            - name: database-config
              mountPath: /config
              readOnly: true
            - name: data
              mountPath: /var/lib/postgresql/data
      containers:
        - name: postgres
          image: postgres:16-alpine
          envFrom:
            - secretRef:
                name: database-secret
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          ports:
            - name: postgres
              containerPort: 5432
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
            initialDelaySeconds: 3
            periodSeconds: 3
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: database-config
          configMap:
            name: database-config
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: cnpe-manual
        selector:
          matchLabels:
            storage.cnpe.io/database: postgres
        resources:
          requests:
            storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-app
  namespace: storage-lab
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders-app
  template:
    metadata:
      labels:
        app: orders-app
    spec:
      initContainers:
        - name: wait-for-database
          image: busybox:1.36
          envFrom:
            - configMapRef:
                name: app-config
          command:
            - /bin/sh
            - -c
          args:
            - |
              echo "checking database endpoint ${DB_HOST}:${DB_PORT}"
              if ! nslookup "${DB_HOST}"; then
                echo "ERROR: database hostname cannot be resolved"
                exit 1
              fi
              if ! nc -z -w 3 "${DB_HOST}" "${DB_PORT}"; then
                echo "ERROR: database endpoint is not reachable"
                exit 1
              fi
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 2
            periodSeconds: 3
YAML

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Storage troubleshooting lab ready: $COURSE_DIR"
info "Expected initial state: PVC Pending and application init failure"
kubectl -n "$NAMESPACE" get pods,persistentvolumeclaims
kubectl get persistentvolume "$PV_NAME"
