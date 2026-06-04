#!/usr/bin/env bash
# ============================================================
#  CNPE Storage Lab — Batteria 1 (scenario broken-app)
#  Domande: domande.md | Guida completa: ../storage-test.md
#
#  Usage:
#    chmod +x setup-lab.sh && ./setup-lab.sh
#    ./setup-lab.sh --cleanup
# ============================================================
set -euo pipefail

NS="broken-app"
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
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/troubleshooting-lab}"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
die()     { echo "[ERR] $*"; exit 1; }

[[ "${1:-}" == "--cleanup" ]] && {
  kubectl delete namespace "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete storageclass fast-ssd --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  success "Cleanup broken-app completato"
  exit 0
}

command -v kubectl  >/dev/null || die "kubectl mancante"
command -v minikube >/dev/null || die "minikube mancante"
mkdir -p "$LAB_DIR"

if ! minikube status -p "$MINIKUBE_PROFILE" &>/dev/null; then
  info "Avvio minikube ${MINIKUBE_PROFILE} (${K8S_VERSION})..."
  minikube start -p "$MINIKUBE_PROFILE" \
    --driver="$MINIKUBE_DRIVER" --cpus="$MINIKUBE_CPUS" \
    --memory="${MINIKUBE_MEMORY}mb" --disk-size=40g \
    --kubernetes-version="$K8S_VERSION" \
    --extra-config=kubelet.fail-swap-on=false \
    --extra-config=kubeadm.ignore-preflight-errors=SystemVerification,Swap,NumCPU,Mem,ContainerRuntime \
    --force
fi

export KUBECONFIG="$(minikube kubeconfig --no-env -p "$MINIKUBE_PROFILE" 2>/dev/null || echo "${HOME}/.kube/config")"
minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server 2>/dev/null || true

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Manifest identici a storage-test.md (scenario rotto)
cat >"$LAB_DIR/broken-scenario.yaml" <<'YAML'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: broken-app
data:
  POSTGRES_DB: appdb
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: supersecret
  PGDATA: "/var/lib/postgresql/wrong-path/data"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: broken-app
data:
  DATABASE_HOST: "postgres-svc"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "appdb"
  DATABASE_USER: "appuser"
  DATABASE_PASSWORD: "supersecret"
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: broken-app
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: broken-app
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          envFrom:
            - configMapRef:
                name: postgres-config
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
              subPath: pgdata
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: "fast-ssd"
        resources:
          requests:
            storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: broken-app
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: broken-app
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
      containers:
        - name: webapp
          image: php:8.2-apache
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: webapp-config
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "<?php" > /var/www/html/index.php
              echo "\$host = getenv('DATABASE_HOST');" >> /var/www/html/index.php
              echo "\$port = getenv('DATABASE_PORT');" >> /var/www/html/index.php
              echo "\$db   = getenv('DATABASE_NAME');" >> /var/www/html/index.php
              echo "\$user = getenv('DATABASE_USER');" >> /var/www/html/index.php
              echo "\$pass = getenv('DATABASE_PASSWORD');" >> /var/www/html/index.php
              echo "echo '<h1>WebApp CNPE</h1>';" >> /var/www/html/index.php
              echo "\$conn = @pg_connect(\"host=\$host port=\$port dbname=\$db user=\$user password=\$pass\");" >> /var/www/html/index.php
              echo "if (\$conn) { echo '<p style=\"color:green\">DB OK: connected to ' . \$host . '</p>'; }" >> /var/www/html/index.php
              echo "else { echo '<p style=\"color:red\">DB KO: cannot reach ' . \$host . '</p>'; }" >> /var/www/html/index.php
              apt-get update -qq && apt-get install -y -qq libpq-dev > /dev/null
              docker-php-ext-install pdo_pgsql pgsql > /dev/null 2>&1
              apache2-foreground
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 30
            periodSeconds: 10
YAML

kubectl apply -f "$LAB_DIR/broken-scenario.yaml"
sleep 10
kubectl -n "$NS" get pods,pvc
info "Domande: domande.md | Guida: ../storage-test.md"
success "Lab broken-app pronto (${LAB_DIR})"
