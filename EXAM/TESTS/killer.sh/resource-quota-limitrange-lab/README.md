# CNPE ResourceQuota and LimitRange Lab

Laboratorio pratico Kubernetes dedicato a:

- default request e limit applicati da `LimitRange`;
- minimi, massimi e rapporto limit/request;
- calcolo del consumo aggregato di `ResourceQuota`;
- quote per numero di oggetti;
- diagnosi dei rifiuti di admission;
- dimensionamento e applicazione di workload conformi.

Le 20 domande formano un unico incidente progressivo nel Namespace
`resource-governance`. Gli starter vengono creati in
`~/course-resource-governance/01/`.

## Avvio su cluster esistente

Prerequisiti: `kubectl` e privilegi per creare Namespace.

```bash
chmod +x setup-resource-quota-limitrange-lab.sh
CLUSTER_PROVIDER=existing ./setup-resource-quota-limitrange-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
chmod +x setup-resource-quota-limitrange-lab-kind.sh
./setup-resource-quota-limitrange-lab-kind.sh
```

Il cluster kind predefinito si chiama `cnpe-resource-governance`.

```bash
KIND_CLUSTER_NAME=cnpe ./setup-resource-quota-limitrange-lab-kind.sh
```

Per rigenerare scenario e directory del corso:

```bash
LAB_FORCE=true ./setup-resource-quota-limitrange-lab-kind.sh
```
