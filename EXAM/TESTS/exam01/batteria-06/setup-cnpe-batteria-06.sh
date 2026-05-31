#!/usr/bin/env bash
set -euo pipefail

# Generic CNPE battery setup bootstrap
PROFILE="cnpe-b06"
K8S_VERSION="v1.35.0"
BATTERY="06"
FOCUS="StatefulSet, CSI Snapshots, Velero, PV policies"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

for cmd in minikube kubectl helm git curl jq docker; do
  command -v "$cmd" >/dev/null 2>&1 || err "missing command: $cmd"
done

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "using fallback course root: $COURSE_ROOT"
fi

info "Battery ${BATTERY} focus: ${FOCUS}"

info "Resetting Minikube profile $PROFILE (delete + recreate)"
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=16384 \
  --disk-size=20g \
  --addons=ingress,metrics-server

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s

# Common namespaces
for ns in monitor builder argocd checkout platform-ops finance market team-a team-b team-c ops-lab; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

# Lightweight baseline workloads
kubectl -n market apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 1
  selector:
    matchLabels: {app: demo-app}
  template:
    metadata:
      labels: {app: demo-app}
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML

# Course folders
for i in $(seq 1 20); do
  mkdir -p "$COURSE_ROOT/$i"
done

# Battery-specific hint files
cat > "$COURSE_ROOT/README-battery-${BATTERY}.txt" <<TXT
CNPE Battery ${BATTERY}
Focus: ${FOCUS}
Course root: ${COURSE_ROOT}
TXT

echo "Setup completed for battery ${BATTERY} (${FOCUS})"
echo "Course root: ${COURSE_ROOT}"

echo ""
echo "=== BEGIN_EXERCISE_ENDPOINT_SUMMARY ==="
echo "Endpoint e credenziali per esercizio (Batteria 06)"
for q in "Q1" "Q2" "Q3" "Q4" "Q5" "Q6" "Q7" "Q8" "Q9" "Q10" "Q11" "Q12" "Q13" "Q14" "Q15" "Q16" "Q17" "Q18" "Q19" "Q20"; do
  echo "- $q | Endpoint: nessun endpoint pre-esposto nello setup base | Credenziali: n/a"
done
echo "Nota: usa i file domande/risposte della batteria per endpoint specifici richiesti dal singolo task."
echo "=== END_EXERCISE_ENDPOINT_SUMMARY ==="

echo ""
echo ""
echo "=== BEGIN_SERVICE_PORT_FORWARD ==="
echo "Port-forward servizi necessari su 0.0.0.0"

PF_DIR="/tmp/cnpe/port-forward"
mkdir -p "$PF_DIR"
forward_count=0

start_pf() {
  local ns="$1"
  local svc="$2"
  local local_port="$3"
  local remote_port="$4"

  kubectl -n "$ns" get svc "$svc" >/dev/null 2>&1 || return 0

  if pgrep -f "kubectl -n $ns port-forward svc/$svc $local_port:$remote_port --address=0.0.0.0" >/dev/null 2>&1; then
    return 0
  fi

  local log_file="$PF_DIR/${ns}__${svc}__${local_port}.log"
  kubectl -n "$ns" port-forward "svc/$svc" "$local_port:$remote_port" --address=0.0.0.0 >"$log_file" 2>&1 &
  sleep 0.3

  if pgrep -f "kubectl -n $ns port-forward svc/$svc $local_port:$remote_port --address=0.0.0.0" >/dev/null 2>&1; then
    forward_count=$((forward_count + 1))
  fi
}

# Batteria 01 endpoints
start_pf prometheus prometheus-server 30020 80
start_pf argocd argocd-server 30030 80
start_pf malawi app1-expose 30041 80
start_pf malawi app2-expose 30042 80
start_pf opencost opencost 30070 9003
start_pf opencost prometheus-opencost-server 30077 80
start_pf grafana grafana 30080 80
start_pf argo-workflows argo-server 30110 2746
start_pf tekton-dashboard tekton-dashboard 30120 9097
start_pf argo-rollouts argo-rollouts-dashboard 30160 3100
start_pf baltic webapp-stable 30161 80
start_pf eyre jaeger-query 30014 16686

# Batteria 02 endpoints
start_pf argocd argocd-server 32030 80
start_pf monitor grafana 32080 80
start_pf retail web-stable 32161 80

echo "Port-forward attivi creati: $forward_count"
echo "Log port-forward: $PF_DIR"
echo "=== END_SERVICE_PORT_FORWARD ==="
