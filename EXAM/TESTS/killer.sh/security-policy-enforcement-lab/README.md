# CNPE Security and Policy Enforcement Lab

Laboratorio pratico dedicato al dominio CNPE Security and Policy Enforcement:

1. comunicazione service-to-service con mTLS e NetworkPolicy;
2. RBAC least privilege su risorse applicative, policy e pipeline;
3. audit trail e PolicyReport Kyverno;
4. governance tramite admission controller;
5. SBOM, scan report e compliance gate in Tekton.

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

Prerequisiti: Docker o Podman, `kind`, `kubectl`, Helm 3 e OpenSSL.

```bash
chmod +x setup-security-policy-enforcement-lab-kind.sh
./setup-security-policy-enforcement-lab-kind.sh
```

Il cluster kind predefinito si chiama `cnpe-security`.

```bash
KIND_CLUSTER_NAME=cnpe ./setup-security-policy-enforcement-lab-kind.sh
```

Gli starter vengono creati in `~/course-security-policy-enforcement/`.
Per rigenerare i Namespace e lo scenario:

```bash
LAB_FORCE=true ./setup-security-policy-enforcement-lab-kind.sh
```

Versioni predefinite:

- Kyverno Helm chart `3.8.1`;
- Tekton Pipelines `v1.9.0`.

Sono sovrascrivibili tramite `KYVERNO_VERSION` e `TEKTON_VERSION`.
