# Tekton Dedicated Lab

Laboratorio autonomo con 20 esercizi deterministici dedicati a Tekton
Pipelines.

## Avvio

Prerequisiti: Linux, `kubectl`, `curl` e un cluster Kubernetes.

```bash
chmod +x setup-tekton-lab.sh
./setup-tekton-lab.sh
```

Il setup installa Tekton Pipelines v1.9.0 LTS e crea gli starter in
`~/course-tekton`. Per rigenerare: `LAB_FORCE=true ./setup-tekton-lab.sh`.
