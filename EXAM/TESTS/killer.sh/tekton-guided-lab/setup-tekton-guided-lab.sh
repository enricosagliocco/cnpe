#!/usr/bin/env bash
set -euo pipefail

TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-tekton-guided}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"

info() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }

ensure_cluster() {
  if kubectl cluster-info >/dev/null 2>&1; then
    return
  fi

  if command -v minikube >/dev/null 2>&1; then
    info "No reachable cluster; starting Minikube"
    minikube start --cpus=4 --memory=6144
    kubectl cluster-info >/dev/null 2>&1 ||
      die "Minikube started, but kubectl still cannot reach the cluster"
    return
  fi

  die "No reachable Kubernetes cluster and Minikube is not installed"
}

require_tekton() {
  kubectl get crd tasks.tekton.dev >/dev/null 2>&1 ||
    die "Tekton Pipelines is not installed; rerun with INSTALL_TOOLS=true"
  kubectl get crd pipelines.tekton.dev >/dev/null 2>&1 ||
    die "Tekton Pipeline CRDs are missing"
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$INSTALL_TOOLS" = "true" ]; then
  info "Installing Tekton Pipelines ${TEKTON_VERSION}"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml"
  kubectl -n tekton-pipelines rollout status \
    deploy/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status \
    deploy/tekton-pipelines-webhook --timeout=300s
  kubectl -n tekton-pipelines patch configmap feature-flags --type merge \
    -p '{"data":{"enable-api-fields":"beta"}}' >/dev/null

  info "Installing Tekton Dashboard"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/dashboard/latest/release.yaml"
  kubectl -n tekton-pipelines rollout status \
    deploy/tekton-dashboard --timeout=300s
fi

require_tekton

kubectl create namespace tekton-guided --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 10); do
  mkdir -p "$COURSE_DIR/$n"
done

cat > "$COURSE_DIR/README.md" <<'MD'
# Metodo di lavoro

Per ogni lezione:

1. leggi `README.md`;
2. applica `example.yaml` e osserva la struttura;
3. completa soltanto i `TODO` nello starter;
4. applica prima Task o Pipeline;
5. applica `run.yaml`;
6. attendi la condizione terminale;
7. controlla status e log.

Comandi utili:

```bash
kubectl -n tekton-guided get tasks,pipelines,taskruns,pipelineruns
kubectl -n tekton-guided wait --for=condition=Succeeded taskrun/<nome> --timeout=120s
kubectl -n tekton-guided wait --for=condition=Succeeded pipelinerun/<nome> --timeout=120s
kubectl -n tekton-guided logs -l tekton.dev/taskRun=<nome> --all-containers
kubectl -n tekton-guided logs -l tekton.dev/pipelineRun=<nome> --all-containers
```

I Run usano nomi fissi. Prima di ripetere un test, elimina il Run precedente:

```bash
kubectl -n tekton-guided delete -f run.yaml --ignore-not-found
```
MD

cat > "$COURSE_DIR/01/README.md" <<'MD'
# 01 - Task e TaskRun

Un `Task` descrive il lavoro riutilizzabile. Un `TaskRun` ne crea
un'esecuzione.

Osserva in `example.yaml`:

- `Task.spec.steps`;
- immagine e script dello step;
- `TaskRun.spec.taskRef`.

Completa `task.yaml` con uno step `hello` che usa `alpine:3.20` e stampa
esattamente `hello tekton`. Applica poi `task.yaml` e `run.yaml`.
MD
cat > "$COURSE_DIR/01/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: example-hello
  namespace: tekton-guided
spec:
  steps:
    - name: hello
      image: alpine:3.20
      script: |
        echo "hello from example"
---
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: example-hello-run
  namespace: tekton-guided
spec:
  taskRef:
    name: example-hello
YAML
cat > "$COURSE_DIR/01/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: guided-hello
  namespace: tekton-guided
spec:
  steps: [] # TODO hello, alpine:3.20, echo "hello tekton"
YAML
cat > "$COURSE_DIR/01/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: guided-hello-run
  namespace: tekton-guided
spec:
  taskRef:
    name: guided-hello
YAML

cat > "$COURSE_DIR/02/README.md" <<'MD'
# 02 - Parametri

I parametri separano la logica del Task dai valori del Run.

Pattern:

```yaml
params:
  - name: who
    type: string
    default: platform
```

