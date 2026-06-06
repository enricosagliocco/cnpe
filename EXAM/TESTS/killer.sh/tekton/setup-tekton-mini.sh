#!/usr/bin/env bash
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-tekton-mini}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

NS="tekton-mini"
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"
REPO_NAME="${REPO_NAME:-tekton-mini-app}"
REPO_URL="${GITEA_URL%/}/${GITEA_ORG}/${REPO_NAME}.git"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/tekton-mini}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete ns tekton-pipelines --ignore-not-found --timeout=180s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

have minikube || die "minikube non trovato"
have kubectl || die "kubectl non trovato"
have curl || die "curl non trovato"
have git || die "git non trovato"
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --driver="$DRIVER" --cpus="$CPUS" --memory="${MEMORY}mb" --disk-size=35g --kubernetes-version="$K8S_VERSION" --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

info "install Tekton Pipelines/Triggers"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
kubectl -n tekton-pipelines wait --for=condition=Available deployment --all --timeout=300s

kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

info "creo repo Gitea demo"
WORK="$LAB_DIR/git-work"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
cat > app.py <<'EOF'
print("hello from tekton mini lab")
EOF
touch requirements.txt
cat > README.md <<'EOF'
# tekton-mini-app
EOF
cat > Dockerfile <<'EOF'
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
EOF
git init -b main >/dev/null
git config user.email "cnpe@example.local"
git config user.name "CNPE Lab"
git add . && git commit -m "initial app" >/dev/null
curl -sS -X POST "${GITEA_URL%/}/api/v1/orgs/${GITEA_ORG}/repos" -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" -d "{\"name\":\"${REPO_NAME}\",\"private\":false,\"auto_init\":false}" >/dev/null || true
git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
git push -u origin main >/dev/null 2>&1 || echo "[WARN] push Gitea fallito: controlla URL/token/org"

cat > "$LAB_DIR/00-rbac.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: tekton-mini
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pipeline-basic
  namespace: tekton-mini
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "configmaps", "secrets", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["tekton.dev"]
  resources: ["tasks", "taskruns", "pipelines", "pipelineruns"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# BUG: manca apps/deployments
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pipeline-basic
  namespace: tekton-mini
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: tekton-mini
roleRef:
  kind: Role
  name: pipeline-basic
  apiGroup: rbac.authorization.k8s.io
EOF

cat > "$LAB_DIR/10-tasks-broken.yaml" <<'EOF'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-clone-lite
  namespace: tekton-mini
spec:
  params:
  - name: url
    type: string
  - name: revision
    type: string
    default: main
  workspaces:
  - name: output
  results:
  - name: commit
  steps:
  - name: clone
    image: alpine/git:2.45.2
    script: |
      #!/bin/sh
      set -eu
      rm -rf $(workspaces.output.path)/*
      git clone --branch "$(params.revision)" "$(params.url)" "$(workspaces.output.path)/source"
      cd "$(workspaces.output.path)/source"
      git rev-parse HEAD | tee "$(results.commit.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: unit-test
  namespace: tekton-mini
spec:
  workspaces:
  - name: source
  steps:
  - name: test
    image: python:3.12-alpine
    workingDir: $(workspaces.source.path)
    script: |
      #!/bin/sh
      set -eu
      # BUG: app.py sta in source/
      test -f app.py
      python app.py
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: render-manifest
  namespace: tekton-mini
spec:
  params:
  - name: image
    type: string
  workspaces:
  - name: source
  results:
  - name: manifest
  steps:
  - name: render
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      mkdir -p "$(workspaces.source.path)/rendered"
      cat > "$(workspaces.source.path)/rendered/deploy.yaml" <<YAML
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: tekton-mini-app
        namespace: tekton-mini
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: tekton-mini-app
        template:
          metadata:
            labels:
              app: tekton-mini-app
          spec:
            containers:
            - name: app
              image: $(params.image)
      YAML
      echo "$(workspaces.source.path)/rendered/deploy.yaml" | tee "$(results.manifest.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: kubectl-apply
  namespace: tekton-mini
spec:
  params:
  - name: manifest
    type: string
  workspaces:
  - name: source
  steps:
  - name: apply
    image: bitnami/kubectl:1.33
    script: |
      #!/bin/sh
      set -eu
      kubectl apply -f "$(params.manifest)"
EOF

cat > "$LAB_DIR/20-pipeline-broken.yaml" <<EOF
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: app-ci
  namespace: tekton-mini
spec:
  params:
  - name: repo-url
    type: string
    default: ${REPO_URL}
  - name: revision
    type: string
    default: main
  - name: image
    type: string
    default: nginx:1.27-alpine
  workspaces:
  - name: shared
  tasks:
  - name: clone
    taskRef:
      name: git-clone-lite
    params:
    - name: url
      value: \$(params.repo-url)
    - name: revision
      value: \$(params.revision)
    workspaces:
    - name: output
      workspace: shared
  - name: tests
    taskRef:
      name: unit-test
    runAfter: ["clone"]
    workspaces:
    - name: source
      workspace: shared
  - name: render
    taskRef:
      name: render-manifest
    runAfter: ["tests"]
    params:
    - name: image
      value: \$(params.image)
    workspaces:
    - name: source
      workspace: shared
  - name: deploy
    taskRef:
      name: kubectl-apply
    runAfter: ["render"]
    params:
    - name: manifest
      value: \$(tasks.render.results.manifest)
    workspaces:
    - name: source
      workspace: shared
EOF

cat > "$LAB_DIR/30-pipelinerun-broken.yaml" <<EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: app-ci-manual-
  namespace: tekton-mini
spec:
  serviceAccountName: pipeline
  pipelineRef:
    name: app-ci
  params:
  - name: repo-url
    value: ${REPO_URL}
  - name: revision
    value: main
  - name: image
    value: nginx:1.27-alpine
  workspaces:
  - name: shared
    emptyDir: {}
EOF

cat > "$LAB_DIR/40-triggers-broken.yaml" <<EOF
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: gitea-push-binding
  namespace: tekton-mini
spec:
  params:
  - name: gitrepositoryurl
    value: \$(body.repository.clone_url)
  - name: gitrevision
    value: \$(body.ref) # BUG: usare body.after o rendere clone compatibile
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: app-ci-template
  namespace: tekton-mini
spec:
  params:
  - name: gitrepositoryurl
  - name: gitrevision
  resourcetemplates:
  - apiVersion: tekton.dev/v1
    kind: PipelineRun
    metadata:
      generateName: app-ci-from-trigger-
    spec:
      serviceAccountName: pipeline
      pipelineRef:
        name: app-ci
      params:
      - name: repo-url
        value: \$(tt.params.gitrepositoryurl)
      - name: revision
        value: \$(tt.params.gitrevision)
      - name: image
        value: nginx:1.27-alpine
      workspaces:
      - name: shared
        emptyDir: {}
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: gitea-listener
  namespace: tekton-mini
spec:
  serviceAccountName: pipeline
  triggers:
  - name: gitea-push
    bindings:
    - ref: gitea-push-binding
    template:
      ref: app-ci-template
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-listener-nodeport
  namespace: tekton-mini
spec:
  type: NodePort
  selector:
    eventlistener: gitea-listener
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30080
EOF

kubectl apply -f "$LAB_DIR/00-rbac.yaml"
kubectl apply -f "$LAB_DIR/10-tasks-broken.yaml"
kubectl apply -f "$LAB_DIR/20-pipeline-broken.yaml"
kubectl apply -f "$LAB_DIR/40-triggers-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Namespace: tekton-mini
Repo Gitea: ${REPO_URL}
EventListener: http://$(minikube -p "$PROFILE" ip 2>/dev/null):30080
EOF

kubectl -n "$NS" get task,pipeline,triggertemplate,triggerbinding,eventlistener,svc
ok "lab Tekton pronto: $LAB_DIR"
