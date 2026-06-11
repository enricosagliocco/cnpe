# CNPE Platform API and Operator Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico dedicato a:

1. progettazione e validazione di CustomResourceDefinition;
2. RBAC per API self-service multi-tenant;
3. reconciliation con un Kubernetes operator;
4. provisioning automatizzato tramite Tekton;
5. status, drift, finalizer e lifecycle delle risorse gestite.

Le 20 domande sono raccolte in cinque scenari progressivi nelle directory
`01`-`05`. Ogni blocco di quattro domande condivide gli stessi starter.

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
./setup-platform-api-operator-lab-kind.sh
```

Il cluster predefinito si chiama `cnpe-platform-api`.

## Avvio su cluster esistente

```bash
./setup-platform-api-operator-lab.sh
```

Il setup installa Tekton Pipelines. Se Tekton è già presente:

```bash
INSTALL_TOOLS=false ./setup-platform-api-operator-lab.sh
```

Gli starter vengono creati in `~/course-platform-api-operator/`.
Per rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-platform-api-operator-lab-kind.sh
```

La versione Tekton predefinita è `v1.9.0` ed è sovrascrivibile tramite
`TEKTON_VERSION`.

La directory del lab è autonoma: può essere copiata ed eseguita senza il file
condiviso `../lab-question-layout.sh`.
