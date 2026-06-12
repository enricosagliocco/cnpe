# CNPE Capacity and Autoscaling Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico con cinque esercizi:

1. ResourceQuota che impedisce la seconda replica;
2. LimitRange con default incompatibili con la capacità del Namespace;
3. VPA in modalità raccomandazione;
4. HPA CPU con Metrics Server e generatore di carico;
5. KEDA cron scaler e HPA gestito automaticamente.

## Avvio su cluster esistente

Prerequisiti: `kubectl`, Helm 3 e accesso cluster-admin.

```bash
chmod +x setup-capacity-autoscaling-lab.sh
./setup-capacity-autoscaling-lab.sh
```

Il setup installa Metrics Server, VPA e KEDA. Se sono già installati:

```bash
INSTALL_TOOLS=false ./setup-capacity-autoscaling-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kind`, `kubectl` e Helm 3.

```bash
chmod +x setup-capacity-autoscaling-lab-kind.sh
./setup-capacity-autoscaling-lab-kind.sh
```

Il cluster kind predefinito si chiama `cnpe-capacity`.

```bash
KIND_CLUSTER_NAME=cnpe ./setup-capacity-autoscaling-lab-kind.sh
```

Gli starter vengono creati in `~/course-capacity-autoscaling/`. Per
rigenerare Namespace ed esercizi:

```bash
LAB_FORCE=true ./setup-capacity-autoscaling-lab-kind.sh
```

Versioni predefinite:

- Metrics Server `v0.8.1`;
- VPA Helm chart `0.9.0`;
- KEDA Helm chart `2.18.1`.

Sono sovrascrivibili tramite `METRICS_SERVER_VERSION`, `VPA_CHART_VERSION` e
`KEDA_CHART_VERSION`.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-capacity-autoscaling-lab.sh
```
