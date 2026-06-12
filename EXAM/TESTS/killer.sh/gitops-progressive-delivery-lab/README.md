# CNPE GitOps and Progressive Delivery Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico dedicato a:

1. Argo CD Application, sync automatica, prune e self-heal;
2. Flux GitRepository, Kustomization, inventory e drift reconciliation;
3. pipeline Tekton integrata con un workflow GitOps;
4. progressive delivery canary;
5. progressive delivery blue/green.

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
chmod +x setup-gitops-progressive-delivery-lab-kind.sh
./setup-gitops-progressive-delivery-lab-kind.sh
```

Il cluster predefinito si chiama `cnpe-gitops`.

## Avvio su cluster esistente

```bash
chmod +x setup-gitops-progressive-delivery-lab.sh
./setup-gitops-progressive-delivery-lab.sh
```

Il setup installa Argo CD, Flux, Tekton Pipelines e Argo Rollouts. Se sono già
presenti:

```bash
INSTALL_TOOLS=false ./setup-gitops-progressive-delivery-lab.sh
```

Gli starter vengono creati in `~/course-gitops-progressive-delivery/`.
Per rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-gitops-progressive-delivery-lab-kind.sh
```

Versioni predefinite:

- Argo CD `v3.4.2`;
- Flux `v2.8.8`;
- Tekton Pipelines `v1.9.0`;
- Argo Rollouts `v1.9.0`.

Sono sovrascrivibili tramite le rispettive variabili `*_VERSION`.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-gitops-progressive-delivery-lab.sh
```