Nello script usa `$(params.who)`. Completa lo starter e passa
`who: cnpe` dal TaskRun. Il log atteso e `hello cnpe`.
MD
cat > "$COURSE_DIR/02/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: example-params, namespace: tekton-guided}
spec:
  params:
    - {name: message, type: string, default: example}
  steps:
    - name: print
      image: alpine:3.20
      script: 'echo "$(params.message)"'
YAML
cat > "$COURSE_DIR/02/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: guided-greet, namespace: tekton-guided}
spec:
  params: [] # TODO who string, default platform
  steps:
    - name: greet
      image: alpine:3.20
      script: 'echo "hello TODO"' # TODO use the parameter
YAML
cat > "$COURSE_DIR/02/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {name: guided-greet-run, namespace: tekton-guided}
spec:
  taskRef: {name: guided-greet}
  params: [] # TODO who=cnpe
YAML

cat > "$COURSE_DIR/03/README.md" <<'MD'
# 03 - Step sequenziali e workspace

Gli step di un Task vengono eseguiti in ordine nello stesso Pod. Un workspace
fornisce uno spazio condiviso.

Completa `task.yaml`:

1. dichiara il workspace `source`;
2. `write` crea `$(workspaces.source.path)/artifact.txt`;
3. `verify` controlla il file e stampa `artifact ready`.

Il TaskRun contiene gia il binding `emptyDir`.
MD
cat > "$COURSE_DIR/03/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: example-workspace, namespace: tekton-guided}
spec:
  workspaces: [{name: data}]
  steps:
    - name: write
      image: alpine:3.20
      script: 'echo example > $(workspaces.data.path)/value'
    - name: read
      image: alpine:3.20
      script: 'cat $(workspaces.data.path)/value'
YAML
cat > "$COURSE_DIR/03/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: guided-workspace, namespace: tekton-guided}
spec:
  workspaces: [] # TODO source
  steps:
    - name: write
      image: alpine:3.20
      script: 'echo artifact > TODO/artifact.txt'
    - name: verify
      image: alpine:3.20
      script: 'test -f TODO/artifact.txt && echo "artifact ready"'
YAML
cat > "$COURSE_DIR/03/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {name: guided-workspace-run, namespace: tekton-guided}
spec:
  taskRef: {name: guided-workspace}
  workspaces:
    - name: source
      emptyDir: {}
YAML

cat > "$COURSE_DIR/04/README.md" <<'MD'
# 04 - Results

Un Task scrive un result nel file `$(results.<nome>.path)`. Il valore compare
nello status del TaskRun.

Completa lo step per scrivere senza newline `1.2.3` nel result `version`.

Verifica:

```bash
kubectl -n tekton-guided get taskrun guided-result-run \
  -o jsonpath='{.status.results[?(@.name=="version")].value}{"\n"}'
```
MD
cat > "$COURSE_DIR/04/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: example-result, namespace: tekton-guided}
spec:
  results: [{name: value}]
  steps:
    - name: produce
      image: alpine:3.20
      script: 'printf example > $(results.value.path)'
YAML
cat > "$COURSE_DIR/04/task.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: guided-result, namespace: tekton-guided}
spec:
  results:
    - name: version
      description: Version produced by the Task
  steps:
    - name: produce
      image: alpine:3.20
      script: 'echo TODO' # TODO printf 1.2.3 to the result path
YAML
cat > "$COURSE_DIR/04/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata: {name: guided-result-run, namespace: tekton-guided}
spec:
  taskRef: {name: guided-result}
YAML

cat > "$COURSE_DIR/05/README.md" <<'MD'
# 05 - Prima Pipeline

Una Pipeline orchestra Task inline o referenziati. Il PipelineRun avvia la
Pipeline.

Completa `pipeline.yaml` con due Task inline:

1. `build` stampa `build`;
2. `test` stampa `test` e usa `runAfter: [build]`.

Verifica dalla Dashboard o dallo status che `test` inizi dopo `build`.
MD
cat > "$COURSE_DIR/05/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: example-pipeline, namespace: tekton-guided}
spec:
  tasks:
    - name: first
      taskSpec:
        steps:
          - {name: first, image: alpine:3.20, script: 'echo first'}
    - name: second
      runAfter: [first]
      taskSpec:
        steps:
          - {name: second, image: alpine:3.20, script: 'echo second'}
