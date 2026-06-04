#!/usr/bin/env bash
# ============================================================
#  CNPE Quota / NetworkPolicy Lab — scenario policy-lab
#  Basato su: ../quota-network-policy-test.md (versione difficile)
#
#  Problemi introdotti (NON modificare Deployment/Service in esame):
#   - LimitRange: max container troppo basso + maxLimitRequestRatio CPU
#   - ResourceQuota: requests.cpu/memory e limits.cpu insufficienti
#   - default-deny-all + api-ingress (label/porta errati)
#   - web-egress (label API errata, DNS assente, namespaceSelector DNS errato)
#   - Namespace senza label richieste da una policy ausiliaria
#
#  Usage:
#    chmod +x setup-lab.sh && ./setup-lab.sh
#    ./setup-lab.sh --cleanup
# ============================================================
set -euo pipefail

NS="policy-lab"
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
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/quota-network-lab}"

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
  section "Cleanup policy-lab"
  kubectl delete namespace "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  success "Cleanup completato"
  exit 0
}

[[ "${1:-}" == "--cleanup" ]] && cleanup_lab

section "0. Prerequisites"
have_cmd kubectl  || die "kubectl non trovato"
have_cmd minikube || die "minikube non trovato"
mkdir -p "$LAB_DIR"

section "1. Minikube (Kubernetes ${K8S_VERSION})"
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

section "2. Namespace (senza label environment)"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

for _ in $(seq 1 30); do
  kubectl get serviceaccount default -n "$NS" &>/dev/null && break
  kubectl create serviceaccount default -n "$NS" 2>/dev/null || true
  sleep 1
done
kubectl get serviceaccount default -n "$NS" &>/dev/null \
  || die "ServiceAccount default mancante in ${NS}"

section "3. Scenario rotto (quota, limiti, policy, workload)"
cat >"$LAB_DIR/broken-quota-network.yaml" <<'YAML'
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: policy-lab
spec:
  hard:
    pods: "10"
    # 2× Pod con requests 100m → servono almeno 200m
    requests.cpu: "150m"
    # 2× Pod con requests 128Mi → servono almeno 256Mi
    requests.memory: "200Mi"
    # 2× limit 200m CPU → servono almeno 400m
    limits.cpu: "300m"
    limits.memory: "1Gi"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: policy-lab
spec:
  limits:
    - type: Container
      max:
        cpu: "50m"
        memory: "64Mi"
      min:
        cpu: "10m"
        memory: "16Mi"
      # Deployment: request 100m, limit 200m → rapporto 2:1 vietato (max 1:1)
      maxLimitRequestRatio:
        cpu: "1"
        memory: "1"
    - type: Pod
      max:
        cpu: "120m"
        memory: "200Mi"

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: policy-lab
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        # Container API ascolta 8080, non 80
        - protocol: TCP
          port: 80

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api-backend
      ports:
        - protocol: TCP
          port: 8080

---
# Policy aggiuntiva: richiede label sul Namespace (assente allo setup)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: require-prod-namespace
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              environment: production
        - podSelector:
            matchLabels:
              app: web
      ports:
        - protocol: TCP
          port: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: policy-lab
spec:
  selector:
    app: api
  ports:
    - port: 8080
      targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: policy-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          command: ["/bin/sh", "-c"]
          args:
            - |
              cat > /etc/nginx/conf.d/default.conf <<'EOF'
              server {
                listen 8080;
                location / {
                  default_type text/plain;
                  return 200 "API OK\n";
                }
              }
              EOF
              nginx -g 'daemon off;'

---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: policy-lab
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: policy-lab
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
          image: curlimages/curl:8.11.1
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          command: ["/bin/sh", "-c"]
          args:
            - |
              apk add --no-cache socat > /dev/null 2>&1 || true
              while true; do
                RESP=$(curl -sf --max-time 3 http://api.policy-lab.svc.cluster.local:8080/ 2>&1 || echo "CURL_FAIL")
                BODY="Web CNPE — API response: ${RESP}"
                printf 'HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n%s' "$BODY" | socat -T 1 TCP-LISTEN:8080,reuseaddr,fork
              done
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - curl -sf --max-time 2 http://api.policy-lab.svc.cluster.local:8080/ | grep -q "API OK"
            initialDelaySeconds: 15
            periodSeconds: 10
YAML

kubectl apply -f "$LAB_DIR/broken-quota-network.yaml"

section "4. Stato atteso (rotto)"
info "Attendo 20s per admission e CNI..."
sleep 20

echo ""
kubectl -n "$NS" get pods,resourcequota,limitrange,networkpolicy 2>/dev/null || true
echo ""
warn "Problemi attesi (risolvi solo Quota, LimitRange, NetworkPolicy, label Namespace):"
echo "  • Pod api/web       → Pending / Forbidden (LimitRange + ResourceQuota)"
echo "  • Pod web           → Running ma Not Ready (NetworkPolicy + DNS)"
echo "  • api-ingress       → label role=frontend e porta 80 errate"
echo "  • web-egress        → app=api-backend, senza DNS kube-system"
echo "  • require-prod-namespace → richiede label environment=production sul NS"
echo ""
info "Domande: EXAM/TESTS/killer.sh/quota-network/questions/domande.md"
info "Risposte: EXAM/TESTS/killer.sh/quota-network/questions/risposte.md"
info "Guida:    EXAM/TESTS/killer.sh/quota-network/quota-network-policy-test.md"
info "Cleanup:  $0 --cleanup"
success "Lab policy-lab pronto in ${LAB_DIR}"
