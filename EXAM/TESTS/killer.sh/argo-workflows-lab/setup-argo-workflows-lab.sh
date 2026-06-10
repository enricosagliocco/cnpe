#!/usr/bin/env bash
set -euo pipefail

ARGO_WORKFLOWS_VERSION="${ARGO_WORKFLOWS_VERSION:-v4.0.5}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-argo-workflows}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-argo-workflows-lab}"
LAB_NAMESPACE="${LAB_NAMESPACE:-argo-workflows-lab}"

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
  kubectl delete namespace "$LAB_NAMESPACE" --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

info "Installing Argo Workflows ${ARGO_WORKFLOWS_VERSION}"
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argo -f \
  "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/install.yaml" >/dev/null
kubectl -n argo rollout status deployment/workflow-controller --timeout=300s
kubectl -n argo rollout status deployment/argo-server --timeout=300s
kubectl create namespace "$LAB_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$LAB_NAMESPACE" create serviceaccount workflow --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null
kubectl apply -f - >/dev/null <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-executor
  namespace: ${LAB_NAMESPACE}
rules:
  - apiGroups: [argoproj.io]
    resources: [workflowtaskresults]
    verbs: [create, patch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-executor
  namespace: ${LAB_NAMESPACE}
subjects:
  - kind: ServiceAccount
    name: workflow
    namespace: ${LAB_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-executor
YAML

for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done

cat > "$COURSE_DIR/01/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: TODO
  templates:
    - name: hello
      container: {} # TODO alpine:3.20 echo hello cnpe
YAML

cat > "$COURSE_DIR/02/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parameters-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: greet
  arguments:
    parameters: [] # TODO name=cnpe
  templates:
    - name: greet
      inputs:
        parameters: [] # TODO name default platform
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo hello TODO"]
YAML

cat > "$COURSE_DIR/03/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: sequential-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  templates:
    - name: main
      steps: [] # TODO prepare, build, verify sequentially
    - name: echo
      inputs:
        parameters:
          - name: message
      container:
        image: alpine:3.20
        command: [echo]
        args: ["{{inputs.parameters.message}}"]
YAML

cat > "$COURSE_DIR/04/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parallel-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  templates:
    - name: main
      steps: [] # TODO clone; lint + unit; report
    - name: task
      inputs:
        parameters:
          - name: name
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["sleep 2; echo {{inputs.parameters.name}}"]
YAML

cat > "$COURSE_DIR/05/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-build-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: build
  templates:
    - name: build
      dag:
        tasks: [] # TODO clone, lint/unit, package
    - name: task
      inputs:
        parameters:
          - name: name
      container:
        image: alpine:3.20
        command: [echo]
        args: ["{{inputs.parameters.name}}"]
YAML

cat > "$COURSE_DIR/06/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: output-parameter-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  templates:
    - name: main
      steps: [] # TODO version then publish
    - name: version
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo -n 2.3.1 > /tmp/version"]
      outputs:
        parameters:
          - name: version
            valueFrom:
              path: /tmp/version
    - name: publish
      inputs:
        parameters:
          - name: version
      container:
        image: alpine:3.20
        command: [echo]
        args: ["publishing {{inputs.parameters.version}}"]
YAML

cat > "$COURSE_DIR/07/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifacts-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  templates:
    - name: main
      steps: [] # TODO generate and consume artifact
    - name: generate
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo cnpe-report > /tmp/report.txt"]
      outputs:
        artifacts: [] # TODO
    - name: consume
      inputs:
        artifacts: [] # TODO /tmp/report.txt
      container:
        image: alpine:3.20
        command: [grep]
        args: [cnpe-report, /tmp/report.txt]
YAML

cat > "$COURSE_DIR/08/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: volume-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  volumes: [] # TODO emptyDir work
  templates:
    - name: main
      steps:
        - - name: write
            template: write
        - - name: read
            template: read
    - name: write
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo shared > /work/data"]
      volumeMounts: [] # TODO
    - name: read
      container:
        image: alpine:3.20
        command: [cat]
        args: [/work/data]
      volumeMounts: [] # TODO
YAML

cat > "$COURSE_DIR/09/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: pvc-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: use-volume
  volumeClaimGC:
    strategy: OnWorkflowCompletion
  volumeClaimTemplates: [] # TODO work 100Mi RWO
  templates:
    - name: use-volume
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["echo pvc > /work/result"]
      volumeMounts:
        - name: work
          mountPath: /work
YAML

cat > "$COURSE_DIR/10/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: conditional-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  arguments:
    parameters:
      - name: environment
        value: dev
  templates:
    - name: main
      steps:
        - - name: deploy
            template: deploy
            when: TODO
    - name: deploy
      container:
        image: alpine:3.20
        command: [echo]
        args: [deployed]
YAML

cat > "$COURSE_DIR/11/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: retry-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: unstable
  templates:
    - name: unstable
      retryStrategy: {} # TODO limit 2 and backoff
      container:
        image: python:3.13-alpine
        command: [sh, -c]
        args:
          - |
            echo attempt={{retries}}
            test "{{retries}}" -ge 2
YAML

cat > "$COURSE_DIR/12/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: timeout-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  activeDeadlineSeconds: 300 # TODO 30
  entrypoint: slow
  templates:
    - name: slow
      timeout: 30s # TODO 5s
      container:
        image: alpine:3.20
        command: [sleep]
        args: ["20"]
YAML

cat > "$COURSE_DIR/13/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: exit-handler-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: fail
  onExit: TODO
  templates:
    - name: fail
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["exit 1"]
    - name: notify
      container:
        image: alpine:3.20
        command: [echo]
        args: ["status={{workflow.status}}"]
YAML

cat > "$COURSE_DIR/14/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: continue-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: main
  templates:
    - name: main
      dag:
        tasks:
          - name: test
            template: fail
          - name: report
            template: report
            depends: test.Succeeded # TODO also Failed/Error
    - name: fail
      container:
        image: alpine:3.20
        command: [false]
    - name: report
      container:
        image: alpine:3.20
        command: [echo]
        args: [reported]
YAML

cat > "$COURSE_DIR/15/template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: reusable-greet
  namespace: argo-workflows-lab
spec:
  entrypoint: greet
  arguments:
    parameters: [] # TODO name
  templates:
    - name: greet
      inputs:
        parameters:
          - name: name
      container:
        image: alpine:3.20
        command: [echo]
        args: ["hello {{inputs.parameters.name}}"]
YAML
cat > "$COURSE_DIR/15/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: reusable-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  workflowTemplateRef: {} # TODO reusable-greet
  arguments:
    parameters:
      - name: name
        value: cnpe
YAML

cat > "$COURSE_DIR/16/cluster-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: cluster-greet
spec:
  entrypoint: greet
  templates:
    - name: greet
      container:
        image: alpine:3.20
        command: [echo]
        args: [cluster-template]
YAML
cat > "$COURSE_DIR/16/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: cluster-ref-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  workflowTemplateRef:
    name: TODO
    clusterScope: false # TODO
YAML
cat > "$COURSE_DIR/16/rbac.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-template-reader
  namespace: argo-workflows-lab
rules: [] # TODO least privilege
YAML

cat > "$COURSE_DIR/17/cronworkflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: periodic-report
  namespace: argo-workflows-lab
spec:
  schedules: [] # TODO every five minutes
  timezone: UTC
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 5
  workflowSpec:
    serviceAccountName: workflow
    entrypoint: report
    templates:
      - name: report
        container:
          image: alpine:3.20
          command: [date]
YAML

for name in one two; do
  cat > "$COURSE_DIR/18/workflow-${name}.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: mutex-${name}-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: deploy
  synchronization: {} # TODO mutex production-deploy
  templates:
    - name: deploy
      container:
        image: alpine:3.20
        command: [sh, -c]
        args: ["date; sleep 20; date"]
YAML
done

cat > "$COURSE_DIR/19/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: broken-
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: missing
  arguments:
    parameters:
      - name: wrong
        value: cnpe
  templates:
    - name: main
      dag:
        tasks:
          - name: second
            template: echo
            dependencies: [absent]
    - name: echo
      inputs:
        parameters:
          - name: message
      container:
        image: alpine:3.20
        command: [echo]
        args: ["{{inputs.parameters.message}}"]
YAML
touch "$COURSE_DIR/19/report.md"

cat > "$COURSE_DIR/20/workflow.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: final-build
  namespace: argo-workflows-lab
spec:
  serviceAccountName: workflow
  entrypoint: build
  onExit: cleanup
  arguments:
    parameters: [] # TODO repo, revision, image
  templates:
    - name: build
      dag:
        tasks: [] # TODO clone, lint/unit, package, scan, publish
    - name: task
      inputs:
        parameters:
          - name: name
      container:
        image: alpine:3.20
        command: [echo]
        args: ["{{inputs.parameters.name}}"]
    - name: cleanup
      container:
        image: alpine:3.20
        command: [echo]
        args: ["status={{workflow.status}}"]
  outputs: {} # TODO image and digest
YAML
touch "$COURSE_DIR/20/run.log"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
info "Argo Workflows lab ready: $COURSE_DIR"
info "UI: kubectl -n argo port-forward svc/argo-server 2746:2746"