YAML
cat > "$COURSE_DIR/05/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-build, namespace: tekton-guided}
spec:
  tasks: [] # TODO build, then test
YAML
cat > "$COURSE_DIR/05/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-build-run, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-build}
YAML

cat > "$COURSE_DIR/06/README.md" <<'MD'
# 06 - Parallelismo e dipendenze

Task senza dipendenze reciproche possono partire in parallelo.

Completa la Pipeline:

1. `lint` e `unit` devono usare `runAfter: [clone]`;
2. `report` deve usare `runAfter: [lint, unit]`.

Gli script contengono sleep per rendere visibile la sovrapposizione nella
Dashboard.
MD
cat > "$COURSE_DIR/06/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: example-parallel, namespace: tekton-guided}
spec:
  tasks:
    - name: left
      taskSpec:
        steps: [{name: left, image: alpine:3.20, script: 'sleep 2; echo left'}]
    - name: right
      taskSpec:
        steps: [{name: right, image: alpine:3.20, script: 'sleep 2; echo right'}]
YAML
cat > "$COURSE_DIR/06/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-parallel, namespace: tekton-guided}
spec:
  tasks:
    - name: clone
      taskSpec:
        steps: [{name: clone, image: alpine:3.20, script: 'echo cloned'}]
    - name: lint
      taskSpec:
        steps: [{name: lint, image: alpine:3.20, script: 'sleep 3; echo lint'}]
      # TODO runAfter clone
    - name: unit
      taskSpec:
        steps: [{name: unit, image: alpine:3.20, script: 'sleep 3; echo unit'}]
      # TODO runAfter clone
    - name: report
      taskSpec:
        steps: [{name: report, image: alpine:3.20, script: 'echo report'}]
      # TODO runAfter lint and unit
YAML
cat > "$COURSE_DIR/06/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-parallel-run, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-parallel}
YAML

cat > "$COURSE_DIR/07/README.md" <<'MD'
# 07 - Propagare un result

Un Task successivo puo consumare:

```text
$(tasks.<task>.results.<result>)
```

Completa il parametro `version` del Task `publish` usando il result prodotto
da `calculate`. Il log atteso e `publishing 2.4.0`.
MD
cat > "$COURSE_DIR/07/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: example-result-flow, namespace: tekton-guided}
spec:
  tasks:
    - name: produce
      taskSpec:
        results: [{name: value}]
        steps:
          - {name: produce, image: alpine:3.20, script: 'printf example > $(results.value.path)'}
    - name: consume
      params:
        - {name: value, value: $(tasks.produce.results.value)}
      taskSpec:
        params: [{name: value}]
        steps:
          - {name: consume, image: alpine:3.20, script: 'echo "$(params.value)"'}
YAML
cat > "$COURSE_DIR/07/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-release, namespace: tekton-guided}
spec:
  tasks:
    - name: calculate
      taskSpec:
        results: [{name: version}]
        steps:
          - name: calculate
            image: alpine:3.20
            script: 'printf 2.4.0 > $(results.version.path)'
    - name: publish
      params: [] # TODO version from calculate result
      taskSpec:
        params: [{name: version}]
        steps:
          - name: publish
            image: alpine:3.20
            script: 'echo "publishing $(params.version)"'
YAML
cat > "$COURSE_DIR/07/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-release-run, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-release}
YAML

cat > "$COURSE_DIR/08/README.md" <<'MD'
# 08 - Esecuzione condizionale

Una `when` expression decide se eseguire un PipelineTask.

Completa `deploy` affinche venga eseguito soltanto quando `environment` e
`staging` oppure `prod`.

Esegui prima `run-dev.yaml`: `deploy` deve essere skipped. Esegui poi
`run-staging.yaml`: il log deve contenere `deploying staging`.
MD
cat > "$COURSE_DIR/08/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: example-when, namespace: tekton-guided}
spec:
  params: [{name: enabled, type: string}]
  tasks:
    - name: conditional
      when:
        - {input: $(params.enabled), operator: in, values: ["true"]}
      taskSpec:
        steps:
          - {name: run, image: alpine:3.20, script: 'echo enabled'}
