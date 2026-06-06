#!/usr/bin/env bash
set -euo pipefail

TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-tekton}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  echo "$COURSE_DIR already initialized; use LAB_FORCE=true"; exit 1
fi

kubectl apply -f "https://infra.tekton.dev/releases/pipeline/previous/${TEKTON_VERSION}/release.yaml"
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl create ns tekton-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null
mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

cat > "$COURSE_DIR/01/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: greet, namespace: tekton-lab}
spec:
  params: [] # TODO name string default platform
  steps:
    - name: greet
      image: alpine:3.20
      script: 'echo "hello TODO"'
YAML
cat > "$COURSE_DIR/01/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: greet-, namespace: tekton-lab}
spec: {taskRef: {name: greet}, params: []} # TODO name=cnpe
YAML

cat > "$COURSE_DIR/02/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: sequential-build, namespace: tekton-lab}
spec:
  workspaces: [{name: output}]
  steps: [] # TODO prepare, build, verify
YAML
cat > "$COURSE_DIR/03/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: git-metadata, namespace: tekton-lab}
spec:
  results: [{name: commit}]
  steps:
    - name: write
      image: alpine:3.20
      script: 'echo -n TODO > $(results.commit.path)'
YAML
cat > "$COURSE_DIR/04/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: workspace-writer, namespace: tekton-lab}
spec:
  workspaces: [] # TODO source
  steps:
    - name: write
      image: alpine:3.20
      script: 'echo app > TODO/app.txt'
YAML
cat > "$COURSE_DIR/04/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: workspace-writer-, namespace: tekton-lab}
spec: {taskRef: {name: workspace-writer}, workspaces: []}
YAML

cat > "$COURSE_DIR/base-pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: build-pipeline, namespace: tekton-lab}
spec:
  params:
    - {name: environment, type: string, default: dev}
  workspaces: [{name: source}]
  tasks:
    - name: clone
      taskSpec:
        workspaces: [{name: source}]
        results: [{name: commit}]
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              echo source > $(workspaces.source.path)/app
              echo -n 0123456789abcdef > $(results.commit.path)
    - name: lint
      taskSpec:
        steps: [{name: lint, image: alpine:3.20, script: "echo lint"}]
    - name: unit
      taskSpec:
        steps: [{name: unit, image: alpine:3.20, script: "echo unit"}]
    - name: build
      taskSpec:
        results: [{name: image}]
        steps:
          - name: build
            image: alpine:3.20
            script: 'echo -n registry.example/app:1.0.0 > $(results.image.path)'
YAML
for n in 05 06 07 08 09 10 11 12 13 14 15 18 20; do
  cp "$COURSE_DIR/base-pipeline.yaml" "$COURSE_DIR/$n/pipeline.yaml"
done
cat > "$COURSE_DIR/05/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: pvc-build-, namespace: tekton-lab}
spec:
  pipelineRef: {name: build-pipeline}
  workspaces: [] # TODO volumeClaimTemplate 100Mi RWO
YAML
touch "$COURSE_DIR/07/result.txt"

cat > "$COURSE_DIR/08/version-task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: version, namespace: tekton-lab}
spec:
  results: [{name: version}]
  steps: [{name: version, image: alpine:3.20, script: 'echo -n 2.3.1 > $(results.version.path)'}]
YAML
cat > "$COURSE_DIR/15/credentials.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata: {name: signing-credentials, namespace: tekton-lab}
stringData: {key: training-key}
YAML
cat > "$COURSE_DIR/16/security.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata: {name: registry-credentials, namespace: tekton-lab}
stringData: {config.json: '{"auths":{}}'}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: pipeline, namespace: tekton-lab}
YAML
cat > "$COURSE_DIR/17/rbac.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: pipeline-configmaps, namespace: tekton-lab}
rules: [] # TODO
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: pipeline-configmaps, namespace: tekton-lab}
subjects: [] # TODO
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: pipeline-configmaps}
YAML
cat > "$COURSE_DIR/18/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: secure-build, namespace: tekton-lab}
spec:
  workspaces: [{name: source}]
  tasks: [] # TODO clone, test, sbom, scan, publish
  finally: [] # TODO report aggregate status
YAML
cat > "$COURSE_DIR/19/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: broken-, namespace: tekton-lab}
spec:
  pipelineRef: {name: missing-pipeline}
  params: [{name: wrong-param, value: broken}]
  workspaces: []
YAML
touch "$COURSE_DIR/19/report.md" "$COURSE_DIR/20/run.log"
rm "$COURSE_DIR/base-pipeline.yaml"
touch "$COURSE_DIR/.initialized"
echo "Tekton lab ready: $COURSE_DIR"
