#!/usr/bin/env bash
set -euo pipefail

TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
TEKTON_TRIGGERS_VERSION="${TEKTON_TRIGGERS_VERSION:-v0.33.0}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-tekton}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-tekton-lab}"
LOCAL_PATH_MANIFEST_URL="${LOCAL_PATH_MANIFEST_URL:-https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml}"

die() { echo "[ERR] $*" >&2; exit 1; }

write_send_event_script() {
  local question=$1 listener=$2 port=$3
  cat > "$COURSE_DIR/$question/send-event.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

payload="\${1:?usage: ./send-event.sh PAYLOAD.json}"
port="\${PORT:-$port}"
response="\${2:-response.json}"
log_file="\$(mktemp)"

kubectl -n tekton-lab wait --for=condition=Ready \
  "eventlistener/$listener" --timeout=90s
kubectl -n tekton-lab port-forward \
  "service/el-$listener" "\${port}:8080" >"\$log_file" 2>&1 &
forward_pid=\$!
cleanup() {
  kill "\$forward_pid" 2>/dev/null || true
  wait "\$forward_pid" 2>/dev/null || true
  rm -f "\$log_file"
}
trap cleanup EXIT

for _ in \$(seq 1 30); do
  if curl -sS -o /dev/null "http://127.0.0.1:\${port}" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

http_code="\$(curl -sS -o "\$response" -w '%{http_code}' \
  -X POST "http://127.0.0.1:\${port}" \
  -H 'Content-Type: application/json' \
  --data-binary "@\$payload")"
echo "HTTP \$http_code"
cat "\$response"
echo
EOF
  chmod +x "$COURSE_DIR/$question/send-event.sh"
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        echo "[INFO] Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
        echo "[INFO] Creating kind cluster: $KIND_CLUSTER_NAME"
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if kubectl cluster-info >/dev/null 2>&1; then
        return
      fi
      command -v minikube >/dev/null 2>&1 ||
        die "No reachable Kubernetes cluster and Minikube is not installed"
      echo "[INFO] No reachable cluster; starting Minikube"
      minikube start --cpus=4 --memory=6144
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a cluster"
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac

  kubectl cluster-info >/dev/null 2>&1 ||
    die "$CLUSTER_PROVIDER started, but kubectl cannot reach the cluster"
}

ensure_storage() {
  if [ "$CLUSTER_PROVIDER" != "kind" ]; then
    return
  fi

  echo "[INFO] Installing local-path storage provisioner"
  kubectl apply -f "$LOCAL_PATH_MANIFEST_URL" >/dev/null
  kubectl -n local-path-storage rollout status \
    deployment/local-path-provisioner --timeout=180s

  kubectl annotate storageclass local-path \
    storageclass.kubernetes.io/is-default-class=true --overwrite >/dev/null
}

command -v kubectl >/dev/null || die "kubectl is required"
command -v curl >/dev/null || die "curl is required"
ensure_cluster
ensure_storage
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  kubectl delete namespace tekton-lab --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

kubectl apply -f "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml"
kubectl apply -f "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/release.yaml"
kubectl apply -f "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/interceptors.yaml"
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-webhook --timeout=300s
kubectl -n tekton-pipelines patch configmap feature-flags --type merge \
  -p '{"data":{"enable-api-fields":"beta"}}' >/dev/null
kubectl apply -f "https://infra.tekton.dev/tekton-releases/dashboard/latest/release.yaml"
kubectl -n tekton-pipelines rollout status deploy/tekton-dashboard --timeout=300s
kubectl create ns tekton-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null
mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

cat > "$COURSE_DIR/01/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: greet
  namespace: tekton-lab
spec:
  params: [] # TODO name string default platform
  steps:
    - name: greet
      image: alpine:3.20
      script: |
        #!/bin/sh
        echo "hello TODO"
YAML
cat > "$COURSE_DIR/01/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: greet-
  namespace: tekton-lab
spec:
  taskRef:
    name: greet
  params: [] # TODO name=cnpe
YAML

cat > "$COURSE_DIR/02/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: sequential-build
  namespace: tekton-lab
