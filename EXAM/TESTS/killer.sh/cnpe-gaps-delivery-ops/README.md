# CNPE Gaps Lab - Delivery and Operations

Laboratorio mirato alle aree GitOps/CD e Observability/Operations del
curriculum CNPE, che insieme pesano il 45% dell'esame.

Le tracce rinforzano in particolare configurazioni GitOps, dipendenze di
pipeline, progressive delivery, PromQL, LogQL, OpenTelemetry e incident
remediation.

## Avvio

Prerequisiti: Linux, `kubectl`, `curl`, `helm` e un cluster Kubernetes.

```bash
chmod +x setup-delivery-ops-lab.sh
./setup-delivery-ops-lab.sh
```

I file vengono creati in `~/course-delivery-ops`. Per rigenerarli:

```bash
LAB_FORCE=true ./setup-delivery-ops-lab.sh
```

Il setup installa Argo CD, Argo Rollouts, Flux, Tekton, Prometheus, Loki e
Jaeger. Per generare soltanto gli starter su un cluster che li contiene già:

```bash
INSTALL_TOOLS=false ./setup-delivery-ops-lab.sh
```
