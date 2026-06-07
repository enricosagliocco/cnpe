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
kubectl apply -f "https://infra.tekton.dev/releases/dashboard/latest/release.yaml"
kubectl -n tekton-pipelines rollout status deploy/tekton-dashboard --timeout=300s
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
cat > "$COURSE_DIR/02/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: sequential-build-, namespace: tekton-lab}
spec:
  taskRef: {name: sequential-build}
  workspaces: [{name: output, emptyDir: {}}]
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
cat > "$COURSE_DIR/03/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: git-metadata-, namespace: tekton-lab}
spec: {taskRef: {name: git-metadata}}
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

cat > "$COURSE_DIR/05/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: build-pipeline, namespace: tekton-lab}
spec:
  workspaces: [{name: source}]
  tasks:
    - name: write
      taskSpec:
        workspaces: [{name: source}]
        steps:
          - name: write
            image: alpine:3.20
            script: 'echo artifact > $(workspaces.source.path)/artifact.txt'
YAML
cat > "$COURSE_DIR/05/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: pvc-build-, namespace: tekton-lab}
spec:
  pipelineRef: {name: build-pipeline}
  workspaces: [] # TODO volumeClaimTemplate 100Mi RWO
YAML

cat > "$COURSE_DIR/06/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: ordered-build, namespace: tekton-lab}
spec:
  workspaces: [{name: source}]
  tasks:
    - name: clone
      taskSpec:
        workspaces: [{name: source}]
        steps: [{name: clone, image: alpine:3.20, script: "echo source > $(workspaces.source.path)/app"}]
      workspaces: [{name: source, workspace: source}]
    - name: test
      taskSpec:
        workspaces: [{name: source}]
        steps: [{name: test, image: alpine:3.20, script: "test -f $(workspaces.source.path)/app"}]
      # TODO runAfter and workspace binding
    - name: package
      taskSpec:
        steps: [{name: package, image: alpine:3.20, script: "echo packaged"}]
      # TODO runAfter test
YAML
cat > "$COURSE_DIR/06/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: ordered-build-, namespace: tekton-lab}
spec:
  pipelineRef: {name: ordered-build}
  workspaces: [{name: source, emptyDir: {}}]
YAML

cat > "$COURSE_DIR/07/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: parallel-tests, namespace: tekton-lab}
spec:
  tasks:
    - name: clone
      taskSpec:
        steps: [{name: clone, image: alpine:3.20, script: "sleep 1; echo cloned"}]
    - name: lint
      taskSpec:
        steps: [{name: lint, image: alpine:3.20, script: "sleep 2; echo lint"}]
      # TODO runAfter clone
    - name: unit
      taskSpec:
        steps: [{name: unit, image: alpine:3.20, script: "sleep 2; echo unit"}]
      # TODO runAfter clone
    - name: report
      taskSpec:
        steps: [{name: report, image: alpine:3.20, script: "echo report"}]
      # TODO wait for lint and unit
YAML
cat > "$COURSE_DIR/07/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: parallel-tests-, namespace: tekton-lab}
spec: {pipelineRef: {name: parallel-tests}}
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
cat > "$COURSE_DIR/08/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: release, namespace: tekton-lab}
spec:
  tasks:
    - name: version
      taskRef: {name: version}
    - name: publish
      params: [] # TODO release from version result
      taskSpec:
        params: [{name: release}]
        steps: [{name: publish, image: alpine:3.20, script: "echo publishing $(params.release)"}]
YAML
cat > "$COURSE_DIR/08/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: release-, namespace: tekton-lab}
spec: {pipelineRef: {name: release}}
YAML

cat > "$COURSE_DIR/09/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: image-build, namespace: tekton-lab}
spec:
  results: [] # TODO expose image from build
  tasks:
    - name: build
      taskSpec:
        results: [{name: image}]
        steps:
          - name: build
            image: alpine:3.20
            script: 'echo -n registry.example/app:1.0.0 > $(results.image.path)'
YAML
cat > "$COURSE_DIR/09/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: image-build-, namespace: tekton-lab}
spec: {pipelineRef: {name: image-build}}
YAML

cat > "$COURSE_DIR/10/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: conditional-deploy, namespace: tekton-lab}
spec:
  params: [{name: environment, type: string}]
  tasks:
    - name: deploy
      when: [] # TODO staging or prod
      taskSpec:
        steps: [{name: deploy, image: alpine:3.20, script: "echo deployed"}]
YAML
for env in dev staging; do
  cat > "$COURSE_DIR/10/run-${env}.yaml" <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: conditional-${env}-, namespace: tekton-lab}
spec:
  pipelineRef: {name: conditional-deploy}
  params: [{name: environment, value: ${env}}]
YAML
done