spec:
  workspaces:
    - name: output
  steps: [] # TODO prepare, build, verify
YAML
cat > "$COURSE_DIR/02/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: sequential-build-
  namespace: tekton-lab
spec:
  taskRef:
    name: sequential-build
  workspaces:
    - name: output
      emptyDir: {}
YAML
cat > "$COURSE_DIR/03/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-metadata
  namespace: tekton-lab
spec:
  results:
    - name: commit
  steps:
    - name: write
      image: alpine:3.20
      script: |
        #!/bin/sh
        echo -n TODO > $(results.commit.path)
YAML
cat > "$COURSE_DIR/03/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: git-metadata-
  namespace: tekton-lab
spec:
  taskRef:
    name: git-metadata
YAML
cat > "$COURSE_DIR/04/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: workspace-writer
  namespace: tekton-lab
spec:
  workspaces: [] # TODO source
  steps:
    - name: write
      image: alpine:3.20
      script: |
        #!/bin/sh
        echo app > TODO/app.txt
YAML
cat > "$COURSE_DIR/04/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: workspace-writer-
  namespace: tekton-lab
spec:
  taskRef:
    name: workspace-writer
  workspaces: []
YAML

cat > "$COURSE_DIR/05/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-pipeline
  namespace: tekton-lab
spec:
  workspaces:
    - name: source
  tasks:
    - name: write
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: write
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo artifact > $(workspaces.source.path)/artifact.txt
YAML
cat > "$COURSE_DIR/05/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: pvc-build-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: build-pipeline
  workspaces: [] # TODO volumeClaimTemplate 100Mi RWO
YAML

cat > "$COURSE_DIR/06/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ordered-build
  namespace: tekton-lab
spec:
  workspaces:
    - name: source
  tasks:
    - name: clone
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo source > $(workspaces.source.path)/app
      workspaces:
        - name: source
          workspace: source
    - name: test
      taskSpec:
        workspaces:
          - name: source
        steps:
          - name: test
            image: alpine:3.20
            script: |
              #!/bin/sh
              test -f $(workspaces.source.path)/app
      # TODO runAfter and workspace binding
    - name: package
      taskSpec:
        steps:
          - name: package
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo packaged
      # TODO runAfter test
YAML
cat > "$COURSE_DIR/06/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ordered-build-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: ordered-build
  workspaces:
    - name: source
      emptyDir: {}
YAML

cat > "$COURSE_DIR/07/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: parallel-tests
  namespace: tekton-lab
spec:
  tasks:
    - name: clone
      taskSpec:
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              #!/bin/sh
              sleep 1
              echo cloned
    - name: lint
      taskSpec:
        steps:
          - name: lint
            image: alpine:3.20
            script: |
              #!/bin/sh
              sleep 2
              echo lint
      # TODO runAfter clone
    - name: unit
      taskSpec:
        steps:
          - name: unit
            image: alpine:3.20
            script: |
              #!/bin/sh
              sleep 2
              echo unit
      # TODO runAfter clone
    - name: report
      taskSpec:
        steps:
          - name: report
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo report
      # TODO wait for lint and unit
YAML
cat > "$COURSE_DIR/07/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: parallel-tests-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: parallel-tests
YAML
touch "$COURSE_DIR/07/result.txt"

cat > "$COURSE_DIR/08/version-task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: version
  namespace: tekton-lab
spec:
  results:
    - name: version
  steps:
    - name: version
      image: alpine:3.20
      script: |
        #!/bin/sh
        echo -n 2.3.1 > $(results.version.path)
YAML
cat > "$COURSE_DIR/08/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release
  namespace: tekton-lab
spec:
  tasks:
    - name: version
      taskRef:
        name: version
    - name: publish
      params: [] # TODO release from version result
      taskSpec:
        params:
          - name: release
        steps:
          - name: publish
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo publishing $(params.release)
YAML
cat > "$COURSE_DIR/08/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: release-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: release
YAML

cat > "$COURSE_DIR/09/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: image-build
  namespace: tekton-lab
