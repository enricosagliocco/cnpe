#!/usr/bin/env bash
set -euo pipefail

ARGO_CD_VERSION="${ARGO_CD_VERSION:-v3.4.3}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-argocd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-argocd-lab}"
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_ORG="${GITEA_ORG:-organization}"
GITEA_URL="${GITEA_URL%/}"
EXAMPLE_REPO_NAME="${EXAMPLE_REPO_NAME:-argocd-example-apps}"
EXTRA_REPO_NAME="${EXTRA_REPO_NAME:-argocd-extra-apps}"
EXAMPLE_REPO_URL="${GITEA_URL}/${GITEA_ORG}/${EXAMPLE_REPO_NAME}.git"
EXTRA_REPO_URL="${GITEA_URL}/${GITEA_ORG}/${EXTRA_REPO_NAME}.git"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

gitea_status() {
  local method=$1 path=$2 data=${3:-}
  local args=(
    -sS -o /dev/null -w "%{http_code}" -X "$method"
    -H "Authorization: token ${GITEA_TOKEN}"
    -H "Content-Type: application/json"
  )
  [ -z "$data" ] || args+=(-d "$data")
  curl "${args[@]}" "${GITEA_URL}${path}"
}

ensure_gitea_org() {
  local code
  code="$(gitea_status GET "/api/v1/orgs/${GITEA_ORG}")"
  if [ "$code" != "200" ]; then
    code="$(gitea_status POST "/api/v1/orgs" \
      "{\"username\":\"${GITEA_ORG}\",\"full_name\":\"${GITEA_ORG}\"}")"
    [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "409" ] ||
      die "Cannot create/access Gitea organization ${GITEA_ORG} (HTTP ${code})"
  fi
}

ensure_gitea_repo() {
  local repo=$1 code
  code="$(gitea_status GET "/api/v1/repos/${GITEA_ORG}/${repo}")"
  if [ "$code" != "200" ]; then
    code="$(gitea_status POST "/api/v1/orgs/${GITEA_ORG}/repos" \
      "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}")"
    [ "$code" = "201" ] || [ "$code" = "200" ] || [ "$code" = "409" ] ||
      die "Cannot create/access Gitea repository ${GITEA_ORG}/${repo} (HTTP ${code})"
  fi
}

gitea_authenticated_url() {
  local repo=$1 login
  login="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/user" |
    sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [ -n "$login" ] || die "Cannot determine the Gitea user associated with GITEA_TOKEN"
  case "$GITEA_URL" in
    http://*) printf 'http://%s:%s@%s/%s/%s.git\n' \
      "$login" "$GITEA_TOKEN" "${GITEA_URL#http://}" "$GITEA_ORG" "$repo" ;;
    https://*) printf 'https://%s:%s@%s/%s/%s.git\n' \
      "$login" "$GITEA_TOKEN" "${GITEA_URL#https://}" "$GITEA_ORG" "$repo" ;;
    *) die "GITEA_URL must start with http:// or https://" ;;
  esac
}

