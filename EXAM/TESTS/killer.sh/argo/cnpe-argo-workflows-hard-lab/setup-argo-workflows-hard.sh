#!/usr/bin/env bash
# =============================================================================
# CNPE Hard Lab — Argo Workflows
# Scenario: argo-workflows-hard
#
# Focus:
#   - WorkflowTemplate
#   - Workflow
#   - DAG dependencies
#   - parameters/artifacts
#   - ServiceAccount/RBAC
#   - CronWorkflow
#   - workflow logs/status/resubmit
#
# Uso:
#   chmod +x setup-argo-workflows-hard.sh
#   ./setup-argo-workflows-hard.sh
#   ./setup-argo-workflows-hard.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-argo-wf-hard}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-10000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

ARGO_NS="argo"
LAB_NS="wf-lab"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/argo-workflows-hard}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$LAB_NS" "$ARGO_NS" --ignore-not-found --timeout=180s 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl curl; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --driver="$DRIVER" --cpus="$CPUS" --memory="${MEMORY}mb" --disk-size=45g --kubernetes-version="$K8S_VERSION" --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

info "install Argo Workflows"
kubectl create ns "$ARGO_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$ARGO_NS" -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
kubectl -n "$ARGO_NS" wait --for=condition=Available deployment --all --timeout=300s

kubectl create ns "$LAB_NS" --dry-run=client -o yaml | kubectl apply -f -

cat > "$LAB_DIR/00-rbac-broken.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow
  namespace: wf-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-basic
  namespace: wf-lab
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
# BUG: mancano configmaps create/patch/get per task create-report
# BUG: mancano workflows get/list/watch per alcune operazioni di troubleshooting
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-basic
  namespace: wf-lab
subjects:
- kind: ServiceAccount
  name: workflow
  namespace: wf-lab
roleRef:
  kind: Role
  name: workflow-basic
  apiGroup: rbac.authorization.k8s.io
YAML

cat > "$LAB_DIR/10-workflowtemplate-broken.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-check-template
  namespace: wf-lab
spec:
  entrypoint: main
  serviceAccountName: workflow
  arguments:
    parameters:
    - name: app-name
      value: payments
    - name: environment
      value: dev
  templates:
  - name: main
    dag:
      tasks:
      - name: generate
        template: generate-report
        arguments:
          parameters:
          - name: app-name
            value: "{{workflow.parameters.app-name}}"
      - name: validate
        template: validate-report
        dependencies:
        - generate
        arguments:
          artifacts:
          - name: report
            from: "{{tasks.generate.outputs.artifacts.report}}"
      - name: security-scan
        template: scan-report
        dependencies:
        - validate
        arguments:
          artifacts:
          - name: report
            from: "{{tasks.generate.outputs.artifacts.report}}"
      - name: create-summary
        template: create-configmap
        # BUG: dovrebbe dipendere da validate e security-scan
        dependencies:
        - validate
        arguments:
          parameters:
          - name: app-name
            value: "{{workflow.parameters.app-name}}"
          - name: environment
            value: "{{workflow.parameters.environment}}"

  - name: generate-report
    inputs:
      parameters:
      - name: app-name
    outputs:
      artifacts:
      - name: report
        path: /tmp/report.txt
    container:
      image: alpine:3.20
      command: [sh, -c]
      args:
      - |
        set -eu
        echo "app={{inputs.parameters.app-name}}" > /tmp/report.txt
        echo "status=ok" >> /tmp/report.txt
        echo "security=passed" >> /tmp/report.txt

  - name: validate-report
    inputs:
      artifacts:
      - name: report
        path: /tmp/report.txt
    container:
      image: alpine:3.20
      command: [sh, -c]
      args:
      - |
        set -eu
        grep "status=ok" /tmp/report.txt

  - name: scan-report
    inputs:
      artifacts:
      - name: report
        # BUG: path diverso da quello usato nello script
        path: /tmp/input/report.txt
    container:
      image: alpine:3.20
      command: [sh, -c]
      args:
      - |
        set -eu
        grep "security=passed" /tmp/report.txt

  - name: create-configmap
    inputs:
      parameters:
      - name: app-name
      - name: environment
    container:
      image: bitnami/kubectl:1.33
      command: [sh, -c]
      args:
      - |
        set -eu
        kubectl -n wf-lab create configmap "summary-{{inputs.parameters.app-name}}" \
          --from-literal=environment="{{inputs.parameters.environment}}" \
          --from-literal=result=passed \
          --dry-run=client -o yaml | kubectl apply -f -
YAML

cat > "$LAB_DIR/20-workflow-broken.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: app-check-
  namespace: wf-lab
spec:
  workflowTemplateRef:
    name: app-check-template
  arguments:
    parameters:
    - name: app-name
      value: payments
    - name: environment
      value: staging
YAML

cat > "$LAB_DIR/30-cronworkflow-broken.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: nightly-app-check
  namespace: wf-lab
spec:
  # BUG: schedule ogni minuto, ma la domanda chiede giornaliero alle 02:30
  schedule: "* * * * *"
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 10
  failedJobsHistoryLimit: 10
  workflowSpec:
    workflowTemplateRef:
      name: app-check-template
    arguments:
      parameters:
      - name: app-name
        value: catalog
      - name: environment
        value: prod
YAML

kubectl apply -f "$LAB_DIR/00-rbac-broken.yaml"
kubectl apply -f "$LAB_DIR/10-workflowtemplate-broken.yaml"
kubectl apply -f "$LAB_DIR/30-cronworkflow-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Scenario: argo-workflows-hard
Argo namespace: argo
Lab namespace: wf-lab

UI opzionale:
  kubectl -n argo port-forward svc/argo-server 2746:2746

File:
  /course/argo-workflows-hard/00-rbac-broken.yaml
  /course/argo-workflows-hard/10-workflowtemplate-broken.yaml
  /course/argo-workflows-hard/20-workflow-broken.yaml
  /course/argo-workflows-hard/30-cronworkflow-broken.yaml
EOF

kubectl -n "$LAB_NS" get workflowtemplate,cronworkflow,sa,role,rolebinding
ok "Argo Workflows hard lab pronto: $LAB_DIR"
