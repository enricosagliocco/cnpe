#!/usr/bin/env bash
# ============================================================
# CNPE Lab Setup - Part 3: Q13-Q20
# ============================================================
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="cnpe-user"
GITEA_PASS="cnpe-pass"
GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"

# Use caller's home directory instead of /course to avoid permission issues.
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course}"

ensure_ns() {
  for ns in "$@"; do
    kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  done
}

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
section() { echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

gitea_api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}

GITEA_AUTH_USER="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" 2>/dev/null | jq -r '.login // empty' || true)"
[ -n "${GITEA_AUTH_USER}" ] || GITEA_AUTH_USER="${GITEA_USER}"

gitea_api_status() {
  local method=$1 path=$2 data=${3:-}
  local url="${GITEA_URL}${path}"
  if [[ -n "$data" ]]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      "$url" \
      -d "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      "$url"
  fi
}

ensure_org_repo() {
  local repo=$1 code

  code="$(gitea_api_status GET "/api/v1/repos/${GITEA_ORG}/${repo}")"
  if [[ "$code" == "200" ]]; then
    return 0
  fi

  code="$(gitea_api_status POST "/api/v1/orgs/${GITEA_ORG}/repos" "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}")"
  if [[ "$code" != "201" && "$code" != "200" && "$code" != "409" ]]; then
    warn "Cannot create repo ${GITEA_ORG}/${repo} (HTTP ${code})"
    return 1
  fi

  code="$(gitea_api_status GET "/api/v1/repos/${GITEA_ORG}/${repo}")"
  [[ "$code" == "200" ]]
}

build_gitea_auth_url() {
  local repo_path=$1
  case "${GITEA_URL}" in
    http://*)
      echo "http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#http://}/${repo_path}"
      ;;
    https://*)
      echo "https://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#https://}/${repo_path}"
      ;;
    *)
      echo "${GITEA_URL}/${repo_path}"
      ;;
  esac
}

# ============================================================
ensure_ns ammersee-legacy eyre sargasso baltic flux-system danau saltlake-app havel-west havel-east caribbean

section "13. Q13 – Pod Security Standards"
# ============================================================
mkdir -p $COURSE_DIR/13

cat > $COURSE_DIR/13/daemonset.yaml << 'YAML'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logging-agent
  namespace: ammersee-legacy
spec:
  selector:
    matchLabels:
      app: logging-agent
  template:
    metadata:
      labels:
        app: logging-agent
    spec:
      serviceAccountName: default
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sleep", "infinity"]
          securityContext:
            runAsUser: 1000
            allowPrivilegeEscalation: true
YAML

cat > $COURSE_DIR/13/statefulset.yaml << 'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-cache
  namespace: ammersee-legacy
spec:
  serviceName: web-cache
  replicas: 2
  selector:
    matchLabels:
      app: web-cache
  template:
    metadata:
      labels:
        app: web-cache
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: cache
          image: nginx:1-alpine
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
YAML

kubectl apply -f $COURSE_DIR/13/daemonset.yaml 2>/dev/null || true
kubectl apply -f $COURSE_DIR/13/statefulset.yaml 2>/dev/null || true

success "Q13 ready"

# ============================================================
section "14. Q14 – Jaeger"
# ============================================================
mkdir -p $COURSE_DIR/14

# Install Jaeger via operator
ensure_ns observability eyre

# Use the all-in-one Jaeger image (simplest setup)
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: eyre
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
        - name: jaeger
          image: jaegertracing/all-in-one:latest
          env:
            - name: COLLECTOR_ZIPKIN_HOST_PORT
              value: ":9411"
          ports:
            - containerPort: 16686
              name: ui
            - containerPort: 14268
              name: collector
            - containerPort: 6831
              protocol: UDP
              name: agent
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
  namespace: eyre
spec:
  type: NodePort
  selector:
    app: jaeger
  ports:
    - name: ui
      port: 16686
      targetPort: 16686
      nodePort: 30014
    - name: collector
      port: 14268
      targetPort: 14268
YAML

