#!/usr/bin/env bash
set -euo pipefail

ARGO_CD_VERSION="${ARGO_CD_VERSION:-v3.4.3}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-argocd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-argocd-lab}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

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

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    - https://github.com/argoproj/argocd-example-apps.git
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
        repoURL: https://github.com/argoproj/argocd-example-apps.git
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
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        revision: master
        directories: [] # TODO valid directories
  template:
    metadata:
      name: 'TODO'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
    - repoURL: https://github.com/argoproj/argocd-example-apps.git
      targetRevision: master
      path: guestbook
    - repoURL: TODO
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
    repoURL: https://github.com/argoproj/argocd-example-apps.git
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
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
info "Argo CD lab ready: $COURSE_DIR"
info "UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
