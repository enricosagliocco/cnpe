# CNPE Platform Automation Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio autonomo con 20 esercizi pratici su:

1. OPA Gatekeeper;
2. Crossplane Composition e XRD;
3. Tekton Triggers;
4. OpenTelemetry Collector;
5. RBAC;
6. NetworkPolicy;
7. taint, toleration e affinity;
8. Helm;
9. StorageClass e PVC;
10. HPA e KEDA.

Le domande sono organizzate in dieci scenari progressivi nelle directory
`01`-`10`. Ogni scenario contiene due domande e file starter incompleti.

## Avvio con kind

Prerequisiti: Docker o Podman, `kind`, `kubectl`, `helm` e `curl`.

```bash
chmod +x setup-platform-automation-lab-kind.sh
./setup-platform-automation-lab-kind.sh
```

Il cluster predefinito si chiama `cnpe-platform-automation`. Il wrapper crea
un control-plane e due worker, installa Calico e rende verificabili le
NetworkPolicy.

## Avvio su cluster esistente

Il cluster deve avere almeno due nodi schedulabili e un CNI che implementi le
NetworkPolicy.

```bash
chmod +x setup-platform-automation-lab.sh
CLUSTER_PROVIDER=existing ./setup-platform-automation-lab.sh
```

Il setup installa Gatekeeper, Crossplane, Tekton Pipelines e Triggers,
Metrics Server e KEDA. Se sono gia presenti:

```bash
INSTALL_TOOLS=false ./setup-platform-automation-lab.sh
```

Gli starter vengono creati in `~/course-platform-automation/`.

Per rigenerare il lab:

```bash
LAB_FORCE=true ./setup-platform-automation-lab-kind.sh
```

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-platform-automation-lab.sh
```