YAML
cat > "$COURSE_DIR/08/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-deploy, namespace: tekton-guided}
spec:
  params:
    - {name: environment, type: string}
  tasks:
    - name: deploy
      when: [] # TODO environment in staging, prod
      taskSpec:
        params: [{name: environment}]
        steps:
          - name: deploy
            image: alpine:3.20
            script: 'echo "deploying $(params.environment)"'
      params:
        - {name: environment, value: $(params.environment)}
YAML
cat > "$COURSE_DIR/08/run-dev.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-deploy-dev, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-deploy}
  params: [{name: environment, value: dev}]
YAML
cat > "$COURSE_DIR/08/run-staging.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-deploy-staging, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-deploy}
  params: [{name: environment, value: staging}]
YAML

cat > "$COURSE_DIR/09/README.md" <<'MD'
# 09 - Finally

I Task in `finally` vengono valutati anche quando un Task normale fallisce.

Completa la sezione `finally` con un Task `notify` che stampi:

```text
pipeline status=$(tasks.status)
```

Il PipelineRun deve risultare fallito per `build`, ma `notify` deve essere
eseguito.
MD
cat > "$COURSE_DIR/09/example.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: example-finally, namespace: tekton-guided}
spec:
  tasks:
    - name: work
      taskSpec:
        steps: [{name: work, image: alpine:3.20, script: 'echo work'}]
  finally:
    - name: cleanup
      taskSpec:
        steps: [{name: cleanup, image: alpine:3.20, script: 'echo cleanup'}]
YAML
cat > "$COURSE_DIR/09/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-finally, namespace: tekton-guided}
spec:
  tasks:
    - name: build
      taskSpec:
        steps:
          - name: build
            image: alpine:3.20
            script: 'echo "build failed"; exit 1'
  finally: [] # TODO notify with $(tasks.status)
YAML
cat > "$COURSE_DIR/09/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-finally-run, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-finally}
YAML

cat > "$COURSE_DIR/10/README.md" <<'MD'
# 10 - Composizione finale e troubleshooting

Il bundle contiene quattro problemi:

1. il Task `test` non dipende da `clone`;
2. `test` non riceve il workspace;
3. `publish` non usa il result `image`;
4. il PipelineRun usa un nome parametro errato.

Correggi i file senza rinominare le risorse. Il flusso finale deve essere:

```text
clone -> test -> build -> publish
```

`build` deve produrre il result `image` con valore
`registry.example/guided:1.0`, e `publish` deve stamparlo. Salva diagnosi,
modifiche e comandi di verifica in `report.md`.
MD
cat > "$COURSE_DIR/10/example.yaml" <<'YAML'
# Rileggi gli esempi delle lezioni 03, 05 e 07.
YAML
cat > "$COURSE_DIR/10/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: guided-final, namespace: tekton-guided}
spec:
  params:
    - {name: repository, type: string}
  workspaces:
    - name: source
  tasks:
    - name: clone
      params:
        - {name: repository, value: $(params.repository)}
      taskSpec:
        params: [{name: repository}]
        workspaces: [{name: source}]
        steps:
          - name: clone
            image: alpine:3.20
            script: |
              echo "$(params.repository)" > $(workspaces.source.path)/repo
      workspaces:
        - {name: source, workspace: source}
    - name: test
      taskSpec:
        workspaces: [{name: source}]
        steps:
          - name: test
            image: alpine:3.20
            script: 'test -s $(workspaces.source.path)/repo'
      # TODO runAfter clone and bind source
    - name: build
      runAfter: [test]
      taskSpec:
        results: [{name: image}]
        steps:
          - name: build
            image: alpine:3.20
            script: 'printf registry.example/guided:1.0 > $(results.image.path)'
    - name: publish
      runAfter: [build]
      params: [] # TODO image from build
      taskSpec:
        params: [{name: image}]
        steps:
          - name: publish
            image: alpine:3.20
            script: 'echo "publishing $(params.image)"'
YAML
cat > "$COURSE_DIR/10/run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: guided-final-run, namespace: tekton-guided}
spec:
  pipelineRef: {name: guided-final}
  params:
    - {name: repo, value: https://example.invalid/guided.git} # TODO correct name
  workspaces:
    - name: source
      emptyDir: {}
YAML
touch "$COURSE_DIR/10/report.md"

touch "$COURSE_DIR/.initialized"
ok "Tekton guided lab ready: $COURSE_DIR"
echo "Lessons: ${COURSE_DIR}/01 ... ${COURSE_DIR}/10"
echo "Dashboard: kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 30120:9097"
