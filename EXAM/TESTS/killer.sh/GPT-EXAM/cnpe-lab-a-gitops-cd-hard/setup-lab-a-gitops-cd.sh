#!/usr/bin/env bash
# =============================================================================
# CNPE Lab A — GitOps & Continuous Delivery Hard
#
# Focus lacuna ufficiale:
#   GitOps and Continuous Delivery 25%
#
# Componenti:
#   - Gitea esterno
#   - Argo CD
#   - Flux
#   - Tekton Pipelines/Triggers
#   - Argo Rollouts
#
# Gitea default:
#   GITEA_URL=http://192.168.1.56:3000/
#   GITEA_TOKEN=d2fcd54b7a8e2762920d929bfd4456db208659e4
#   GITEA_USER=cnpe-user
#   GITEA_PASS=cnpe-pass
#   GITEA_ORG=organization
#
# Uso:
#   chmod +x setup-lab-a-gitops-cd.sh
#   ./setup-lab-a-gitops-cd.sh
#   ./setup-lab-a-gitops-cd.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-lab-a-gitops}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-12000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"

APP_REPO="${APP_REPO:-cnpe-lab-a-apps}"
APP_REPO_URL="${GITEA_URL%/}/${GITEA_ORG}/${APP_REPO}.git"

NS_ARGO="argocd"
NS_FLUX="flux-system"
NS_TEKTON="tekton-pipelines"
NS_CI="ci"
NS_DELIVERY="delivery"
NS_DEV="app-dev"
NS_PROD="app-prod"
NS_ROLLOUTS="rollouts-lab"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/lab-a-gitops-cd}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$NS_ARGO" "$NS_FLUX" "$NS_TEKTON" "$NS_CI" "$NS_DELIVERY" "$NS_DEV" "$NS_PROD" "$NS_ROLLOUTS" argo-rollouts --ignore-not-found --timeout=240s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl helm git curl; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=50g \
    --kubernetes-version="$K8S_VERSION" \
    --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

for ns in "$NS_CI" "$NS_DELIVERY" "$NS_DEV" "$NS_PROD" "$NS_ROLLOUTS"; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

info "creo repo Gitea"
WORK="$LAB_DIR/repo-work"
rm -rf "$WORK"
mkdir -p "$WORK/apps/web/manifests" "$WORK/apps/api/manifests" "$WORK/apps/rollout" "$WORK/argocd/apps" "$WORK/flux/apps/web" "$WORK/helm/podinfo-values"

cd "$WORK"

