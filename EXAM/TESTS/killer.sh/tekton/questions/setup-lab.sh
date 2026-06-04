#!/usr/bin/env bash
# ============================================================
#  CNPE Tekton Lab — scenario builder / tekton-lab
#
#  Problemi introdotti:
#   - Pipeline: runAfter errato, when con nome task sbagliato
#   - Task: nome parametro errato in script, workspace non montato
#   - PipelineRun: ServiceAccount inesistente, workspace non bound
#   - RBAC: RoleBinding subject namespace errato
#   - team-sandwich: workload per task di scan
#
#  Usage:
#    chmod +x setup-lab.sh && ./setup-lab.sh
#    ./setup-lab.sh --cleanup
# ============================================================
set -euo pipefail

BUILDER_NS="builder"
TEKTON_NS="tekton-pipelines"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-cnpe}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-10000}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
DASHBOARD_NODEPORT="${DASHBOARD_NODEPORT:-30220}"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/tekton-lab}"

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

apply_with_retry() {
  local file="$1" attempts="${2:-24}"
  local i
  for i in $(seq 1 "$attempts"); do
    kubectl apply -f "$file" 2>/dev/null && return 0
    sleep 5
  done
  kubectl apply -f "$file"
}

cleanup_lab() {
  section "Cleanup Tekton lab"
  kubectl delete namespace team-sandwich team-butter team-croissant --ignore-not-found --timeout=60s 2>/dev/null || true
  kubectl delete pipelinerun --all -n "$BUILDER_NS" --ignore-not-found 2>/dev/null || true
  kubectl delete taskrun --all -n "$BUILDER_NS" --ignore-not-found 2>/dev/null || true
  kubectl delete pipeline,task -n "$BUILDER_NS" -l cnpe-lab=true --ignore-not-found 2>/dev/null || true
  kubectl delete pipeline cnpe-release cnpe-team-onboard cnpe-policy-scan -n "$BUILDER_NS" --ignore-not-found 2>/dev/null || true
  kubectl delete task cnpe-fetch-config cnpe-build-image cnpe-kubectl-deploy cnpe-notify-fail cnpe-create-ns cnpe-create-rbac cnpe-policy-scan -n "$BUILDER_NS" --ignore-not-found 2>/dev/null || true
  kubectl delete role,rolebinding,sa -n "$BUILDER_NS" -l cnpe-lab=true --ignore-not-found 2>/dev/null || true
  kubectl delete pvc cnpe-manifests-ws -n "$BUILDER_NS" --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  success "Cleanup completato (Tekton lasciato installato)"
  exit 0
}

[[ "${1:-}" == "--cleanup" ]] && cleanup_lab

section "0. Prerequisites"
have_cmd kubectl  || die "kubectl non trovato"
have_cmd minikube || die "minikube non trovato"
mkdir -p "$LAB_DIR"

section "1. Minikube (${K8S_VERSION})"
if ! minikube status -p "$MINIKUBE_PROFILE" &>/dev/null; then
  minikube start -p "$MINIKUBE_PROFILE" \
    --driver="$MINIKUBE_DRIVER" --cpus="$MINIKUBE_CPUS" \
    --memory="${MINIKUBE_MEMORY}mb" --disk-size=40g \
    --kubernetes-version="$K8S_VERSION" \
    --extra-config=kubelet.fail-swap-on=false \
    --extra-config=kubeadm.ignore-preflight-errors=SystemVerification,Swap,NumCPU,Mem,ContainerRuntime \
    --force
fi
export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$MINIKUBE_PROFILE" 2>/dev/null || echo "${HOME}/.kube/config")"
export KUBECONFIG

section "2. Tekton Pipelines + Dashboard"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.68.0/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/previous/v0.54.0/release.yaml 2>/dev/null || true

kubectl -n "$TEKTON_NS" wait deploy/tekton-pipelines-webhook --for=condition=Available --timeout=300s
kubectl -n "$TEKTON_NS" rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl -n "$TEKTON_NS" rollout status deploy/tekton-dashboard --timeout=300s 2>/dev/null || true

kubectl -n "$TEKTON_NS" patch svc tekton-dashboard --type merge -p "{
  \"spec\": {
    \"type\": \"NodePort\",
    \"ports\": [{\"port\": 9097, \"targetPort\": 9097, \"nodePort\": ${DASHBOARD_NODEPORT}, \"protocol\": \"TCP\", \"name\": \"http\"}]
  }
}" 2>/dev/null || true

if have_cmd curl && ! have_cmd tkn; then
  TKN_VER="0.38.1"
  curl -sSL "https://github.com/tektoncd/cli/releases/download/v${TKN_VER}/tkn_${TKN_VER}_Linux_x86_64.tar.gz" \
    | sudo tar -xzf - -C /usr/local/bin tkn 2>/dev/null || warn "tkn CLI non installata (opzionale)"