cat > "$COURSE_DIR/11/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: failing-build, namespace: tekton-lab}
spec:
  tasks:
    - name: build
      taskSpec:
        steps: [{name: fail, image: alpine:3.20, script: "exit 1"}]
  finally: [] # TODO notify with $(tasks.status)
YAML
cat > "$COURSE_DIR/11/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: failing-build-, namespace: tekton-lab}
spec: {pipelineRef: {name: failing-build}}
YAML

cat > "$COURSE_DIR/12/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: retry-build, namespace: tekton-lab}
spec:
  tasks:
    - name: unstable
      retries: 0 # TODO
      taskSpec:
        steps:
          - name: unstable
            image: alpine:3.20
            script: |
              echo retry=$(context.task.retry-count)
              test "$(context.task.retry-count)" -ge 2
YAML
cat > "$COURSE_DIR/12/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: retry-build-, namespace: tekton-lab}
spec: {pipelineRef: {name: retry-build}}
YAML

cat > "$COURSE_DIR/13/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: timeout-build, namespace: tekton-lab}
spec:
  tasks:
    - name: slow
      timeout: 30s # TODO 5s
      taskSpec:
        steps: [{name: slow, image: alpine:3.20, script: "sleep 20"}]
YAML
cat > "$COURSE_DIR/13/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: timeout-build-, namespace: tekton-lab}
spec:
  pipelineRef: {name: timeout-build}
  timeouts: {pipeline: 2m, tasks: 2m} # TODO tasks 30s
YAML

cat > "$COURSE_DIR/14/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: matrix-tests, namespace: tekton-lab}
spec:
  tasks:
    - name: test
      matrix: {} # TODO python x os
      params:
        - {name: python, value: ["$(params.python)"]}
        - {name: os, value: ["$(params.os)"]}
      taskSpec:
        params: [{name: python}, {name: os}]
        steps: [{name: test, image: alpine:3.20, script: "echo $(params.python)-$(params.os)"}]
YAML
cat > "$COURSE_DIR/14/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: matrix-tests-, namespace: tekton-lab}
spec: {pipelineRef: {name: matrix-tests}}
YAML

cat > "$COURSE_DIR/15/credentials.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata: {name: signing-credentials, namespace: tekton-lab}
stringData: {key: training-key}
YAML
cat > "$COURSE_DIR/15/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: sign, namespace: tekton-lab}
spec:
  workspaces: [{name: credentials, optional: true}]
  steps:
    - name: sign
      image: alpine:3.20
      script: 'echo signed' # TODO run only when credentials is bound
YAML
cat > "$COURSE_DIR/15/run-unbound.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: sign-unbound-, namespace: tekton-lab}
spec: {taskRef: {name: sign}}
YAML
cat > "$COURSE_DIR/15/run-bound.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: sign-bound-, namespace: tekton-lab}
spec:
  taskRef: {name: sign}
  workspaces:
    - name: credentials
      secret: {secretName: signing-credentials}
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
cat > "$COURSE_DIR/16/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: read-docker-config, namespace: tekton-lab}
spec:
  workspaces: [{name: dockerconfig}]
  steps:
    - name: read
      image: alpine:3.20
      script: 'test -f $(workspaces.dockerconfig.path)/config.json'
YAML
cat > "$COURSE_DIR/16/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: read-docker-config-, namespace: tekton-lab}
spec:
  serviceAccountName: pipeline
  taskRef: {name: read-docker-config}
  workspaces: [] # TODO read-only Secret binding
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
cat > "$COURSE_DIR/17/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: create-build-metadata, namespace: tekton-lab}
spec:
  steps:
    - name: create
      image: bitnami/kubectl:1.31
      script: kubectl create configmap build-metadata --from-literal=status=ready
YAML
cat > "$COURSE_DIR/17/taskrun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {generateName: create-build-metadata-, namespace: tekton-lab}
spec:
  serviceAccountName: pipeline
  taskRef: {name: create-build-metadata}
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
cat > "$COURSE_DIR/20/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: final-build, namespace: tekton-lab}
spec:
  params: [] # TODO repo, revision, image
  workspaces: [{name: source}]
  tasks: [] # TODO clone, parallel lint/unit, build, scan, publish
  finally: [] # TODO cleanup
  results: [] # TODO commit and image
YAML
cat > "$COURSE_DIR/20/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: final-build-, namespace: tekton-lab}
spec:
  pipelineRef: {name: final-build}
  params:
    - {name: repo, value: https://example.invalid/app.git}
    - {name: revision, value: main}
    - {name: image, value: registry.example/app:2.0.0}
  workspaces: [] # TODO PVC
YAML
touch "$COURSE_DIR/.initialized"
echo "Tekton lab ready: $COURSE_DIR"