spec:
  results: [] # TODO expose image from build
  tasks:
    - name: build
      taskSpec:
        results:
          - name: image
        steps:
          - name: build
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo -n registry.example/app:1.0.0 > $(results.image.path)
YAML
cat > "$COURSE_DIR/09/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: image-build-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: image-build
YAML

cat > "$COURSE_DIR/10/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: conditional-deploy
  namespace: tekton-lab
spec:
  params:
    - name: environment
      type: string
  tasks:
    - name: deploy
      when: [] # TODO staging or prod
      taskSpec:
        steps:
          - name: deploy
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo deployed
YAML
for env in dev staging; do
  cat > "$COURSE_DIR/10/run-${env}.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: conditional-${env}-
  namespace: tekton-lab
spec:
  pipelineRef:
    name: conditional-deploy
  params:
    - name: environment
      value: ${env}
YAML
done

cat > "$COURSE_DIR/11/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q11-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q11-trigger
  namespace: tekton-lab
rules: [] # TODO PipelineRun create; TriggerBinding and TriggerTemplate get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q11-trigger
  namespace: tekton-lab
subjects: [] # TODO ServiceAccount q11-trigger
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q11-trigger
YAML
cat > "$COURSE_DIR/11/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: q11-ci-pipeline
  namespace: tekton-lab
spec:
  params:
    - name: git-repo-url
      type: string
    - name: git-commit-sha
      type: string
    - name: git-commit-message
      type: string
  tasks:
    - name: log-commit
      params:
        - name: repository-url
          value: $(params.git-repo-url)
        - name: commit-sha
          value: $(params.git-commit-sha)
        - name: commit-message
          value: $(params.git-commit-message)
      taskSpec:
        params:
          - name: repository-url
          - name: commit-sha
          - name: commit-message
        steps:
          - name: log
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "Repository: $(params.repository-url)"
              echo "Commit SHA: $(params.commit-sha)"
              echo "Message: $(params.commit-message)"
YAML
cat > "$COURSE_DIR/11/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q11-git-push
  namespace: tekton-lab
spec:
  params:
    - name: git-repo-url
      value: $(body.repository.url)
    - name: git-commit-sha
      value: $(body.head_commit.id)
    - name: git-commit-message
      value: $(body.head_commit.message)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q11-git-push
  namespace: tekton-lab
spec:
  params:
    - name: git-repo-url
    - name: git-commit-sha
    - name: git-commit-message
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q11-ci-pipeline-run-
        labels:
          lab.cnpe.io/question: q11
      spec:
        pipelineRef:
          name: q11-ci-pipeline
        params:
          - name: git-repo-url
            value: $(tt.params.git-repo-url)
          - name: git-commit-sha
            value: $(tt.params.git-commit-sha)
          - name: git-commit-message
            value: $(tt.params.git-commit-message)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q11-git-push
  namespace: tekton-lab
spec:
  serviceAccountName: q11-trigger
  triggers:
    - name: push
      bindings:
        - ref: q11-git-push
      template:
        ref: q11-git-push
YAML
cat > "$COURSE_DIR/11/payload.json" <<'JSON'
{
  "repository": {
    "url": "https://git.example/exam/commit-logger.git"
  },
  "head_commit": {
    "id": "abc123def456",
    "message": "Add trigger exercise"
  }
}
JSON
write_send_event_script 11 q11-git-push 18011

cat > "$COURSE_DIR/12/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: q12-webhook-build
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  tasks:
    - name: show-input
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
      taskSpec:
        params:
          - name: repository
          - name: revision
        steps:
          - name: show
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "repository=$(params.repository)"
              echo "revision=$(params.revision)"
YAML
cat > "$COURSE_DIR/12/triggertemplate.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q12-git-push
  namespace: tekton-lab
spec:
  params: [] # TODO repository and revision
  resourcetemplates: [] # TODO PipelineRun for q12-webhook-build with q12 label
