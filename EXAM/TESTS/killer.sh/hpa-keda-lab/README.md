# CNPE HPA and KEDA Troubleshooting Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio con 20 ticket indipendenti: Q1-Q10 coprono HPA e Metrics Server;
Q11-Q20 coprono KEDA, ScaledObject, autenticazione, cron e Prometheus.

Il setup crea o riusa il cluster e installa i controller condivisi. Le
risorse di ogni domanda vengono applicate esclusivamente dallo script
`qNN/create-resources.sh` e rimosse da `qNN/remove-resources.sh`.

## Minikube

```bash
./setup-hpa-keda-lab.sh
```

## Kind

```bash
./setup-hpa-keda-lab-kind.sh
```

## Cluster esistente

```bash
CLUSTER_PROVIDER=existing ./setup-hpa-keda-lab.sh
```

Impostare `INSTALL_TOOLS=false` soltanto se Metrics Server e KEDA sono già
installati e disponibili.

## Esecuzione

```bash
cd ~/course-hpa-keda/q01
./create-resources.sh
# troubleshooting e verifica
./remove-resources.sh
```

`LAB_FORCE=true` rigenera i file senza eliminare il cluster o i controller
condivisi.
