#!/usr/bin/env bash
set -euo pipefail

PROFILE="cnpe-fluxcd"
K8S_VERSION="v1.35.0"

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }

GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_API="${GITEA_URL%/}/api/v1"
GITEA_OWNER="organization"

gitea_available() {
  curl -fsS --connect-timeout 3 --max-time 5 -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" >/dev/null 2>&1
}

seed_git_repo_to_gitea() {
  local repo_path="$1"
  local repo_name="$2"
  local commit_message="$3"
  local status post_status push_base push_url

  git -C "$repo_path" init -b main >/dev/null 2>&1
  git -C "$repo_path" config user.name "CNPE Setup"
  git -C "$repo_path" config user.email "cnpe-setup@example.local"
  git -C "$repo_path" add .
  git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true

  if ! gitea_available; then
    warn "Gitea non raggiungibile, salto il push per ${repo_name}"
    return 0
  fi

  if [[ -z "$GITEA_OWNER" ]]; then
    if ! GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"; then
      warn "Impossibile risolvere l'owner Gitea, salto il push per ${repo_name}"
      return 0
    fi
  fi
  if [[ -z "$GITEA_OWNER" ]]; then
    warn "Unable to resolve Gitea owner, skipping push for ${repo_name}"
    return 0
  fi

  status="$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/repos/${GITEA_OWNER}/${repo_name}" || true)"
  if [[ "$status" != "200" ]]; then
    post_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" -d "{\"name\":\"${repo_name}\",\"private\":false,\"auto_init\":false}" "${GITEA_API}/orgs/${GITEA_OWNER}/repos" || true)"
    if [[ "$post_status" != "201" && "$post_status" != "409" ]]; then
      warn "Gitea repo create failed for ${repo_name} (HTTP ${post_status})"
      return 0
    fi
  fi

  push_base="${GITEA_URL%/}"
  push_url="${push_base/\/\//\/\/${GITEA_OWNER}:${GITEA_TOKEN}@}/${GITEA_OWNER}/${repo_name}.git"
  git -C "$repo_path" remote remove origin >/dev/null 2>&1 || true
  git -C "$repo_path" remote add origin "$push_url" >/dev/null 2>&1 || true
  git -C "$repo_path" push -u origin main --force >/dev/null 2>&1 || warn "Push to Gitea failed for ${repo_name}"
}

for cmd in minikube kubectl git curl docker; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERR] missing command: $cmd"; exit 1; }
done

if mkdir -p /course >/dev/null 2>&1; then
  COURSE_ROOT="/course"
else
  COURSE_ROOT="$HOME/course"
  mkdir -p "$COURSE_ROOT"
  warn "Cannot write /course, using ${COURSE_ROOT}"
fi

for i in $(seq 1 12); do
  mkdir -p "$COURSE_ROOT/$i"
done

echo "[INFO] Removing any pre-existing minikube clusters/profiles"
minikube delete --all >/dev/null 2>&1 || true
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true

info "Starting minikube profile ${PROFILE}"
minikube start \
  --profile="$PROFILE" \
  --kubernetes-version="$K8S_VERSION" \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --addons=ingress,metrics-server

kubectl config use-context "$PROFILE" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace flux-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Installing Flux controllers"
if ! kubectl create -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml >/dev/null 2>&1; then
  warn "Flux install manifest returned non-zero (continuing)"
fi
kubectl -n flux-system rollout status deploy/source-controller --timeout=180s >/dev/null || warn "source-controller not ready yet"
kubectl -n flux-system rollout status deploy/kustomize-controller --timeout=180s >/dev/null || warn "kustomize-controller not ready yet"

mkdir -p "$COURSE_ROOT/2/repo-fluxcd-app/apps/web/base"
cat > "$COURSE_ROOT/2/repo-fluxcd-app/apps/web/base/deploy.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: flux-lab
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
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
YAML

cat > "$COURSE_ROOT/2/repo-fluxcd-app/apps/web/base/svc.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: flux-lab
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
YAML

cat > "$COURSE_ROOT/2/repo-fluxcd-app/apps/web/base/kustomization.yaml" <<'YAML'
resources:
- deploy.yaml
- svc.yaml
YAML

mkdir -p "$COURSE_ROOT/2/repo-fluxcd-app/clusters/dev"
cat > "$COURSE_ROOT/2/repo-fluxcd-app/clusters/dev/kustomization.yaml" <<'YAML'
resources:
- ../../apps/web/base
YAML

seed_git_repo_to_gitea "$COURSE_ROOT/2/repo-fluxcd-app" "cnpe-specific-fluxcd-app" "init fluxcd app repo"

mkdir -p "$COURSE_ROOT/6/repo-fluxcd-infra/tenants/dev"
cat > "$COURSE_ROOT/6/repo-fluxcd-infra/tenants/dev/namespace.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-dev
YAML

cat > "$COURSE_ROOT/6/repo-fluxcd-infra/tenants/dev/kustomization.yaml" <<'YAML'
resources:
- namespace.yaml
YAML

seed_git_repo_to_gitea "$COURSE_ROOT/6/repo-fluxcd-infra" "cnpe-specific-fluxcd-infra" "init fluxcd infra repo"

cat > "$COURSE_ROOT/README-fluxcd.txt" <<'TXT'
CNPE Batteria Specifica FluxCD

Namespace controller: flux-system
Namespace laboratorio: flux-lab

Repo seedati su Gitea:
- cnpe-specific-fluxcd-app
- cnpe-specific-fluxcd-infra

Working copies locali:
- /course/2/repo-fluxcd-app
- /course/6/repo-fluxcd-infra
TXT

ok "Setup batteria FluxCD completato"
echo "Course root: $COURSE_ROOT"
