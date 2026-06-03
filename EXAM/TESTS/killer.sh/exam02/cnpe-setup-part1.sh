#!/usr/bin/env bash
# ============================================================
# CNPE Exam02 - Part 1 (Q1-Q7)
# Focus: GitOps and Continuous Delivery
# ============================================================
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="cnpe-user"
GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course/exam02}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required: $1"; }

gitea_api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" "$@"
}

gitea_status() {
  local method=$1 path=$2 data=${3:-}
  local url="${GITEA_URL}${path}"
  if [[ -n "$data" ]]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      "$url" -d "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" "$url"
  fi
}

GITEA_AUTH_USER="$(gitea_api -X GET "${GITEA_URL}/api/v1/user" 2>/dev/null | jq -r '.login // empty' || true)"
[ -n "${GITEA_AUTH_USER}" ] || GITEA_AUTH_USER="${GITEA_USER}"

build_auth_url() {
  local repo_path=$1
  case "${GITEA_URL}" in
    http://*) echo "http://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#http://}/${repo_path}" ;;
    https://*) echo "https://${GITEA_AUTH_USER}:${GITEA_TOKEN}@${GITEA_URL#https://}/${repo_path}" ;;
    *) echo "${GITEA_URL}/${repo_path}" ;;
  esac
}

ensure_org_repo() {
  local repo=$1 code
  code="$(gitea_status GET "/api/v1/repos/${GITEA_ORG}/${repo}")"
  if [[ "$code" == "200" ]]; then
    return 0
  fi
  code="$(gitea_status POST "/api/v1/orgs/${GITEA_ORG}/repos" "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}")"
  [[ "$code" == "201" || "$code" == "200" || "$code" == "409" ]]
}

push_repo() {
  local repo=$1 dir=$2
  ensure_org_repo "$repo" || { warn "Repo ${repo} not accessible"; return 1; }
  (
    cd "$dir"
    git init -b main 2>/dev/null || git init
    git checkout -B main
    git add -A
    git commit -m "exam02 seed ${repo}" --allow-empty >/dev/null 2>&1 || true
    git remote remove origin >/dev/null 2>&1 || true
    git remote add origin "$(build_auth_url "${GITEA_ORG}/${repo}.git")"
    git push -u origin main --force
  )
}

section "0. Prerequisites"
require_cmd kubectl
require_cmd git
require_cmd curl
require_cmd jq
require_cmd helm

mkdir -p "${COURSE_DIR}"/{1,2,3,4,5,6,7}

section "1. Q1 - Argo CD Drift Recovery"
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if ! kubectl -n argocd get deploy argocd-server >/dev/null 2>&1; then
  kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
fi
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":31030,"protocol":"TCP","name":"https"}]}}' >/dev/null 2>&1 || true

cat > "${COURSE_DIR}/1/README.md" <<'EOF'
Q1 focus:
- Fix OutOfSync app and auto-sync policy
- Restore app health in namespace gitops-apps
EOF

section "2. Q2 - Flux Resume and Reconcile"
flux install >/dev/null 2>&1 || kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1 || true
kubectl create ns gitops-apps --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/2/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
EOF
cat > "${COURSE_DIR}/2/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flux-workload
  namespace: gitops-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flux-workload
  template:
    metadata:
      labels:
        app: flux-workload
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
EOF

section "3. Q3 - Argo CD Multi-Branch"
mkdir -p "${COURSE_DIR}/3/web-client/manifests"
cat > "${COURSE_DIR}/3/web-client/manifests/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
  namespace: gitops-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-client
  template:
    metadata:
      labels:
        app: web-client
        version: v1
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
EOF
cat > "${COURSE_DIR}/3/web-client/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - manifests/deploy.yaml
EOF

section "4. Q4 - Tekton Pipeline Repair"
kubectl create ns builder2 --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/4/pipeline.yaml" <<'EOF'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: app-ci
  namespace: builder2
spec:
  params:
    - name: app
      type: string
  tasks:
    - name: lint
      taskSpec:
        steps:
          - name: lint
            image: bash:5.2
            script: |
              #!/usr/bin/env bash
              echo lint $(params.app)
EOF

section "5. Q5 - Argo Workflows Failure Handling"
kubectl create ns argo --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/5/workflowtemplate.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: retake-greeter
  namespace: argo
spec:
  entrypoint: main
  templates:
    - name: main
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo hello-retake"]
EOF

section "6. Q6 - Progressive Delivery"
cat > "${COURSE_DIR}/6/canary.yaml" <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: app2
  namespace: gitops-apps
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app2
  service:
    port: 80
  analysis:
    interval: 10s
    iterations: 1
    webhooks: []
EOF

section "7. Q7 - Git Push and Controller Sync"
for repo in retake-argocd retake-flux retake-pipelines; do
  mkdir -p "${COURSE_DIR}/7/${repo}"
  cat > "${COURSE_DIR}/7/${repo}/README.md" <<EOF
Repository ${repo} for exam02 retake drills.
EOF
  push_repo "$repo" "${COURSE_DIR}/7/${repo}" || true
done

success "Exam02 Part1 ready at ${COURSE_DIR}"
