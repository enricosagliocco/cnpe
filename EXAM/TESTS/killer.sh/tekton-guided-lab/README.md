# Tekton Guided Pipelines Lab

Percorso guidato di 10 lezioni per imparare Task, TaskRun, Pipeline e
PipelineRun con Tekton Pipelines `v1`.

## Avvio

Prerequisiti:

- Linux;
- `kubectl`;
- un cluster Kubernetes raggiungibile oppure Minikube;
- accesso Internet durante l'installazione.

```bash
chmod +x setup-tekton-guided-lab.sh
./setup-tekton-guided-lab.sh
```

Il corso viene creato in `~/course-tekton-guided`. Ogni lezione contiene:

- `README.md`: concetto e procedura;
- `example.yaml`: esempio funzionante;
- `task.yaml` o `pipeline.yaml`: starter con `TODO`;
- `run.yaml`: TaskRun o PipelineRun per la verifica.

Per rigenerare i file:

```bash
LAB_FORCE=true ./setup-tekton-guided-lab.sh
```

Per usare un'installazione Tekton gia presente:

```bash
INSTALL_TOOLS=false ./setup-tekton-guided-lab.sh
```

## Dashboard

```bash
kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 30120:9097
```

Apri `http://127.0.0.1:30120`.

## Riferimenti ufficiali

- [Tasks](https://tekton.dev/docs/pipelines/tasks/)
- [TaskRuns](https://tekton.dev/docs/pipelines/taskruns/)
- [Pipelines](https://tekton.dev/docs/pipelines/pipelines/)
- [PipelineRuns](https://tekton.dev/docs/pipelines/pipelineruns/)
- [Workspaces](https://tekton.dev/docs/pipelines/workspaces/)
- [Variables](https://tekton.dev/docs/pipelines/variables/)