# Trace-generating apps in eyre
for svc_name in imageai speechai textai; do
  AI_MODEL="cheap_v1.2"
  ACCESS_PUBLIC="false"
  [ "$svc_name" = "imageai" ] && AI_MODEL="fast_v1.2"
  [ "$svc_name" = "textai" ]  && ACCESS_PUBLIC="true"

  kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${svc_name}
  namespace: eyre
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${svc_name}
  template:
    metadata:
      labels:
        app: ${svc_name}
    spec:
      containers:
        - name: app
          image: curlimages/curl:latest
          command: ["/bin/sh","-c"]
          args:
            - |
              while true; do
                curl -s -X POST http://jaeger.eyre:14268/api/traces \
                  -H 'Content-Type: application/x-thrift' 2>/dev/null || true;
                sleep 5;
              done
          env:
            - name: SERVICE_NAME
              value: ${svc_name}
            - name: AI_MODEL
              value: "${AI_MODEL}"
            - name: ACCESS_PUBLIC
              value: "${ACCESS_PUBLIC}"
            - name: JAEGER_ENDPOINT
              value: "http://jaeger.eyre:14268/api/traces"
YAML
done

# Trace injection script (sends real traces to Jaeger)
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: trace-sender
  namespace: eyre
data:
  send.sh: |
    #!/bin/sh
    # Sends Thrift-encoded spans to Jaeger HTTP collector
    JAEGER="http://jaeger.eyre:14268/api/traces"
    SERVICE=${SERVICE_NAME:-unknown}
    AI_MODEL=${AI_MODEL:-unknown}
    ACCESS_PUBLIC=${ACCESS_PUBLIC:-false}
    while true; do
      TRACE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16)
      SPAN_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8)
      sleep 5
    done
YAML

success "Q14 ready"

# ============================================================
section "15. Q15 – VPA"
# ============================================================
# Install VPA
VPA_VERSION="1.0.0"
git clone https://github.com/kubernetes/autoscaler.git /tmp/autoscaler-vpa \
  --depth=1 --branch="vertical-pod-autoscaler/${VPA_VERSION}" 2>/dev/null || \
git clone https://github.com/kubernetes/autoscaler.git /tmp/autoscaler-vpa \
  --depth=1 2>/dev/null || true

if [ -d /tmp/autoscaler-vpa/vertical-pod-autoscaler/deploy ]; then
  /tmp/autoscaler-vpa/vertical-pod-autoscaler/hack/vpa-up.sh 2>/dev/null || true
else
  # Fallback: install VPA CRDs manually
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml 2>/dev/null || \
  kubectl apply -f - <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: verticalpodautoscalers.autoscaling.k8s.io
spec:
  group: autoscaling.k8s.io
  names:
    kind: VerticalPodAutoscaler
    plural: verticalpodautoscalers
    shortNames:
      - vpa
    singular: verticalpodautoscaler
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML
fi

mkdir -p $COURSE_DIR/15
ensure_ns sargasso

cat > $COURSE_DIR/15/etcd.yaml << 'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: etcd
  namespace: sargasso
spec:
  serviceName: etcd
  replicas: 1
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
        - name: etcd
          image: registry.k8s.io/etcd:3.5.9-0
          command:
            - etcd
            - --data-dir=/var/lib/etcd
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
          volumeMounts:
            - name: data
              mountPath: /var/lib/etcd
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 100Mi
YAML

kubectl apply -f $COURSE_DIR/15/etcd.yaml 2>/dev/null || true

success "Q15 ready"

# ============================================================
section "16. Q16 – Argo Rollouts"
# ============================================================
# Install Argo Rollouts
kubectl create ns argo-rollouts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Dashboard on NodePort 30160
kubectl -n argo-rollouts patch svc argo-rollouts-dashboard \
  -p '{"spec":{"type":"NodePort","ports":[{"port":3100,"targetPort":3100,"nodePort":30160}]}}' \
  2>/dev/null || true

# kubectl argo plugin
tmp_rollouts_cli="/tmp/kubectl-argo-rollouts"
curl -sSL https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64 \
  -o "${tmp_rollouts_cli}" 2>/dev/null && \
  chmod +x "${tmp_rollouts_cli}" && \
  sudo mv "${tmp_rollouts_cli}" /usr/local/bin/kubectl-argo-rollouts || true

mkdir -p $COURSE_DIR/16
ensure_ns baltic

