#!/usr/bin/env bash
# ============================================================
#  CNPE Storage Lab — Batteria 2 (scenario storage-lab-2)
#
#  Problemi introdotti:
#   - StorageClass cnpe-ssd assente → PVC api-data Pending
#   - PV statico con capacity/accessMode/storageClass errati
#   - Secret api-credentials: chiave sbagliata vs volume items
#   - ConfigMap nginx-conf: chiave file diversa da subPath
#   - ResourceQuota requests.storage 6Gi: backup+api saturano; metrics-data non creato (D16)
#   - hostPath Directory su path inesistente
#   - StorageClass cnpe-ssd senza allowVolumeExpansion (domanda D18)
#
#  Usage:
#    chmod +x setup-lab-v2.sh && ./setup-lab-v2.sh
#    ./setup-lab-v2.sh --cleanup
# ============================================================
set -euo pipefail

NS="storage-lab-2"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-cnpe}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-10000}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/storage-lab-2}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
section() {
  echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║  $*${NC}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}\n"
}

have_cmd() { command -v "$1" &>/dev/null; }

cleanup_lab() {
  section "Cleanup storage-lab-2"
  kubectl delete namespace "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete storageclass cnpe-ssd cnpe-retain --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  success "Cleanup completato"
  exit 0
}

[[ "${1:-}" == "--cleanup" ]] && cleanup_lab

# ============================================================
section "0. Prerequisites"
# ============================================================
have_cmd kubectl  || die "kubectl non trovato"
have_cmd minikube || die "minikube non trovato"

mkdir -p "$LAB_DIR"

# ============================================================
section "1. Minikube (Kubernetes ${K8S_VERSION})"
# ============================================================
if ! minikube status -p "$MINIKUBE_PROFILE" &>/dev/null; then
  info "Avvio minikube profile ${MINIKUBE_PROFILE}..."
  minikube start -p "$MINIKUBE_PROFILE" \
    --driver="$MINIKUBE_DRIVER" \
    --cpus="$MINIKUBE_CPUS" \
    --memory="${MINIKUBE_MEMORY}mb" \
    --disk-size=40g \
    --kubernetes-version="$K8S_VERSION" \
    --extra-config=kubelet.fail-swap-on=false \
    --extra-config=kubeadm.ignore-preflight-errors=SystemVerification,Swap,NumCPU,Mem,ContainerRuntime \
    --force
else
  info "Minikube profile ${MINIKUBE_PROFILE} già attivo"
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$MINIKUBE_PROFILE" 2>/dev/null || echo "${HOME}/.kube/config")"
export KUBECONFIG

minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server 2>/dev/null || true
kubectl cluster-info >/dev/null || die "Cluster non raggiungibile"
success "Cluster OK — $(kubectl version --short 2>/dev/null | head -1 || kubectl version | head -1)"

# ============================================================
section "2. Namespace e ResourceQuota (troppo stretta)"
# ============================================================
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Pod admission requires ServiceAccount "default" in the namespace.
for _ in $(seq 1 30); do
  kubectl get serviceaccount default -n "$NS" &>/dev/null && break
  kubectl create serviceaccount default -n "$NS" 2>/dev/null || true
  sleep 1
done
kubectl get serviceaccount default -n "$NS" &>/dev/null \
  || die "ServiceAccount default mancante in ${NS} — elimina il namespace e riesegui lo script"

cat >"$LAB_DIR/resourcequota.yaml" <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: storage-lab-2
spec:
  hard:
    # backup-claim 5Gi + api-data 1Gi = 6Gi; metrics-data (1Gi) supera il limite (D16)
    requests.storage: 6Gi
    persistentvolumeclaims: "5"
YAML
kubectl apply -f "$LAB_DIR/resourcequota.yaml"

# ============================================================
section "3. PV statico (non bindabile al PVC backup-claim)"
# ============================================================
cat >"$LAB_DIR/static-pv.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-backup-pv
  labels:
    type: local-backup
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: cnpe-retain
  hostPath:
    path: /tmp/cnpe-static-backup
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-claim
  namespace: storage-lab-2
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: cnpe-retain
  resources:
    requests:
      storage: 5Gi
YAML
kubectl apply -f "$LAB_DIR/static-pv.yaml"

# ============================================================
section "4. Secret e ConfigMap errati"
# ============================================================
cat >"$LAB_DIR/config-secret.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
  namespace: storage-lab-2
type: Opaque
stringData:
  # Il Deployment monta items.key: api-key — nome errato
  apiKey: "super-token-12345"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
  namespace: storage-lab-2
data:
  # subPath nel Pod è nginx.conf — chiave sbagliata
  default.conf: |
    server {
      listen 8080;
      location / { return 200 'ok\n'; }
    }
YAML
kubectl apply -f "$LAB_DIR/config-secret.yaml"

