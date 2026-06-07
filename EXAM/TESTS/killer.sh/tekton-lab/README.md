# Tekton Dedicated Lab

Laboratorio autonomo con 20 esercizi deterministici dedicati a Tekton
Pipelines.

## Avvio

Prerequisiti: Linux, `kubectl`, `curl` e un cluster Kubernetes.

```bash
chmod +x setup-tekton-lab.sh
./setup-tekton-lab.sh
```

Il setup installa Tekton Pipelines v1.9.0 LTS, Tekton Dashboard e crea gli
starter in `~/course-tekton`. Ogni directory contiene una risorsa incompleta o
guasta e un Run con cui verificare la correzione. Per aprire la GUI:

```bash
kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 30120:9097
```

Apri `http://127.0.0.1:30120`. Per rigenerare:
`LAB_FORCE=true ./setup-tekton-lab.sh`.