# Services for canary
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: baltic
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30161
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-canary
  namespace: baltic
spec:
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80
YAML

# Argo Rollout – already paused mid-canary at 50%
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: webapp
  namespace: baltic
spec:
  replicas: 4
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
          image: nginx:1-alpine
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "webapp version ${VERSION}" > /usr/share/nginx/html/index.html;
              nginx -g 'daemon off;'
          env:
            - name: VERSION
              value: "1.18.3"
          ports:
            - containerPort: 80
  strategy:
    canary:
      canaryService: webapp-canary
      steps:
        - setWeight: 25
        - setWeight: 50
        - pause: {}
        - setWeight: 75
        - setWeight: 100
YAML

# Patch to simulate it being paused at step 2 (50%)
sleep 5
kubectl -n baltic patch rollout webapp --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"webapp","env":[{"name":"VERSION","value":"1.18.3"}]}]}}}}' \
  2>/dev/null || true

# AnalysisTemplate placeholder
cat > $COURSE_DIR/16/analysis_template.yaml << 'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: http-check
  namespace: baltic
spec:
  metrics:
    - name: webcheck
      provider:
        web:
          url: http://TODO
      successCondition: asInt(result.status) >= 200 && asInt(result.status) < 300
      interval: 10s
      count: 3
YAML

success "Q16 ready"

# ============================================================
section "17. Q17 – FluxCD"
# ============================================================
# Install Flux
flux install 2>/dev/null || \
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

mkdir -p $COURSE_DIR/17/havel-west
mkdir -p $COURSE_DIR/17/havel-east

# havel-west manifests
cat > $COURSE_DIR/17/havel-west/deployment.yaml << 'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logger
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command: ["/bin/sh", "-c", "while true; do echo log; sleep 5; done"]
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
YAML

cat > $COURSE_DIR/17/havel-west/configmap.yaml << 'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: logger-config
data:
  log-format: json
  log-level: info
  retention-days: "30"
YAML

cat > $COURSE_DIR/17/havel-west/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - configmap.yaml
YAML

# havel-east manifests
cat > $COURSE_DIR/17/havel-east/statefulset.yaml << 'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cache
spec:
  serviceName: cache
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: cache
          image: redis:7-alpine
          resources:
            requests:
              cpu: 10m
              memory: 20Mi
YAML

cat > $COURSE_DIR/17/havel-east/secret-api.yaml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
type: Opaque
stringData:
  api-key: "placeholder-api-key"
YAML

cat > $COURSE_DIR/17/havel-east/secret-db.yaml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  password: "placeholder-db-pass"
YAML

cat > $COURSE_DIR/17/havel-east/kustomization.yaml << 'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - statefulset.yaml
  - secret-api.yaml
  - secret-db.yaml
YAML

# Push both repos to Gitea
for repo in havel-west havel-east; do
  ensure_org_repo "${repo}" || { warn "Skipping push for ${repo}: repo not accessible"; continue; }
  (
    cd $COURSE_DIR/17/$repo
    git init -b main 2>/dev/null || git init
    git checkout -b main 2>/dev/null || true
    git add -A
    git commit -m "init of project" --allow-empty 2>/dev/null || true
    REMOTE_URL="$(build_gitea_auth_url "${GITEA_ORG}/${repo}.git")"
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REMOTE_URL"
    git push -u origin main --force
  )
done

HW_URL="${GITEA_URL}/${GITEA_ORG}/havel-west.git"
HE_URL="${GITEA_URL}/${GITEA_ORG}/havel-east.git"

# Flux GitRepository + Kustomization for havel-west
kubectl apply -f - <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: havel-west
  namespace: flux-system
spec:
  interval: 30s
  url: ${HW_URL}
  ref:
    branch: main
YAML

kubectl apply -f - <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: havel-west
  namespace: flux-system
spec:
  interval: 30s
  sourceRef:
    kind: GitRepository
    name: havel-west
  path: ./
  prune: true
  targetNamespace: havel-west
  suspend: false
YAML

# Wait for initial sync then introduce drift and suspend
sleep 20
kubectl -n havel-west scale deploy logger --replicas=2 2>/dev/null || true
kubectl -n havel-west patch cm logger-config \
  --type merge -p '{"data":{"log-level":"debug"}}' 2>/dev/null || true