YAML
cat > "$COURSE_DIR/12/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q12-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q12-trigger
  namespace: tekton-lab
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns"]
    verbs: ["create"]
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["triggerbindings", "triggertemplates"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q12-trigger
  namespace: tekton-lab
subjects:
  - kind: ServiceAccount
    name: q12-trigger
    namespace: tekton-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q12-trigger
YAML
cat > "$COURSE_DIR/12/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q12-git-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q12-git-push
  namespace: tekton-lab
spec:
  serviceAccountName: q12-trigger
  triggers:
    - name: push
      bindings:
        - ref: q12-git-push
      template:
        ref: q12-git-push
YAML
cat > "$COURSE_DIR/12/payload.json" <<'JSON'
{
  "after": "template123",
  "repository": {
    "clone_url": "https://git.example/exam/template-app.git"
  }
}
JSON
write_send_event_script 12 q12-git-push 18012

cat > "$COURSE_DIR/13/triggerbinding.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q13-git-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: TODO
    - name: revision
      value: TODO
YAML
cat > "$COURSE_DIR/13/payload.json" <<'JSON'
{
  "ref": "refs/heads/main",
  "after": "abc123def456",
  "repository": {
    "name": "portal",
    "clone_url": "https://git.example/teams/portal.git"
  }
}
JSON
cat > "$COURSE_DIR/13/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: q13-webhook-build
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  tasks:
    - name: log-commit
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
      taskSpec:
        params:
          - name: repository
          - name: revision
        steps:
          - name: log
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "$(params.repository)@$(params.revision)"
YAML
cat > "$COURSE_DIR/13/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q13-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q13-trigger
  namespace: tekton-lab
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns"]
    verbs: ["create"]
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["triggerbindings", "triggertemplates"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q13-trigger
  namespace: tekton-lab
subjects:
  - kind: ServiceAccount
    name: q13-trigger
    namespace: tekton-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q13-trigger
YAML
cat > "$COURSE_DIR/13/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q13-git-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q13-webhook-build-
        labels:
          lab.cnpe.io/question: q13
      spec:
        pipelineRef:
          name: q13-webhook-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q13-git-push
  namespace: tekton-lab
spec:
  serviceAccountName: q13-trigger
  triggers:
    - name: push
      bindings:
        - ref: q13-git-push
      template:
        ref: q13-git-push
YAML
write_send_event_script 13 q13-git-push 18013

cat > "$COURSE_DIR/14/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: q14-webhook-build
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  tasks:
    - name: show-input
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
      taskSpec:
        params:
          - name: repository
          - name: revision
        steps:
          - name: show
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "$(params.repository)@$(params.revision)"
YAML
cat > "$COURSE_DIR/14/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q14-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q14-trigger
  namespace: tekton-lab
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns"]
    verbs: ["create"]
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["triggerbindings", "triggertemplates"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q14-trigger
  namespace: tekton-lab
subjects:
  - kind: ServiceAccount
    name: q14-trigger
    namespace: tekton-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q14-trigger
YAML
cat > "$COURSE_DIR/14/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q14-git-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q14-git-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q14-webhook-build-
        labels:
          lab.cnpe.io/question: q14
      spec:
        pipelineRef:
          name: q14-webhook-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q14-git-push
  namespace: tekton-lab
spec:
  serviceAccountName: q14-trigger
  triggers:
    - name: push
      bindings:
        - ref: missing-binding
      template:
        ref: missing-template
YAML
cat > "$COURSE_DIR/14/payload.json" <<'JSON'
{"ref":"refs/heads/main","after":"abc123","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
write_send_event_script 14 q14-git-push 18014

for q in 15 18; do
  cp "$COURSE_DIR/14/pipeline.yaml" "$COURSE_DIR/$q/pipeline.yaml"
  cp "$COURSE_DIR/14/rbac.yaml" "$COURSE_DIR/$q/rbac.yaml"
  sed -i \
    -e "s/q14-webhook-build/q${q}-webhook-build/g" \
    -e "s/q14-trigger/q${q}-trigger/g" \
    "$COURSE_DIR/$q/pipeline.yaml" "$COURSE_DIR/$q/rbac.yaml"
done
cat > "$COURSE_DIR/15/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q15-branch-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q15-branch-push
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q15-branch-build-
        labels:
          lab.cnpe.io/question: q15
      spec:
        pipelineRef:
          name: q15-webhook-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q15-branch-push
  namespace: tekton-lab
spec:
  serviceAccountName: q15-trigger
  triggers:
    - name: all-branches
      interceptors: [] # TODO allow only refs/heads/main
      bindings:
        - ref: q15-branch-push
      template:
        ref: q15-branch-push
YAML
cat > "$COURSE_DIR/15/payload-main.json" <<'JSON'
{"ref":"refs/heads/main","after":"main123","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
cat > "$COURSE_DIR/15/payload-feature.json" <<'JSON'
{"ref":"refs/heads/feature","after":"feature123","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
write_send_event_script 15 q15-branch-push 18015

cat > "$COURSE_DIR/16/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: q16-payload-build
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
    - name: branch
  tasks:
    - name: show-input
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
        - name: branch
          value: $(params.branch)
      taskSpec:
        params:
          - name: repository
          - name: revision
          - name: branch
        steps:
          - name: show
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "repository=$(params.repository)"
              echo "revision=$(params.revision)"
              echo "branch=$(params.branch)"
YAML
cp "$COURSE_DIR/14/rbac.yaml" "$COURSE_DIR/16/rbac.yaml"
sed -i 's/q14-trigger/q16-trigger/g' "$COURSE_DIR/16/rbac.yaml"
cat > "$COURSE_DIR/16/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q16-payload-map
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: hard-coded
    - name: revision
      value: hard-coded
    - name: branch
      value: hard-coded
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q16-payload-map
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
    - name: branch
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q16-payload-build-
        labels:
          lab.cnpe.io/question: q16
      spec:
        pipelineRef:
          name: q16-payload-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
          - name: branch
            value: $(tt.params.branch)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q16-payload-map
  namespace: tekton-lab
spec:
  serviceAccountName: q16-trigger
  triggers:
    - name: push
      bindings:
        - ref: q16-payload-map
      template:
        ref: q16-payload-map
YAML
cat > "$COURSE_DIR/16/payload.json" <<'JSON'
{"ref":"refs/heads/release","after":"def456","repository":{"clone_url":"https://git.example/payments.git"}}
JSON
write_send_event_script 16 q16-payload-map 18016

cp "$COURSE_DIR/14/pipeline.yaml" "$COURSE_DIR/17/pipeline.yaml"
cp "$COURSE_DIR/14/rbac.yaml" "$COURSE_DIR/17/rbac.yaml"
sed -i \
  -e 's/q14-webhook-build/q17-webhook-build/g' \
  -e 's/q14-trigger/q17-trigger/g' \
  "$COURSE_DIR/17/pipeline.yaml" "$COURSE_DIR/17/rbac.yaml"
cat > "$COURSE_DIR/17/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q17-release-event
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q17-release-event
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: q17-release-build-
        labels:
          lab.cnpe.io/question: q17
      spec:
        pipelineRef:
          name: q17-webhook-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q17-release-events
  namespace: tekton-lab
spec:
  serviceAccountName: q17-trigger
  triggers: [] # TODO main/tag filters using q17-release-event
YAML
cat > "$COURSE_DIR/17/payload-main.json" <<'JSON'
{"ref":"refs/heads/main","after":"main456","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
cat > "$COURSE_DIR/17/payload-tag.json" <<'JSON'
{"ref":"refs/tags/v2.0.0","after":"tag456","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
cat > "$COURSE_DIR/17/payload-feature.json" <<'JSON'
{"ref":"refs/heads/feature","after":"feature456","repository":{"clone_url":"https://git.example/portal.git"}}
JSON
write_send_event_script 17 q17-release-events 18017

cat > "$COURSE_DIR/18/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q18-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q18-trigger
  namespace: tekton-lab
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q18-trigger
  namespace: tekton-lab
subjects:
  - kind: ServiceAccount
    name: q18-trigger
    namespace: tekton-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q18-trigger
YAML
cp "$COURSE_DIR/15/triggers.yaml" "$COURSE_DIR/18/triggers.yaml"
sed -i \
  -e 's/q15-branch-push/q18-branch-push/g' \
  -e 's/q15-branch-build/q18-branch-build/g' \
  -e 's/q15-webhook-build/q18-webhook-build/g' \
  -e 's/q15-trigger/q18-trigger/g' \
  -e 's/question: q15/question: q18/g' \
  -e 's/interceptors: \[\] # TODO allow only refs\/heads\/main/interceptors: []/' \
  "$COURSE_DIR/18/triggers.yaml"
cp "$COURSE_DIR/15/payload-main.json" "$COURSE_DIR/18/payload.json"
touch "$COURSE_DIR/18/rbac-check.txt"
write_send_event_script 18 q18-branch-push 18018

cp "$COURSE_DIR/14/pipeline.yaml" "$COURSE_DIR/19/pipeline.yaml"
sed -i 's/q14-webhook-build/q19-webhook-build/g' "$COURSE_DIR/19/pipeline.yaml"
cat > "$COURSE_DIR/19/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: q19-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: q19-trigger
  namespace: tekton-lab
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns"]
    verbs: ["create"]
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["triggerbindings", "triggertemplates"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: q19-trigger
  namespace: tekton-lab
subjects:
  - kind: ServiceAccount
    name: q19-trigger
    namespace: tekton-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: q19-trigger
YAML
cat > "$COURSE_DIR/19/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: q19-broken-hook
  namespace: tekton-lab
spec:
  params:
    - name: repository
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: q19-broken-hook
  namespace: tekton-lab
spec:
  params:
    - name: repository
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: repaired-hook-
        labels:
          lab.cnpe.io/question: q19
      spec:
        pipelineRef:
          name: q19-webhook-build
        params:
          - name: repository
            value: $(tt.params.repository)
          - name: revision
            value: $(tt.params.revision)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: q19-broken-hook
  namespace: tekton-lab
spec:
  serviceAccountName: missing-service-account
  triggers:
    - name: push
      bindings:
        - ref: missing-binding
      template:
        ref: q19-broken-hook
YAML
cat > "$COURSE_DIR/19/payload.json" <<'JSON'
{"ref":"refs/heads/main","after":"repair123","repository":{"clone_url":"https://git.example/repaired.git"}}
JSON
touch "$COURSE_DIR/19/report.md"
write_send_event_script 19 q19-broken-hook 18019

cat > "$COURSE_DIR/20/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: final-webhook-build
  namespace: tekton-lab
spec:
  params:
    - name: repository
    - name: revision
  tasks:
    - name: validate-input
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
      taskSpec:
        params:
          - name: repository
          - name: revision
        steps:
          - name: validate
            image: alpine:3.20
            script: |
              #!/bin/sh
              test -n "$(params.repository)"
              test -n "$(params.revision)"
              echo "$(params.repository)@$(params.revision)"
YAML
cat > "$COURSE_DIR/20/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: final-trigger
  namespace: tekton-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: final-trigger
  namespace: tekton-lab
rules: [] # TODO least privilege for EventListener
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: final-trigger
  namespace: tekton-lab
subjects: [] # TODO final-trigger
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: final-trigger
YAML
cat > "$COURSE_DIR/20/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: final-webhook
  namespace: tekton-lab
spec:
  params: [] # TODO repository and revision from body
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: final-webhook
  namespace: tekton-lab
spec:
  params: [] # TODO repository and revision
  resourcetemplates: [] # TODO PipelineRun final-webhook-build with q20 label
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: final-webhook
  namespace: tekton-lab
spec:
  serviceAccountName: final-trigger
  triggers:
    - name: main
      interceptors: [] # TODO CEL main branch
      bindings: [] # TODO final-webhook
      template:
        ref: final-webhook
YAML
cat > "$COURSE_DIR/20/payload-main.json" <<'JSON'
{"ref":"refs/heads/main","after":"final123","repository":{"clone_url":"https://git.example/final.git"}}
JSON
cat > "$COURSE_DIR/20/payload-feature.json" <<'JSON'
{"ref":"refs/heads/feature","after":"skip123","repository":{"clone_url":"https://git.example/final.git"}}
JSON
touch "$COURSE_DIR/20/run.log"
write_send_event_script 20 final-webhook 18020
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
echo "Tekton lab ready: $COURSE_DIR"
