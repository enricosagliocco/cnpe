# CNPE Hard Lab — StorageClass / PV / PVC

Lab focalizzato su troubleshooting storage in stile esame CNPE.

## Avvio

```bash
chmod +x setup-storageclass-hard.sh
./setup-storageclass-hard.sh
```

## Cleanup

```bash
./setup-storageclass-hard.sh --cleanup
```

## Namespace

```text
storage-hard
```

## File creati nel cluster

```text
/course/storage-hard/00-storage-broken.yaml
/course/storage-hard/01-configmaps-broken.yaml
/course/storage-hard/02-db-sts-do-not-edit.yaml
/course/storage-hard/03-app-deploy-do-not-edit.yaml
/course/storage-hard/04-cache-pvc-pod-broken.yaml
/course/storage-hard/99-apply-order.txt
/course/storage-hard/README.txt
```

## Vincolo esame

Non modificare:

```text
StatefulSet db
Deployment webapp
```

Puoi correggere:

```text
StorageClass
PV/PVC
Service
ConfigMap
```

## Focus

- Pod Pending
- PVC Pending
- local PV
- nodeAffinity
- StorageClass `WaitForFirstConsumer`
- headless Service per StatefulSet
- ConfigMap app per endpoint DB
- ConfigMap DB per path dati
- initContainer che aspetta il DB
