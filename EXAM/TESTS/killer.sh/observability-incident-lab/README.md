# CNPE Observability and Incident Response Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico dedicato a:

1. monitoring e alerting con Prometheus Operator;
2. logging centralizzato con Loki, Promtail e Grafana;
3. tracing distribuito con OpenTelemetry e Jaeger;
4. indicatori DORA, SLI, SLO ed efficienza della piattaforma;
5. correlazione metriche-log-trace e incident remediation.

## Avvio con kind

Prerequisiti: Docker o Podman, `kind`, `kubectl` e Helm.

```bash
./setup-observability-incident-lab-kind.sh
```

Il cluster predefinito si chiama `cnpe-observability`.

## Avvio su cluster esistente

```bash
./setup-observability-incident-lab.sh
```

Per usare uno stack gia installato:

```bash
INSTALL_TOOLS=false ./setup-observability-incident-lab.sh
```

Gli starter vengono creati in `~/course-observability-incident/`.
Per rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-observability-incident-lab-kind.sh
```

Versioni predefinite:

- kube-prometheus-stack `86.2.0`;
- Loki `6.55.0`;
- Promtail `6.17.1`;
- Jaeger `1.76.0`;
- OpenTelemetry Collector `0.134.0`.
