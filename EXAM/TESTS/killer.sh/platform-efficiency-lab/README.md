# CNPE Platform Architecture and Efficiency Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico dedicato a:

1. networking e isolamento multi-tenant;
2. storage locale con binding topology-aware;
3. compute resilience, topology spread e PDB;
4. OpenCost, showback e right-sizing;
5. ResourceQuota, LimitRange e PriorityClass per tenant.

## Avvio con kind

È la modalità consigliata perché crea un cluster a tre nodi.

Prerequisiti: Docker o Podman, `kind`, `kubectl` e Helm 3.

```bash
chmod +x setup-platform-efficiency-lab-kind.sh
./setup-platform-efficiency-lab-kind.sh
```

Il cluster predefinito si chiama `cnpe-efficiency`.

## Avvio su cluster esistente

Il cluster deve avere almeno due Node schedulabili.

```bash
chmod +x setup-platform-efficiency-lab.sh
./setup-platform-efficiency-lab.sh
```

Il setup installa Prometheus e OpenCost. Se sono già disponibili:

```bash
INSTALL_TOOLS=false ./setup-platform-efficiency-lab.sh
```

Gli starter vengono creati in `~/course-platform-efficiency/`. Per
rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-platform-efficiency-lab-kind.sh
```

Versioni predefinite:

- Prometheus chart `29.10.0`;
- OpenCost chart `2.5.22`.

Sono sovrascrivibili tramite `PROMETHEUS_CHART_VERSION` e
`OPENCOST_CHART_VERSION`.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-platform-efficiency-lab.sh
```