cat > apps/web/manifests/web.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-client
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 80;
        location / {
          return 200 'CNPE Web v1';
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
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
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: web-config
        configMap:
          name: web-client
---
apiVersion: v1
kind: Service
metadata:
  name: web-client
spec:
  selector:
    app: web-client
  ports:
  - port: 80
    targetPort: 80
YAML

cat > apps/web/manifests/kustomization.yaml <<'YAML'
resources:
- web.yaml
YAML

cat > apps/api/manifests/api.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      containers:
      - name: http
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
YAML

cat > apps/api/manifests/kustomization.yaml <<'YAML'
resources:
- api.yaml
YAML

cat > apps/rollout/rollout.yaml <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payments
  strategy:
    canary:
      steps:
      - setWeight: 50
      - pause: {}
      - setWeight: 100
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  selector:
    app: payments
  ports:
  - port: 80
    targetPort: 80
YAML

cat > apps/rollout/kustomization.yaml <<'YAML'
resources:
- rollout.yaml
YAML

cat > argocd/apps/web-app-broken.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-client
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${APP_REPO_URL}
    targetRevision: main
    # BUG: path errato
    path: apps/web/wrong
  destination:
    server: https://kubernetes.default.svc
    namespace: app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cat > argocd/apps/api-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${APP_REPO_URL}
    targetRevision: main
    path: apps/api/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cat > argocd/app-of-apps-broken.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${APP_REPO_URL}
    targetRevision: main
    # BUG: path contiene solo una app rotta se web non fixata
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cat > argocd/applicationset-broken.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-generator
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: ${APP_REPO_URL}
      revision: main
      directories:
      # BUG: pattern sbagliato, non scopre apps/*/manifests
      - path: services/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: ${APP_REPO_URL}
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: app-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF

cat > flux/apps/web/gitrepository-broken.yaml <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: web-source
  namespace: flux-system
spec:
  interval: 30s
  url: ${APP_REPO_URL}
  ref:
    # BUG: branch inesistente
    branch: master
EOF

cat > flux/apps/web/kustomization-broken.yaml <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: web-flux
  namespace: flux-system
spec:
  interval: 30s
  targetNamespace: app-prod
  sourceRef:
    kind: GitRepository
    name: web-source
  # BUG: path errato
  path: ./apps/web/badpath
  prune: true
  timeout: 1m
YAML

cat > helm/podinfo-values/values.yaml <<'YAML'
replicaCount: 2
YAML

git init -b main >/dev/null
git config user.email "cnpe@example.local"
git config user.name "CNPE Lab"
git add .
git commit -m "initial gitops apps" >/dev/null

git checkout -b testing >/dev/null
sed -i 's/CNPE Web v1/CNPE Web testing/g; s/version: v1/version: v3/g' apps/web/manifests/web.yaml
git add apps/web/manifests/web.yaml
git commit -m "testing web version" >/dev/null
git checkout main >/dev/null

curl -sS -X POST "${GITEA_URL%/}/api/v1/orgs/${GITEA_ORG}/repos" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${APP_REPO}\",\"private\":false,\"auto_init\":false}" >/dev/null || true

git remote add origin "$APP_REPO_URL" 2>/dev/null || git remote set-url origin "$APP_REPO_URL"
git push -u origin main >/dev/null 2>&1 || warn "push main Gitea fallito"
git push -u origin testing >/dev/null 2>&1 || warn "push testing Gitea fallito"

info "install Argo CD"
kubectl create ns "$NS_ARGO" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$NS_ARGO" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n "$NS_ARGO" wait --for=condition=Available deployment --all --timeout=300s
kubectl -n "$NS_ARGO" patch secret argocd-secret -p '{"stringData":{"admin.password":"$2a$10$rRyWIPK37UyCDLPgBQ2a4.P5Dxi7OU1./stK/bAD3BfZ4uVm3D6S6","admin.passwordMtime":"2026-01-01T00:00:00Z"}}' >/dev/null || true

info "install Flux controllers"
kubectl create ns "$NS_FLUX" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
kubectl -n "$NS_FLUX" wait --for=condition=Available deployment --all --timeout=300s

info "install Tekton"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
kubectl -n "$NS_TEKTON" wait --for=condition=Available deployment --all --timeout=300s

info "install Argo Rollouts"
kubectl create ns argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n argo-rollouts wait --for=condition=Available deployment --all --timeout=300s

cat > "$LAB_DIR/00-argocd-objects.yaml" <<EOF
$(cat "$WORK/argocd/app-of-apps-broken.yaml")
---
$(cat "$WORK/argocd/applicationset-broken.yaml")
EOF

cat > "$LAB_DIR/01-flux-broken.yaml" <<EOF
$(cat "$WORK/flux/apps/web/gitrepository-broken.yaml")
---
$(cat "$WORK/flux/apps/web/kustomization-broken.yaml")
EOF

cat > "$LAB_DIR/02-tekton-broken.yaml" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: ci
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-checkout
  namespace: ci
spec:
  params:
  - name: repo-url
    type: string
  - name: revision
    type: string
    default: main
  workspaces:
  - name: source
  results:
  - name: commit
  steps:
  - name: clone
    image: alpine/git:2.45.2
    script: |
      #!/bin/sh
      set -eu
      rm -rf "\$(workspaces.source.path)"/*
      # BUG: fragile with SHA and branches
      git clone --branch "\$(params.revision)" "\$(params.repo-url)" "\$(workspaces.source.path)/repo"
      cd "\$(workspaces.source.path)/repo"
      git rev-parse HEAD | tee "\$(results.commit.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: manifest-test
  namespace: ci
spec:
  workspaces:
  - name: source
  steps:
  - name: test
    image: bitnami/kubectl:1.33
    workingDir: \$(workspaces.source.path)
    script: |
      #!/bin/sh
      set -eu
      # BUG: path sbagliato: repo è in repo/
      kubectl kustomize apps/web/manifests >/tmp/out.yaml
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: gitops-validate
  namespace: ci
spec:
  params:
  - name: repo-url
    type: string
    default: ${APP_REPO_URL}
  - name: revision
    type: string
    default: main
  workspaces:
  - name: shared
  tasks:
  - name: checkout
    taskRef:
      name: git-checkout
    params:
    - name: repo-url
      value: \$(params.repo-url)
    - name: revision
      value: \$(params.revision)
    workspaces:
    - name: source
      workspace: shared
  - name: test-manifest
    taskRef:
      name: manifest-test
    runAfter:
    - checkout
    workspaces:
    - name: source
      workspace: shared
---
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: gitops-validate-
  namespace: ci
spec:
  serviceAccountName: pipeline
  pipelineRef:
    name: gitops-validate
  params:
  - name: repo-url
    value: ${APP_REPO_URL}
  - name: revision
    value: main
  workspaces:
  - name: shared
    emptyDir: {}
EOF

cat > "$LAB_DIR/03-rollout-broken.yaml" <<EOF
$(cat "$WORK/apps/rollout/rollout.yaml")
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: rollout-smoke
  namespace: rollouts-lab
spec:
  metrics:
  - name: smoke
    count: 1
    successCondition: result == "ok"
    provider:
      job:
        spec:
          template:
            spec:
              restartPolicy: Never
              containers:
              - name: check
                image: alpine:3.20
                command: [sh, -c]
                args:
                # BUG: stampa passed, non ok
                - echo passed
EOF

kubectl apply -f "$LAB_DIR/00-argocd-objects.yaml" || true
kubectl apply -f "$LAB_DIR/01-flux-broken.yaml" || true
kubectl apply -f "$LAB_DIR/02-tekton-broken.yaml"
kubectl apply -f "$LAB_DIR/03-rollout-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
CNPE Lab A — GitOps & CD

Repo:
  ${APP_REPO_URL}

Branch:
  main
  testing

Namespaces:
  argocd
  flux-system
  ci
  app-dev
  app-prod
  rollouts-lab

Argo CD:
  admin/admin

Files:
  /course/lab-a-gitops-cd/00-argocd-objects.yaml
  /course/lab-a-gitops-cd/01-flux-broken.yaml
  /course/lab-a-gitops-cd/02-tekton-broken.yaml
  /course/lab-a-gitops-cd/03-rollout-broken.yaml
EOF

kubectl get ns argocd flux-system ci app-dev app-prod rollouts-lab
kubectl -n argocd get applications,applicationsets 2>/dev/null || true
kubectl -n flux-system get gitrepository,kustomization 2>/dev/null || true
kubectl -n ci get task,pipeline,pipelinerun
kubectl -n rollouts-lab get rollout,analysistemplate
ok "Lab A pronto: $LAB_DIR"
