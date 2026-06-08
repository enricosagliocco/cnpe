# CNPE Storage Troubleshooting Lab

Scenario singolo di troubleshooting Kubernetes focalizzato su:

- Pod bloccati prima dell'avvio;
- eventi e log degli init container;
- binding statico tra PersistentVolume e PersistentVolumeClaim;
- selector, label, StorageClass, capacità e access mode;
- ConfigMap usate da applicazione e database;
- recupero operativo senza modificare Deployment e StatefulSet.

## Avvio su cluster esistente

```bash
chmod +x setup-storage-troubleshooting-lab.sh
./setup-storage-troubleshooting-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
chmod +x setup-storage-troubleshooting-lab-kind.sh
./setup-storage-troubleshooting-lab-kind.sh
```

Il cluster kind predefinito si chiama `cnpe-storage`. Per usarne un altro:

```bash
KIND_CLUSTER_NAME=cnpe ./setup-storage-troubleshooting-lab-kind.sh
```

Gli starter vengono creati in `~/course-storage-troubleshooting/01/`.
Per rigenerare completamente scenario e Namespace:

```bash
LAB_FORCE=true ./setup-storage-troubleshooting-lab-kind.sh
```
