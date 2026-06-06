#!/usr/bin/env bash
# =============================================================================
# CNPE Hard Lab — Tekton Exam-like
# Scenario: tekton-hard
#
# Stile:
#   - setup iniziale con risorse volutamente incomplete/rotte
#   - repository Git remoto su Gitea
#   - Task/Pipeline/Trigger già presenti ma da correggere
#   - domande performance-based con output da salvare
#
# Gitea default:
#   GITEA_URL=http://192.168.1.56:3000/
#   GITEA_TOKEN=d2fcd54b7a8e2762920d929bfd4456db208659e4
#   GITEA_USER=cnpe-user
#   GITEA_PASS=cnpe-pass
#   GITEA_ORG=organization
#
# Uso:
#   chmod +x setup-tekton-hard.sh
#   ./setup-tekton-hard.sh
#   ./setup-tekton-hard.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-tekton-hard}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-10000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

NS="builder"
APP_NS="apps-prod"
DEV_NS="apps-dev"

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"
REPO_NAME="${REPO_NAME:-tekton-hard-app}"
REPO_URL="${GITEA_URL%/}/${GITEA_ORG}/${REPO_NAME}.git"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/tekton-hard}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info(){ echo -e "${CYAN}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERR]${NC} $*"; exit 1; }
section(){ echo -e "\n${BOLD}${GREEN}== $* ==${NC}\n"; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  section "Cleanup"
  kubectl delete ns "$NS" "$APP_NS" "$DEV_NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete ns tekton-pipelines --ignore-not-found --timeout=180s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[[ "${1:-}" == "--cleanup" ]] && cleanup

section "0. Prerequisiti"
for c in minikube kubectl curl git; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

section "1. Minikube"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=45g \
    --kubernetes-version="$K8S_VERSION" \
    --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

section "2. Install Tekton"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
kubectl -n tekton-pipelines wait --for=condition=Available deployment --all --timeout=300s

section "3. Namespaces"
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns "$APP_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns "$DEV_NS" --dry-run=client -o yaml | kubectl apply -f -

section "4. Repo Gitea"
WORK="$LAB_DIR/repo-work"
rm -rf "$WORK"
mkdir -p "$WORK/k8s/base" "$WORK/k8s/overlays/dev" "$WORK/k8s/overlays/prod" "$WORK/scripts"
cd "$WORK"

cat > app.py <<'PY'
import os
print("tekton hard app version=" + os.getenv("APP_VERSION", "0.1.0"))
PY

cat > requirements.txt <<'REQ'
REQ

cat > Dockerfile <<'DOCKER'
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
ENV APP_VERSION=0.1.0
CMD ["python", "app.py"]
DOCKER

cat > k8s/base/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tekton-hard-app
  labels:
    app: tekton-hard-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tekton-hard-app
  template:
    metadata:
      labels:
        app: tekton-hard-app
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        env:
        - name: APP_VERSION
          value: "0.1.0"
        ports:
        - containerPort: 80
YAML

cat > k8s/base/service.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: tekton-hard-app
spec:
  selector:
    app: tekton-hard-app
  ports:
  - port: 80
    targetPort: 80
YAML

cat > k8s/base/kustomization.yaml <<'YAML'
resources:
- deployment.yaml
- service.yaml
YAML

cat > k8s/overlays/dev/kustomization.yaml <<'YAML'
namespace: apps-dev
resources:
- ../../base
namePrefix: dev-
commonLabels:
  env: dev
patches:
- target:
    kind: Deployment
    name: tekton-hard-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
YAML

cat > k8s/overlays/prod/kustomization.yaml <<'YAML'
namespace: apps-prod
resources:
- ../../base
namePrefix: prod-
commonLabels:
  env: prod
patches:
- target:
    kind: Deployment
    name: tekton-hard-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
YAML

cat > scripts/check.sh <<'SH'
#!/usr/bin/env sh
set -eu
test -f app.py
python app.py | grep "tekton hard app"
SH
chmod +x scripts/check.sh

cat > README.md <<'MD'
# tekton-hard-app

Repository usato dal CNPE hard Tekton lab.

Contiene:
- codice app Python minimale
- manifest Kustomize base/dev/prod
- script di test
MD

git init -b main >/dev/null
git config user.email "cnpe@example.local"
git config user.name "CNPE Lab"
git add .
git commit -m "initial app and kustomize manifests" >/dev/null

git checkout -b release >/dev/null
sed -i 's/0.1.0/0.2.0/g' app.py Dockerfile k8s/base/deployment.yaml
git add .
git commit -m "release 0.2.0" >/dev/null
git checkout main >/dev/null

curl -sS -X POST "${GITEA_URL%/}/api/v1/orgs/${GITEA_ORG}/repos" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"auto_init\":false}" >/dev/null || true

git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
git push -u origin main >/dev/null 2>&1 || warn "push main verso Gitea fallito"
git push -u origin release >/dev/null 2>&1 || warn "push release verso Gitea fallito"

section "5. RBAC, Tasks, Pipeline e Trigger difettosi"
cat > "$LAB_DIR/00-rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: builder
  namespace: builder
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: builder-tekton
  namespace: builder
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "configmaps", "secrets", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["tekton.dev"]
  resources: ["tasks", "taskruns", "pipelines", "pipelineruns"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# BUG: mancano permessi per creare/patchare namespace e deploy in apps-dev/apps-prod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: builder-tekton
  namespace: builder
subjects:
- kind: ServiceAccount
  name: builder
  namespace: builder
roleRef:
  kind: Role
  name: builder-tekton
  apiGroup: rbac.authorization.k8s.io
YAML

cat > "$LAB_DIR/01-cross-namespace-rbac-broken.yaml" <<'YAML'
# BUG: RoleBinding verso la ServiceAccount sbagliata.
# Deve permettere alla ServiceAccount builder/builder di applicare Deployment e Service in apps-dev e apps-prod.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer
  namespace: apps-dev
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer
  namespace: apps-dev
subjects:
- kind: ServiceAccount
  name: default
  namespace: builder
roleRef:
  kind: Role
  name: app-deployer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer
  namespace: apps-prod
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer
  namespace: apps-prod
subjects:
- kind: ServiceAccount
  name: default
  namespace: builder
roleRef:
  kind: Role
  name: app-deployer
  apiGroup: rbac.authorization.k8s.io
YAML

cat > "$LAB_DIR/10-tasks-broken.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-fetch
  namespace: builder
spec:
  params:
  - name: url
    type: string
  - name: revision
    type: string
    default: main
  workspaces:
  - name: repo
  results:
  - name: commit
    description: checked out commit
  steps:
  - name: fetch
    image: alpine/git:2.45.2
    script: |
      #!/bin/sh
      set -eu
      rm -rf "$(workspaces.repo.path)"/*
      # BUG: --branch non funziona bene se revision è un commit SHA da webhook.
      git clone --branch "$(params.revision)" "$(params.url)" "$(workspaces.repo.path)/src"
      cd "$(workspaces.repo.path)/src"
      git rev-parse HEAD | tee "$(results.commit.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: source-test
  namespace: builder
spec:
  workspaces:
  - name: repo
  steps:
  - name: test
    image: python:3.12-alpine
    # BUG: path sbagliato; il repo è clonato in src/
    workingDir: $(workspaces.repo.path)
    script: |
      #!/bin/sh
      set -eu
      ./scripts/check.sh
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: render-kustomize
  namespace: builder
spec:
  params:
  - name: environment
    type: string
    default: dev
  - name: image
    type: string
  workspaces:
  - name: repo
  results:
  - name: manifest
    description: rendered manifest path
  steps:
  - name: render
    image: line/kubectl-kustomize:1.33.0-5.6.0
    script: |
      #!/bin/sh
      set -eu
      cd "$(workspaces.repo.path)/src"
      # BUG: prod/dev path non validato; se environment errato fallisce in modo poco chiaro.
      kubectl kustomize "k8s/overlays/$(params.environment)" > "$(workspaces.repo.path)/rendered.yaml"
      # BUG: non sostituisce davvero l'immagine nel manifest renderizzato.
      echo "$(workspaces.repo.path)/rendered.yaml" | tee "$(results.manifest.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: policy-scan
  namespace: builder
spec:
  params:
  - name: forbidden
    type: string
  - name: manifest
    type: string
  steps:
  - name: scan
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      if grep -R "$(params.forbidden)" "$(params.manifest)"; then
        echo "forbidden word found: $(params.forbidden)"
        exit 1
      fi
      echo "ok"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: apply-manifest
  namespace: builder
spec:
  params:
  - name: manifest
    type: string
  steps:
  - name: apply
    image: bitnami/kubectl:1.33
    script: |
      #!/bin/sh
      set -eu
      kubectl apply -f "$(params.manifest)"
YAML

cat > "$LAB_DIR/20-pipeline-broken.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: app-delivery
  namespace: builder
spec:
  params:
  - name: repo-url
    type: string
    default: ${REPO_URL}
  - name: revision
    type: string
    default: main
  - name: environment
    type: string
    default: dev
  - name: image
    type: string
    default: nginx:1.27-alpine
  - name: forbidden1
    type: string
    default: latest
  - name: forbidden2
    type: string
    default: privileged
  workspaces:
  - name: shared
  tasks:
  - name: fetch
    taskRef:
      name: git-fetch
    params:
    - name: url
      value: \$(params.repo-url)
    - name: revision
      value: \$(params.revision)
    workspaces:
    - name: repo
      workspace: shared

  - name: test
    taskRef:
      name: source-test
    runAfter:
    - fetch
    workspaces:
    - name: repo
      workspace: shared

  - name: render
    taskRef:
      name: render-kustomize
    runAfter:
    - test
    params:
    - name: environment
      value: \$(params.environment)
    - name: image
      value: \$(params.image)
    workspaces:
    - name: repo
      workspace: shared

  # BUG: le due scan dovrebbero girare in parallelo dopo render; qui scan2 dipende da scan1.
  - name: scan-forbidden1
    taskRef:
      name: policy-scan
    runAfter:
    - render
    params:
    - name: forbidden
      value: \$(params.forbidden1)
    - name: manifest
      value: \$(tasks.render.results.manifest)

  - name: scan-forbidden2
    taskRef:
      name: policy-scan
    runAfter:
    - scan-forbidden1
    params:
    - name: forbidden
      value: \$(params.forbidden2)
    - name: manifest
      value: \$(tasks.render.results.manifest)

  - name: deploy
    taskRef:
      name: apply-manifest
    runAfter:
    - scan-forbidden1
    # BUG: manca scan-forbidden2 tra le dipendenze di deploy.
    params:
    - name: manifest
      value: \$(tasks.render.results.manifest)
YAML

cat > "$LAB_DIR/30-pipelinerun-dev-broken.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: app-delivery-dev-
  namespace: builder
spec:
  serviceAccountName: builder
  pipelineRef:
    name: app-delivery
  params:
  - name: repo-url
    value: ${REPO_URL}
  - name: revision
    value: main
  - name: environment
    value: dev
  - name: image
    value: nginx:1.27-alpine
  - name: forbidden1
    value: latest
  - name: forbidden2
    value: privileged
  workspaces:
  - name: shared
    emptyDir: {}
YAML

cat > "$LAB_DIR/31-pipelinerun-prod-broken.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: app-delivery-prod-
  namespace: builder
spec:
  serviceAccountName: builder
  pipelineRef:
    name: app-delivery
  params:
  - name: repo-url
    value: ${REPO_URL}
  - name: revision
    value: release
  - name: environment
    value: prod
  - name: image
    value: httpd:2-alpine
  - name: forbidden1
    value: latest
  - name: forbidden2
    value: privileged
  workspaces:
  - name: shared
    emptyDir: {}
YAML

cat > "$LAB_DIR/40-triggers-broken.yaml" <<YAML
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: gitea-push-binding
  namespace: builder
spec:
  params:
  - name: git-url
    value: \$(body.repository.clone_url)
  - name: git-revision
    # BUG: con Gitea push il commit SHA è body.after; body.ref è refs/heads/main.
    value: \$(body.ref)
  - name: git-branch
    value: \$(body.ref)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: app-delivery-template
  namespace: builder
spec:
  params:
  - name: git-url
  - name: git-revision
  - name: git-branch
  resourcetemplates:
  - apiVersion: tekton.dev/v1
    kind: PipelineRun
    metadata:
      generateName: app-delivery-from-gitea-
      labels:
        source: gitea
        # BUG: manca label exam=cnpe richiesta nelle domande
    spec:
      serviceAccountName: builder
      pipelineRef:
        name: app-delivery
      params:
      - name: repo-url
        value: \$(tt.params.git-url)
      - name: revision
        value: \$(tt.params.git-revision)
      - name: environment
        # BUG: ogni push va in prod, troppo rischioso; deve andare dev per main e prod solo release
        value: prod
      - name: image
        value: nginx:1.27-alpine
      - name: forbidden1
        value: latest
      - name: forbidden2
        value: privileged
      workspaces:
      - name: shared
        emptyDir: {}
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: gitea-listener
  namespace: builder
spec:
  serviceAccountName: builder
  triggers:
  - name: gitea-push
    interceptors:
    - ref:
        name: cel
      params:
      - name: filter
        # BUG: filtra solo release, quindi push main non genera PipelineRun
        value: "body.ref == 'refs/heads/release'"
    bindings:
    - ref: gitea-push-binding
    template:
      ref: app-delivery-template
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-listener-nodeport
  namespace: builder
spec:
  type: NodePort
  selector:
    eventlistener: gitea-listener
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30081
YAML

kubectl apply -f "$LAB_DIR/00-rbac.yaml"
kubectl apply -f "$LAB_DIR/01-cross-namespace-rbac-broken.yaml"
kubectl apply -f "$LAB_DIR/10-tasks-broken.yaml"
kubectl apply -f "$LAB_DIR/20-pipeline-broken.yaml"
kubectl apply -f "$LAB_DIR/40-triggers-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Scenario: tekton-hard
Namespace Tekton lab: builder
Namespaces applicativi: apps-dev, apps-prod

Repo Gitea:
  ${REPO_URL}

Branch:
  main
  release

EventListener:
  http://$(minikube -p "$PROFILE" ip 2>/dev/null):30081

File:
  /course/tekton-hard/00-rbac.yaml
  /course/tekton-hard/01-cross-namespace-rbac-broken.yaml
  /course/tekton-hard/10-tasks-broken.yaml
  /course/tekton-hard/20-pipeline-broken.yaml
  /course/tekton-hard/30-pipelinerun-dev-broken.yaml
  /course/tekton-hard/31-pipelinerun-prod-broken.yaml
  /course/tekton-hard/40-triggers-broken.yaml
EOF

section "6. Stato iniziale"
kubectl -n "$NS" get task,pipeline,eventlistener,triggerbinding,triggertemplate,svc
echo
kubectl get ns "$NS" "$APP_NS" "$DEV_NS"
echo
warn "Lab pronto. Domande nel file domande-tekton-hard.md del pack."
ok "Completato"
