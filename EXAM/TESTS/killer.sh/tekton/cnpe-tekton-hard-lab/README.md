# CNPE Hard Lab — Tekton

Lab Tekton più difficile, ispirato allo stile performance-based del simulatore CNPE.

## Avvio

```bash
chmod +x setup-tekton-hard.sh
./setup-tekton-hard.sh
```

## Gitea

Default usati dallo script:

```bash
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"
```

Repository creato:

```text
organization/tekton-hard-app
```

Branch creati:

```text
main
release
```

## Cleanup

```bash
./setup-tekton-hard.sh --cleanup
```

## Namespace

```text
builder
apps-dev
apps-prod
tekton-pipelines
```

## File nel cluster

```text
/course/tekton-hard/00-rbac.yaml
/course/tekton-hard/01-cross-namespace-rbac-broken.yaml
/course/tekton-hard/10-tasks-broken.yaml
/course/tekton-hard/20-pipeline-broken.yaml
/course/tekton-hard/30-pipelinerun-dev-broken.yaml
/course/tekton-hard/31-pipelinerun-prod-broken.yaml
/course/tekton-hard/40-triggers-broken.yaml
/course/tekton-hard/README.txt
```

## Focus

- Task
- Pipeline
- PipelineRun
- Workspaces
- Results
- params
- parallelismo tra task
- Kustomize render dentro Tekton
- RBAC cross-namespace
- TriggerBinding
- TriggerTemplate
- EventListener
- CEL interceptor
- webhook Gitea