# Now suspend the kustomization (candidate must resume it)
kubectl -n flux-system patch kustomization havel-west \
  --type merge -p '{"spec":{"suspend":true}}'

success "Q17 ready"

# ============================================================
section "18. Q18 – Kyverno"
# ============================================================
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --wait --timeout=300s

# Ensure kyverno CRDs include NamespacedMutatingPolicy (v1)
# This is available from Kyverno >= 1.12
success "Q18 ready (kyverno installed, caribbean namespace ready)"

# ============================================================
section "19. Q19 – Crossplane"
# ============================================================
helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || true
helm repo update
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace \
  --wait --timeout=300s

# Wait for crossplane to be ready
kubectl wait pod -n crossplane-system \
  -l app=crossplane --for=condition=Ready --timeout=180s

# Install function-patch-and-transform
kubectl apply -f - <<'YAML'
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.6.0
YAML

sleep 30

mkdir -p $COURSE_DIR/19

# XRD
cat > $COURSE_DIR/19/xrd.yaml << 'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: redis.cache.killer.sh
spec:
  group: cache.killer.sh
  names:
    kind: Redis
    plural: redis
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                size:
                  type: string
                  enum: ["small", "medium", "large"]
                  default: "small"
YAML

# Composition (missing Service – candidate must add it)
cat > $COURSE_DIR/19/composition.yaml << 'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: redis-composition
spec:
  compositeTypeRef:
    apiVersion: cache.killer.sh/v1alpha1
    kind: Redis
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: statefulset
            base:
              apiVersion: apps/v1
              kind: StatefulSet
              metadata:
                name: redis
              spec:
                serviceName: redis
                replicas: 1
                selector:
                  matchLabels:
                    app: redis
                template:
                  metadata:
                    labels:
                      app: redis
                  spec:
                    containers:
                      - name: redis
                        image: redis:7-alpine
                        ports:
                          - containerPort: 6379
                        volumeMounts:
                          - name: data
                            mountPath: /data
                    volumes:
                      - name: data
                        emptyDir: {}
            patches:
              - fromFieldPath: metadata.namespace
                toFieldPath: metadata.namespace
            readinessChecks:
              - type: None
          - name: configmap
            base:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: redis-config
              data:
                redis.conf: |
                  maxmemory 128mb
                  maxmemory-policy allkeys-lru
            patches:
              - fromFieldPath: metadata.namespace
                toFieldPath: metadata.namespace
            readinessChecks:
              - type: None
YAML

kubectl apply -f $COURSE_DIR/19/xrd.yaml
kubectl apply -f $COURSE_DIR/19/composition.yaml

kubectl create ns danau --dry-run=client -o yaml | kubectl apply -f - >/dev/null

success "Q19 ready"

# ============================================================
section "20. Q20 – Linkerd + Gateway API"
# ============================================================
# Install Linkerd CLI
if ! command -v linkerd &>/dev/null; then
  curl -sSL https://run.linkerd.io/install | sh
  export PATH=$PATH:$HOME/.linkerd2/bin
fi

# Install Gateway API CRDs
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml \
  2>/dev/null || \
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml \
  2>/dev/null || true

# Check prerequisites
linkerd check --pre 2>/dev/null || warn "Linkerd pre-check failed – continuing anyway"

# Install Linkerd CRDs and control plane after Gateway API is present.
linkerd install --crds | kubectl apply -f - 2>/dev/null || true
linkerd install | kubectl apply -f - 2>/dev/null || true

# Wait for control plane
linkerd check 2>/dev/null || warn "Linkerd check failed – mesh may still be starting"

# Annotate saltlake-app for Linkerd injection
kubectl annotate ns saltlake-app \
  linkerd.io/inject=enabled --overwrite 2>/dev/null || true

# ServiceAccounts
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: saltlake-app
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: saltlake-app
YAML

