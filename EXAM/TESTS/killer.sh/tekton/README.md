# CNPE Tekton Mini Lab

Mini lab Tekton con Gitea esterno.

## Avvio

```bash
chmod +x setup-tekton-mini.sh
./setup-tekton-mini.sh
```

## Gitea

Lo script usa:

```bash
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"
```

## Cleanup

```bash
./setup-tekton-mini.sh --cleanup
```

## Focus

Task, Pipeline, PipelineRun, Workspace, Params, Results, RBAC, TriggerBinding, TriggerTemplate, EventListener.