prepare_gitea_repositories() {
  local work_dir example_auth_url extra_auth_url
  work_dir="$(mktemp -d)"

  ensure_gitea_org
  ensure_gitea_repo "$EXAMPLE_REPO_NAME"
  ensure_gitea_repo "$EXTRA_REPO_NAME"
  example_auth_url="$(gitea_authenticated_url "$EXAMPLE_REPO_NAME")"
  extra_auth_url="$(gitea_authenticated_url "$EXTRA_REPO_NAME")"

  info "Mirroring Argo CD example applications to ${EXAMPLE_REPO_URL}"
  git clone --quiet --depth 1 --branch master \
    https://github.com/argoproj/argocd-example-apps.git "$work_dir/example"
  git -C "$work_dir/example" push --quiet --force "$example_auth_url" HEAD:master

  mkdir -p "$work_dir/extra/extras"
  cat > "$work_dir/extra/extras/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-extra-source
data:
  lab: multi-source
YAML
  git -C "$work_dir/extra" init --quiet --initial-branch=main
  git -C "$work_dir/extra" config user.name "CNPE Lab Setup"
  git -C "$work_dir/extra" config user.email "cnpe-lab@local"
  git -C "$work_dir/extra" add extras/configmap.yaml
  git -C "$work_dir/extra" commit --quiet -m "Add multi-source lab manifests"
  git -C "$work_dir/extra" push --quiet --force "$extra_auth_url" HEAD:main
  rm -rf "$work_dir"
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if ! kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

for command_name in kubectl curl git sed; do
  command -v "$command_name" >/dev/null || die "$command_name is required"
done

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

prepare_gitea_repositories
ensure_cluster

if [ "$LAB_FORCE" = "true" ]; then
  for ns in argocd-apps team-a team-b helm-apps kustomize-apps; do
    kubectl delete namespace "$ns" --ignore-not-found --wait=true
  done
  rm -rf "$COURSE_DIR"
fi

info "Installing Argo CD ${ARGO_CD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply --server-side --force-conflicts -n argocd -f \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml" >/dev/null
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done

cat > "$COURSE_DIR/01/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: source-lab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: missing
    path: wrong
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-apps
YAML

cat > "$COURSE_DIR/02/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: destination-lab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: guestbook
  destination: {} # TODO local cluster and argocd-apps
YAML

cat > "$COURSE_DIR/03/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: automated-lab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-apps
  syncPolicy:
    automated: {} # TODO prune and selfHeal
YAML

for q in 04 05 06 08; do
  name="app-${q}"
  namespace="argocd-apps"
  [ "$q" = "04" ] && namespace="team-a"
  cat > "$COURSE_DIR/$q/application.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: ${namespace}
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions: [] # TODO
YAML
done

cat > "$COURSE_DIR/07/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ignore-replicas
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-apps
  ignoreDifferences: [] # TODO apps/Deployment /spec/replicas
YAML

cat > "$COURSE_DIR/09/project.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  sourceRepos: [] # TODO example repository
  destinations: [] # TODO team-* on local cluster
YAML
cat > "$COURSE_DIR/09/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-guestbook
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: team-a
YAML

cat > "$COURSE_DIR/10/project.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  sourceRepos:
    - __EXAMPLE_REPO_URL__
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-*
  namespaceResourceWhitelist: [] # TODO Deployment, Service, ConfigMap
  clusterResourceWhitelist: [] # keep empty
YAML

cat > "$COURSE_DIR/11/project.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: orphan-lab
  namespace: argocd
spec:
  sourceRepos:
    - '*'
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-a
  orphanedResources: {} # TODO warn true
YAML

cat > "$COURSE_DIR/12/applicationset.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements: [] # TODO dev and stage
  template:
    metadata:
      name: 'guestbook-{{environment}}'
    spec:
      project: default
      source:
        repoURL: __EXAMPLE_REPO_URL__
        targetRevision: master
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: 'team-{{environment}}'
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
YAML

cat > "$COURSE_DIR/13/applicationset.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: discovered-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: __EXAMPLE_REPO_URL__
        revision: master
        directories: [] # TODO valid directories
  template:
    metadata:
      name: 'TODO'
    spec:
      project: default
      source:
        repoURL: __EXAMPLE_REPO_URL__
        targetRevision: master
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd-apps
YAML

cat > "$COURSE_DIR/14/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: helm-guestbook
    helm:
      parameters: [] # TODO service.type and replicaCount
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-apps
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML

cat > "$COURSE_DIR/15/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: master
    path: kustomize-guestbook
    kustomize: {} # TODO prefix and common label
  destination:
    server: https://kubernetes.default.svc
    namespace: kustomize-apps
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
YAML

cat > "$COURSE_DIR/16/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-source-lab
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: __EXAMPLE_REPO_URL__
      targetRevision: master
      path: guestbook
    - repoURL: __EXTRA_REPO_URL__
      targetRevision: TODO
      path: TODO
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-apps
YAML

cat > "$COURSE_DIR/17/project.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: maintenance
  namespace: argocd
spec:
  sourceRepos: ['*']
  destinations:
    - server: https://kubernetes.default.svc
      namespace: maintenance-*
  syncWindows: [] # TODO deny and manual allow
YAML

cat > "$COURSE_DIR/18/argocd-rbac-cm.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # TODO role developer: get and sync platform/dev-*, no delete
    # TODO group team-dev
  policy.default: role:readonly
YAML

cat > "$COURSE_DIR/19/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: broken-app
  namespace: argocd
spec:
  project: missing-project
  source:
    repoURL: __EXAMPLE_REPO_URL__
    targetRevision: missing
    path: missing
  destination:
    server: https://wrong.invalid
    namespace: team-a
YAML
touch "$COURSE_DIR/19/report.md"

cat > "$COURSE_DIR/20/project.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: final-platform
  namespace: argocd
spec:
  sourceRepos: [] # TODO
  destinations: [] # TODO dev and stage only
YAML
cat > "$COURSE_DIR/20/applicationset.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: final-platform
  namespace: argocd
spec:
  generators: [] # TODO dev and stage
  template: {} # TODO environment-specific sync policy
YAML
cat > "$COURSE_DIR/20/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: | # TODO dev and stage roles
YAML
touch "$COURSE_DIR/20/final-report.md"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
find "$COURSE_DIR" -type f \( -name '*.yaml' -o -name '*.md' \) -exec \
  sed -i \
    -e "s|__EXAMPLE_REPO_URL__|${EXAMPLE_REPO_URL}|g" \
    -e "s|__EXTRA_REPO_URL__|${EXTRA_REPO_URL}|g" {} +
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
info "Argo CD lab ready: $COURSE_DIR"
info "Example repository: $EXAMPLE_REPO_URL (branch master)"
info "Extra repository: $EXTRA_REPO_URL (branch main, path extras)"
info "UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