# Backend app script
# Deploy frontend
kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: saltlake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      serviceAccountName: frontend-sa
      containers:
        - name: frontend
          image: python:3-alpine
          command:
            - /bin/sh
            - -c
          args:
            - |
              cat > /tmp/front.py <<'PY'
              import http.server, socketserver
              PORT = 80
              class H(http.server.BaseHTTPRequestHandler):
                  def do_GET(self):
                      import urllib.request
                      try:
                          r = urllib.request.urlopen("http://backend.saltlake-app/")
                          data = r.read()
                      except Exception as e:
                          data = str(e).encode()
                      self.send_response(200)
                      self.end_headers()
                      self.wfile.write(data)
                  def log_message(self, *a):
                      pass
              with socketserver.TCPServer(("", PORT), H) as s:
                  s.serve_forever()
              PY
              python3 /tmp/front.py
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: saltlake-app
spec:
  selector:
    app: frontend
  ports:
    - port: 80
YAML

# Deploy backend-v1
kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v1
  namespace: saltlake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend-sa
      containers:
        - name: backend
          image: python:3-alpine
          command:
            - /bin/sh
            - -c
          args:
            - |
              cat > /tmp/app.py <<'PY'
              import http.server, json, os, socketserver
              PORT = 80
              class H(http.server.BaseHTTPRequestHandler):
                  def do_GET(self):
                      self.send_response(200)
                      self.end_headers()
                      self.wfile.write(json.dumps({"name": "backend", "version": os.environ.get("VERSION", "v1")}).encode())
                  def log_message(self, *a):
                      pass
              with socketserver.TCPServer(("", PORT), H) as s:
                  s.serve_forever()
              PY
              python3 /tmp/app.py
          env:
            - name: VERSION
              value: v1
          ports:
            - containerPort: 80
YAML

# Deploy backend-v2
kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v2
  namespace: saltlake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v2
  template:
    metadata:
      labels:
        app: backend
        version: v2
    spec:
      serviceAccountName: backend-sa
      containers:
        - name: backend
          image: python:3-alpine
          command:
            - /bin/sh
            - -c
          args:
            - |
              cat > /tmp/app.py <<'PY'
              import http.server, json, os, socketserver
              PORT = 80
              class H(http.server.BaseHTTPRequestHandler):
                  def do_GET(self):
                      self.send_response(200)
                      self.end_headers()
                      self.wfile.write(json.dumps({"name": "backend", "version": os.environ.get("VERSION", "v1")}).encode())
                  def log_message(self, *a):
                      pass
              with socketserver.TCPServer(("", PORT), H) as s:
                  s.serve_forever()
              PY
              python3 /tmp/app.py
          env:
            - name: VERSION
              value: v2
          ports:
            - containerPort: 80
YAML

# Services
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: saltlake-app
spec:
  selector:
    app: backend
  ports:
    - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-v1
  namespace: saltlake-app
spec:
  selector:
    app: backend
    version: v1
  ports:
    - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-v2
  namespace: saltlake-app
spec:
  selector:
    app: backend
    version: v2
  ports:
    - port: 80
YAML

# AuthorizationPolicy with WRONG serviceaccount name (candidate must fix it)
kubectl apply -f - <<'YAML'
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: saltlake-app
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: backend
  requiredAuthenticationRefs:
    - kind: ServiceAccount
      name: frontend
      namespace: saltlake-app
YAML

success "Q20 ready"

# ============================================================
section "Final summary"
# ============================================================
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "MINIKUBE_IP")

echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  CNPE Lab - Service URLs${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "  Q2  Prometheus       http://${MINIKUBE_IP}:30020"
echo -e "  Q3  Argo CD          http://${MINIKUBE_IP}:30030  (admin/admin)"
echo -e "  Q4  app1             http://${MINIKUBE_IP}:30041"
echo -e "  Q4  app2             http://${MINIKUBE_IP}:30042"
echo -e "  Q7  OpenCost         http://${MINIKUBE_IP}:30070"
echo -e "  Q8  Grafana          http://${MINIKUBE_IP}:30080  (admin/admin)"
echo -e "  Q11 Argo Workflows   http://${MINIKUBE_IP}:30110"
echo -e "  Q12 Tekton           http://${MINIKUBE_IP}:30120"
echo -e "  Q14 Jaeger           http://${MINIKUBE_IP}:30014"
echo -e "  Q16 Argo Rollouts    http://${MINIKUBE_IP}:30160"
echo -e "  Q16 webapp           http://${MINIKUBE_IP}:30161"
echo -e "  Gitea                ${GITEA_URL}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
