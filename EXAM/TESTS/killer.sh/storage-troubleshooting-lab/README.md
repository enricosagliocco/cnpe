# CNPE Storage Troubleshooting Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio pratico composto da 20 incidenti storage indipendenti in stile
esame CNPE. Lo script crea o riusa un cluster, genera manifest e comandi
locali, ma non applica le risorse delle domande.

Gli scenari coprono:

- PVC `Pending` e binding statico;
- selector, capacita, access mode, StorageClass e pre-binding;
- ConfigMap, Secret, projected volume, `subPath` e mount read-only;
- StatefulSet e volumeClaimTemplate;
- local PV, node affinity e scheduling;
- reclaim policy `Retain` e recupero di PV `Released`;
- volume mode e permessi per container non-root.

Ogni domanda usa il Namespace `storage-qNN` e la directory
`~/course-storage-troubleshooting/qNN/`. Applicare una sola domanda per volta.

## Avvio con Minikube

Prerequisiti: un driver compatibile con Minikube, `minikube` e `kubectl`.
Il setup predefinito crea un cluster a due nodi.

```bash
./setup-storage-troubleshooting-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kind` e `kubectl`.

```bash
./setup-storage-troubleshooting-lab-kind.sh
```

Il wrapper crea un cluster a tre nodi per gli esercizi sui local PV.

## Avvio su cluster esistente

Il cluster deve avere almeno due nodi schedulabili.

```bash
CLUSTER_PROVIDER=existing ./setup-storage-troubleshooting-lab.sh
```

Per rigenerare tutti i manifest:

```bash
LAB_FORCE=true ./setup-storage-troubleshooting-lab-kind.sh
```

`LAB_FORCE=true` rigenera i file del corso senza eliminare il cluster.

## Esecuzione delle domande

Per avviare, ad esempio, Q03:

```bash
cd ~/course-storage-troubleshooting/q03
./create-resources.sh
```

Terminata la domanda, eliminare tutte le sue risorse prima di passare alla
successiva:

```bash
./remove-resources.sh
```

La cancellazione del Namespace non elimina PV e StorageClass, che sono risorse
cluster-scoped. Per questo va eseguito anche `kubectl delete -f incident.yaml`.
Se durante la soluzione sono stati rinominati o creati oggetti aggiuntivi,
verificare e rimuovere eventuali risorse residue:

```bash
kubectl get pv,storageclass | grep 'storage-q'
```

Q07, Q08, Q09 e Q16 contengono YAML aggiuntivi da usare durante la soluzione.
Per Q16, dopo aver applicato `incident.yaml`, preparare il PV `Released` con:

```bash
kubectl -n storage-q16 wait pvc/old-data \
  --for=jsonpath='{.status.phase}'=Bound --timeout=60s
kubectl -n storage-q16 wait pod/seed \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl -n storage-q16 delete pod seed --wait=true
kubectl -n storage-q16 delete pvc old-data --wait=true
kubectl apply -f recovery.yaml
```

## Pulizia completa

Al termine del laboratorio:

```bash
for n in $(seq -w 1 20); do
  kubectl delete namespace "storage-q${n}" --ignore-not-found --wait=true
done
kubectl get pv -o name | grep '^persistentvolume/storage-q' |
  xargs -r kubectl delete --ignore-not-found
kubectl get storageclass -o name |
  grep '^storageclass.storage.k8s.io/storage-q' |
  xargs -r kubectl delete --ignore-not-found
```
