#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-gitops-progressive-delivery}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-existing}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-gitops}"
ARGO_CD_VERSION="${ARGO_CD_VERSION:-v3.4.2}"
FLUX_VERSION="${FLUX_VERSION:-v2.8.8}"
TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
ARGO_ROLLOUTS_VERSION="${ARGO_ROLLOUTS_VERSION:-v1.9.0}"

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
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_tools() {
  info "Installing Argo CD ${ARGO_CD_VERSION}"
  kubectl create namespace argocd --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
  kubectl apply -n argocd -f \
    "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml" \
    >/dev/null
  kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
  kubectl -n argocd rollout status statefulset/argocd-application-controller \
    --timeout=300s

  info "Installing Flux ${FLUX_VERSION}"
  kubectl apply -f \
    "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/install.yaml" \
    >/dev/null
  kubectl -n flux-system rollout status deployment/source-controller \
    --timeout=300s
  kubectl -n flux-system rollout status deployment/kustomize-controller \
    --timeout=300s

  info "Installing Tekton Pipelines ${TEKTON_VERSION}"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml" \
    >/dev/null
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-pipelines-webhook --timeout=300s

  info "Installing Argo Rollouts ${ARGO_ROLLOUTS_VERSION}"
  kubectl create namespace argo-rollouts --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
  kubectl apply -n argo-rollouts -f \
    "https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml" \
    >/dev/null
  kubectl -n argo-rollouts rollout status deployment/argo-rollouts \
    --timeout=300s
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  install_tools
else
  kubectl get crd applications.argoproj.io >/dev/null 2>&1 ||
    die "Argo CD CRDs are required"
  kubectl get crd gitrepositories.source.toolkit.fluxcd.io >/dev/null 2>&1 ||
    die "Flux CRDs are required"
  kubectl get crd pipelines.tekton.dev >/dev/null 2>&1 ||
    die "Tekton CRDs are required"
  kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 ||
    die "Argo Rollouts CRDs are required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  for namespace in gitops-apps gitops-infra ci-pipeline progressive-delivery; do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=true
  done
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done
for namespace in gitops-apps gitops-infra ci-pipeline progressive-delivery; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

cat > "$COURSE_DIR/01/application.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: nonexistent-branch
    path: wrong-path
  destination:
    server: https://kubernetes.default.svc
    namespace: gitops-apps
  syncPolicy: {} # TODO automated prune and selfHeal
YAML
kubectl apply -f "$COURSE_DIR/01/application.yaml" >/dev/null
touch "$COURSE_DIR/01/status.txt"

cat > "$COURSE_DIR/02/source.yaml" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-infra
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/fluxcd/flux2-kustomize-helm-example
  ref:
    branch: missing
YAML

cat > "$COURSE_DIR/02/kustomization.yaml" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-infra
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: platform-infra
  path: ./missing
  targetNamespace: gitops-infra
  prune: false
  wait: true
  timeout: 2m
YAML
kubectl apply -f "$COURSE_DIR/02/source.yaml" >/dev/null
kubectl apply -f "$COURSE_DIR/02/kustomization.yaml" >/dev/null
touch "$COURSE_DIR/02/reconcile.txt"

cat > "$COURSE_DIR/03/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: application-ci
  namespace: ci-pipeline
spec:
  params:
    - name: repo-url
      type: string
      default: https://github.com/argoproj/argocd-example-apps.git
    - name: revision
      type: string
      default: master
    - name: image
      type: string
      default: registry.example/guestbook:v2
  workspaces:
    - name: source
  results:
    - name: promotion-file
      value: $(tasks.prepare-promotion.results.file)
  tasks:
    - name: clone
      taskSpec:
        params:
          - name: repo-url
          - name: revision
        workspaces:
          - name: source
        steps:
          - name: clone
            image: alpine/git:2.47.2
            script: |
              #!/bin/sh
              git clone --depth 1 --branch "$(params.revision)" \
                "$(params.repo-url)" "$(workspaces.source.path)/repo"
      params:
        - name: repo-url
          value: $(params.repo-url)
        - name: revision
          value: $(params.revision)
      workspaces:
        - name: source
          workspace: source
    - name: test
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: validate
            image: alpine:3.20
            script: |
              #!/bin/sh
              test -f "$(workspaces.source.path)/repo/guestbook/guestbook-ui-deployment.yaml"
      # TODO runAfter clone and bind workspace
    - name: prepare-promotion
      taskSpec:
        params:
          - name: image
        workspaces:
          - name: source
        results:
          - name: file
        steps:
          - name: render
            image: alpine:3.20
            script: |
              #!/bin/sh
              mkdir -p "$(workspaces.source.path)/promotion"
              cat > "$(workspaces.source.path)/promotion/image-patch.yaml" <<EOF
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: guestbook-ui
              spec:
                template:
                  spec:
                    containers:
                      - name: guestbook-ui
                        image: $(params.image)
              EOF
              echo -n promotion/image-patch.yaml > $(results.file.path)
      params:
        - name: image
          value: $(params.image)
      # TODO runAfter test and bind workspace
YAML

cat > "$COURSE_DIR/03/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: application-ci-
  namespace: ci-pipeline
spec:
  pipelineRef:
    name: application-ci
  workspaces:
    - name: source
      emptyDir: {}
YAML
touch "$COURSE_DIR/03/pipeline-result.txt"

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: canary-stable
  namespace: progressive-delivery
spec:
  selector:
    app: canary-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: canary-preview
  namespace: progressive-delivery
spec:
  selector:
    app: canary-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-active
  namespace: progressive-delivery
spec:
  selector:
    app: bluegreen-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-preview
  namespace: progressive-delivery
spec:
  selector:
    app: bluegreen-api
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

cat > "$COURSE_DIR/04/canary-rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-api
  namespace: progressive-delivery
spec:
  replicas: 4
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: canary-api
  template:
    metadata:
      labels:
        app: canary-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          env:
            - name: VERSION
              value: v1
          ports:
            - name: http
              containerPort: 80
  strategy:
    canary:
      stableService: TODO
      canaryService: TODO
      steps: [] # TODO 25%, pause 20s, 50%, manual pause, 100%
YAML
touch "$COURSE_DIR/04/events.txt"

cat > "$COURSE_DIR/05/bluegreen-rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bluegreen-api
  namespace: progressive-delivery
spec:
  replicas: 2
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: bluegreen-api
  template:
    metadata:
      labels:
        app: bluegreen-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          env:
            - name: VERSION
              value: v1
          ports:
            - name: http
              containerPort: 80
  strategy:
    blueGreen:
      activeService: TODO
      previewService: TODO
      autoPromotionEnabled: true # TODO false
      scaleDownDelaySeconds: 0 # TODO 30
YAML
touch "$COURSE_DIR/05/promotion.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/../lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "GitOps and progressive delivery lab ready: $COURSE_DIR"
info "Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
kubectl -n argocd get applications
kubectl -n flux-system get gitrepositories,kustomizations
kubectl -n progressive-delivery get services
