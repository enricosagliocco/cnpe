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

## Accesso GUI

Il setup installa anche Argo Rollouts Dashboard, Tekton Dashboard e Grafana. I
comandi di port-forward, gli URL e le credenziali per Argo CD, Rollouts,
Tekton, Prometheus, Grafana e Jaeger sono riportati all'inizio di
`domande.md`.

Il setup crea workload running per drift GitOps, discovery Prometheus,
incidenti LogQL, OTLP e trace correlation. Ogni soluzione deve essere
applicata e verificata nel cluster.