fi

section "3. Namespace builder + RBAC (rotto)"
kubectl create namespace "$BUILDER_NS" --dry-run=client -o yaml | kubectl apply -f -

cat >"$LAB_DIR/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline-runner
  namespace: builder
  labels:
    cnpe-lab: "true"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pipeline-runner-role
  namespace: builder
  labels:
    cnpe-lab: "true"
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "secrets", "configmaps", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
# BUG: subject punta a ServiceAccount nel namespace default, non builder
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pipeline-runner-binding
  namespace: builder
  labels:
    cnpe-lab: "true"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pipeline-runner-role
subjects:
  - kind: ServiceAccount
    name: pipeline-runner
    namespace: default
YAML
kubectl apply -f "$LAB_DIR/rbac.yaml"

cat >"$LAB_DIR/manifests/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnpe-sample-app
  namespace: builder
data:
  APP_NAME: "cnpe-demo"
YAML
kubectl apply -f "$LAB_DIR/manifests/configmap.yaml"

cat >"$LAB_DIR/pvc-workspace.yaml" <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cnpe-manifests-ws
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 64Mi
YAML
kubectl apply -f "$LAB_DIR/pvc-workspace.yaml"

section "4. Task e Pipeline (rotte)"
cat >"$LAB_DIR/tekton-resources.yaml" <<'YAML'
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-fetch-config
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: gitRevision
      type: string
  workspaces:
    - name: manifest-ws
  steps:
    - name: write-manifest
      image: busybox:1.36
      script: |
        #!/bin/sh
        set -eux
        echo "revision=$(params.gitRevision)" > $(workspaces.manifest-ws.path)/build.meta
        echo "ok" > $(workspaces.manifest-ws.path)/ready.txt
---
# BUG: script usa $(params.git-revision) invece di gitRevision
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-build-image
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: gitRevision
      type: string
    - name: imageRepo
      type: string
  workspaces:
    - name: manifest-ws
  steps:
    - name: build
      image: busybox:1.36
      script: |
        #!/bin/sh
        set -eux
        test -f $(workspaces.manifest-ws.path)/ready.txt
        echo "Building $(params.imageRepo) at revision $(params.git-revision)"
        echo "image=$(params.imageRepo):$(params.git-revision)" >> $(workspaces.manifest-ws.path)/build.meta
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-kubectl-deploy
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: targetNamespace
      type: string
  workspaces:
    - name: manifest-ws
  steps:
    - name: deploy
      image: bitnami/kubectl:latest
      script: |
        #!/usr/bin/env bash
        set -eux
        kubectl create ns $(params.targetNamespace) --dry-run=client -o yaml | kubectl apply -f -
        kubectl -n $(params.targetNamespace) create configmap cnpe-built \
          --from-file=$(workspaces.manifest-ws.path)/build.meta \
          --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-notify-fail
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: pipelineRun
      type: string
  steps:
    - name: notify
      image: busybox:1.36
      script: |
        #!/bin/sh
        echo "ALERT: pipeline $(params.pipelineRun) failed"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: cnpe-release
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: gitRevision
      type: string
    - name: imageRepo
      type: string
      default: "registry.example/cnpe-app"
    - name: targetNamespace
      type: string
  workspaces:
    - name: shared-manifests
  tasks:
    - name: fetch
      taskRef:
        name: cnpe-fetch-config
      params:
        - name: gitRevision
          value: $(params.gitRevision)
      workspaces:
        - name: manifest-ws
          workspace: shared-manifests
    - name: build
      taskRef:
        name: cnpe-build-image
      # BUG: runAfter punta a task inesistente "checkout"
      runAfter:
        - checkout
      params:
        - name: gitRevision
          value: $(params.gitRevision)
        - name: imageRepo
          value: $(params.imageRepo)
      workspaces:
        - name: manifest-ws
          workspace: shared-manifests
    - name: deploy
      taskRef:
        name: cnpe-kubectl-deploy
      runAfter:
        - build
      params:
        - name: targetNamespace
          value: $(params.targetNamespace)
      workspaces:
        - name: manifest-ws
          workspace: shared-manifests
  finally:
    - name: alert-on-fail
      taskRef:
        name: cnpe-notify-fail
      # BUG: when usa nome task "build-image" invece di "build"
      when:
        - input: "$(tasks.build-image.status)"
          operator: in
          values: ["Failed"]
      params:
        - name: pipelineRun
          value: "$(context.pipelineRun.name)"
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-create-ns
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: team-name
      type: string
  steps:
    - name: create
      image: bitnami/kubectl:latest
      script: |
        #!/usr/bin/env bash
        set -eux
        kubectl create ns team-$(params.team-name) --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-create-rbac
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: team-name
      type: string
  steps:
    - name: bind
      image: bitnami/kubectl:latest
      script: |
        #!/usr/bin/env bash
        set -eux
        kubectl create rolebinding team-$(params.team-name)-view \
          --clusterrole=view \
          --serviceaccount=team-$(params.team-name):default \
          -n team-$(params.team-name) \
          --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: cnpe-team-onboard
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: team-name
      type: string
  tasks:
    - name: create-namespace
      taskRef:
        name: cnpe-create-ns
      params:
        - name: team-name
          value: $(params.team-name)
    - name: create-rbac
      taskRef:
        name: cnpe-create-rbac
      runAfter:
        - create-namespace
      params:
        - name: team-name
          value: $(params.team-name)
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: cnpe-policy-scan
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: team-name
      type: string
    - name: forbidden
      type: string
  steps:
    - name: scan
      image: bitnami/kubectl:latest
      script: |
        #!/usr/bin/env bash
        set -eux
        kubectl get pods -n team-$(params.team-name) -oyaml | grep -E "$(params.forbidden)" && \
          echo "FORBIDDEN pattern $(params.forbidden) found" && exit 1 || \
          echo "Scan OK in team-$(params.team-name)"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: cnpe-policy-scan
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  params:
    - name: team-name
      type: string
    - name: forbidden1
      type: string
    - name: forbidden2
      type: string
  tasks:
    - name: scan-a
      taskRef:
        name: cnpe-policy-scan
      params:
        - name: team-name
          value: $(params.team-name)
        - name: forbidden
          value: $(params.forbidden1)
    - name: scan-b
      taskRef:
        name: cnpe-policy-scan
      params:
        - name: team-name
          value: $(params.team-name)
        - name: forbidden
          # BUG: riusa forbidden1 invece di forbidden2
          value: $(params.forbidden1)