# ============================================================
section "5. PVC dinamico (StorageClass cnpe-ssd assente)"
# ============================================================
cat >"$LAB_DIR/api-pvc.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: api-data
  namespace: storage-lab-2
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: cnpe-ssd
  resources:
    requests:
      storage: 1Gi
YAML
kubectl apply -f "$LAB_DIR/api-pvc.yaml"

# PVC metrics — NON applicato allo setup: 6Gi già usati da backup+api (D16)
cat >"$LAB_DIR/metrics-pvc.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: metrics-data
  namespace: storage-lab-2
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
YAML

# ============================================================
section "6. Workload (Deployment / Pod — NON da modificare in esame)"
# ============================================================
cat >"$LAB_DIR/workloads.yaml" <<'YAML'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-api
  namespace: storage-lab-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: file-api
  template:
    metadata:
      labels:
        app: file-api
    spec:
      containers:
        - name: api
          image: busybox:1.36
          command: ["sh", "-c", "echo data > /data/ok && sleep 3600"]
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: api-data
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backup-agent
  namespace: storage-lab-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backup-agent
  template:
    metadata:
      labels:
        app: backup-agent
    spec:
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "ls -la /backup && sleep 3600"]
          volumeMounts:
            - name: backup
              mountPath: /backup
      volumes:
        - name: backup
          persistentVolumeClaim:
            claimName: backup-claim
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-api
  namespace: storage-lab-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-api
  template:
    metadata:
      labels:
        app: secure-api
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "cat /etc/creds/api-key && sleep 3600"]
          volumeMounts:
            - name: creds
              mountPath: /etc/creds
              readOnly: true
      volumes:
        - name: creds
          secret:
            secretName: api-credentials
            items:
              - key: api-key
                path: api-key
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-worker
  namespace: storage-lab-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-worker
  template:
    metadata:
      labels:
        app: config-worker
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          volumeMounts:
            - name: conf
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: conf
          configMap:
            name: nginx-conf
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics
  namespace: storage-lab-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics
  template:
    metadata:
      labels:
        app: metrics
    spec:
      containers:
        - name: metrics
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          volumeMounts:
            - name: data
              mountPath: /metrics
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: metrics-data
---
apiVersion: v1
kind: Pod
metadata:
  name: node-debug
  namespace: storage-lab-2
spec:
  containers:
    - name: debug
      image: busybox:1.36
      command: ["sleep", "3600"]
      volumeMounts:
        - name: host-logs
          mountPath: /host/logs
  volumes:
    - name: host-logs
      hostPath:
        path: /var/log/cnpe-does-not-exist
        type: Directory
---
apiVersion: v1
kind: Pod
metadata:
  name: shared-cache
  namespace: storage-lab-2
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo cache > /cache/x && sleep 3600"]
      volumeMounts:
        - name: cache
          mountPath: /cache
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 5; cat /cache/x || true; sleep 3600"]
      volumeMounts:
        - name: cache
          mountPath: /cache
  volumes:
    - name: cache
      emptyDir:
        medium: Memory
        sizeLimit: 64Mi
YAML
kubectl apply -f "$LAB_DIR/workloads.yaml"

# D16: metrics-data non deve esistere finché non si alza requests.storage
if kubectl get pvc metrics-data -n "$NS" &>/dev/null; then
  phase="$(kubectl get pvc metrics-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
  kubectl delete pvc metrics-data -n "$NS" --ignore-not-found --wait=false 2>/dev/null || true
  die "metrics-data presente (phase=${phase}) — esegui --cleanup e riesegui lo script"
fi

# ============================================================
section "7. Stato atteso (rotto)"
# ============================================================
info "Attendo 15s per eventi kubelet..."
sleep 15

echo ""
kubectl -n "$NS" get pods,pvc,pv 2>/dev/null || true
echo ""
warn "Problemi attesi:"
echo "  • api-data          → Pending (StorageClass cnpe-ssd mancante)"
echo "  • backup-claim      → Pending (RWX/5Gi vs PV RWO/2Gi)"
echo "  • secure-api-*      → ContainerCreating (Secret key api-key)"
echo "  • config-worker-*   → CrashLoop o mount vuoto (ConfigMap key)"
echo "  • metrics-data      → assente (requests.storage 6Gi già usati); deploy/metrics senza PVC"
echo "  • storage-quota     → used.requests.storage 6Gi / hard 6Gi"
echo "  • node-debug        → ContainerCreating (hostPath Directory)"
echo "  • shared-cache      → Running (emptyDir Memory — domanda teorica)"
echo ""
info "Domande: EXAM/TESTS/killer.sh/storage/questions/domande-02.md"
info "Cleanup:  $0 --cleanup"
success "Lab storage-lab-2 pronto in ${LAB_DIR}"
