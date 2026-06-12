# CNPE Security and Policy Enforcement Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico dedicato al dominio CNPE Security and Policy Enforcement:

1. comunicazione service-to-service con mTLS e NetworkPolicy;
2. RBAC least privilege su risorse applicative, policy e pipeline;
3. audit trail e PolicyReport Kyverno;
4. governance tramite admission controller;
5. SBOM, scan report e compliance gate in Tekton.

Le 20 domande sono raccolte in cinque scenari progressivi nelle directory
`01`-`05`. Ogni blocco di quattro domande condivide gli stessi starter.

## Avvio su cluster esistente

Prerequisiti: `kubectl`, Helm 3, OpenSSL e privilegi cluster-admin.

```bash
chmod +x setup-security-policy-enforcement-lab.sh
./setup-security-policy-enforcement-lab.sh
```

Il setup installa Kyverno e Tekton Pipelines. Se sono già presenti:

```bash
INSTALL_TOOLS=false ./setup-security-policy-enforcement-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kind`, `kubectl`, Helm 3 e OpenSSL. Il setup
crea il cluster senza il CNI predefinito e installa Calico, necessario per
applicare realmente le NetworkPolicy.

```bash
chmod +x setup-security-policy-enforcement-lab-kind.sh
./setup-security-policy-enforcement-lab-kind.sh
```

Il cluster kind predefinito si chiama `cnpe-security`.

```bash
KIND_CLUSTER_NAME=cnpe ./setup-security-policy-enforcement-lab-kind.sh
```

Se esiste già un cluster kind con lo stesso nome ma usa `kindnet`, eliminalo
prima di eseguire il setup:

```bash
kind delete cluster --name cnpe-security
```

Gli starter vengono creati in `~/course-security-policy-enforcement/`.
Per rigenerare i Namespace e lo scenario:

```bash
LAB_FORCE=true ./setup-security-policy-enforcement-lab-kind.sh
```

Versioni predefinite:

- Kyverno Helm chart `3.8.1`;
- Tekton Pipelines `v1.9.0`.
- Calico `v3.29.3` per il cluster kind.

Sono sovrascrivibili tramite `KYVERNO_VERSION`, `TEKTON_VERSION` e
`CALICO_VERSION`.

La directory del lab è autonoma: può essere copiata ed eseguita senza il file
condiviso `../lab-question-layout.sh`.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-security-policy-enforcement-lab.sh
```