YAML
apply_with_retry "$LAB_DIR/tekton-resources.yaml"

section "5. PipelineRun esempio (fallirà)"
cat >"$LAB_DIR/pipelinerun-release.yaml" <<'YAML'
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: cnpe-release-
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  pipelineRef:
    name: cnpe-release
  # BUG: SA inesistente
  serviceAccountName: tekton-bot
  params:
    - name: gitRevision
      value: "v1.2.3"
    - name: targetNamespace
      value: "cnpe-staging"
  workspaces:
    - name: shared-manifests
      # BUG: emptyDir al posto del PVC preparato (opzionale) — manca persistentVolumeClaim
      emptyDir: {}
YAML

cat >"$LAB_DIR/pipelinerun-onboard-butter.yaml" <<'YAML'
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: onboard-butter
  namespace: builder
  labels:
    cnpe-lab: "true"
spec:
  pipelineRef:
    name: cnpe-team-onboard
  serviceAccountName: pipeline-runner
  params:
    - name: team-name
      value: butter
YAML

kubectl create -f "$LAB_DIR/pipelinerun-release.yaml" 2>/dev/null || true
kubectl apply -f "$LAB_DIR/pipelinerun-onboard-butter.yaml" 2>/dev/null || true

section "6. team-sandwich (target scan)"
kubectl create namespace team-sandwich --dry-run=client -o yaml | kubectl apply -f -
kubectl -n team-sandwich apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: crypto-miner
  labels:
    app: miner
spec:
  containers:
    - name: miner
      image: busybox:1.36
      command: ["sh", "-c", "echo miner-running; sleep 3600"]
YAML

section "7. Stato atteso"
sleep 15
echo ""
kubectl -n "$BUILDER_NS" get task,pipeline,pipelinerun,taskrun 2>/dev/null || true
echo ""
MINIKUBE_IP="$(minikube ip -p "$MINIKUBE_PROFILE" 2>/dev/null || echo "?")"
warn "Problemi attesi:"
echo "  • cnpe-release        → runAfter checkout; when build-image; SA tekton-bot"
echo "  • cnpe-build-image    → param git-revision vs gitRevision"
echo "  • pipeline-runner RBAC → RoleBinding subject in namespace default"
echo "  • cnpe-policy-scan    → scan-b usa forbidden1 due volte"
echo "  • onboard-butter      → fallisce RBAC finché binding non corretto"
echo "  • team-sandwich       → pod per scan forbidden pattern"
echo ""
info "Dashboard: http://${MINIKUBE_IP}:${DASHBOARD_NODEPORT}"
info "Port-forward: kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard ${DASHBOARD_NODEPORT}:9097"
info "Domande:  EXAM/TESTS/killer.sh/tekton/questions/domande.md"
info "Risposte: EXAM/TESTS/killer.sh/tekton/questions/risposte.md"
success "Lab Tekton pronto in ${LAB_DIR}"
