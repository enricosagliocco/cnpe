# CNPE Platform API and Operator Lab

Laboratorio pratico dedicato a:

1. progettazione e validazione di CustomResourceDefinition;
2. RBAC per API self-service multi-tenant;
3. reconciliation con un Kubernetes operator;
4. provisioning automatizzato tramite Tekton;
5. status, drift, finalizer e lifecycle delle risorse gestite.

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
