# Risposte — Batteria 2 (`storage-lab-2`)

> Usa questo file solo **dopo** aver tentato il troubleshooting.  
> Vincolo: non modificare Deployment/StatefulSet.

---

## Area 1: StorageClass e provisioning dinamico

**D1.** Il PVC `api-data` referenzia `storageClassName: cnpe-ssd`, che **non esiste** sul cluster → provisioning dinamico impossibile.

**D2.** `kubectl describe pvc api-data -n storage-lab-2` (sezione Events).

**D3.** Creare la StorageClass richiesta, ad esempio:

```bash
cat <<'YAML' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cnpe-ssd
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: false
YAML
```

**D4.** Il controller può aver già tentato il bind; eliminare il Pod `file-api` per forzare un nuovo scheduling/bind:

```bash
kubectl -n storage-lab-2 delete pod -l app=file-api
```

**D5.** Con `WaitForFirstConsumer` il PVC resta `Pending` finché un Pod che lo usa non è **schedulato**; il volume viene creato/associato nel nodo scelto. Con `Immediate` il PV viene provisionato subito, anche senza Pod.

---

## Area 2: Provisioning statico

**D6.** Mismatch su **accessModes** (`ReadWriteMany` nel PVC vs `ReadWriteOnce` nel PV) e **capacity** (5Gi richiesti vs 2Gi offerti).

**D7.** Anche `storageClassName` deve coincidere (`cnpe-retain` su entrambi).

**D8.** Ricreare il PVC allineato al PV (o correggere il PV se la policy del lab lo consente), senza toccare il Deployment:

```bash
kubectl -n storage-lab-2 delete pvc backup-claim --ignore-not-found
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-claim
  namespace: storage-lab-2
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: cnpe-retain
  volumeName: static-backup-pv
  resources:
    requests:
      storage: 2Gi
YAML
kubectl -n storage-lab-2 rollout restart deployment/backup-agent
```

**D9.** `kubectl get pvc backup-claim -n storage-lab-2` → `STATUS=Bound`, colonna `VOLUME=static-backup-pv`.

**D10.** Statico: volumi pre-esistenti, binding manuale, ambienti air-gapped o storage legacy. Dinamico: self-service, elasticità, meno errori umani.

---

## Area 3: Secret e ConfigMap

**D11.** Il volume Secret richiede la chiave `api-key`; nel Secret esiste solo `apiKey`.

**D12.** Patch/ricreare il Secret con la chiave corretta:

```bash
kubectl -n storage-lab-2 create secret generic api-credentials \
  --from-literal=api-key='super-token-12345' \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n storage-lab-2 delete pod -l app=secure-api
```

**D13.** `subPath: nginx.conf` richiede la chiave `nginx.conf` nella ConfigMap; è definita `default.conf`.

**D14.** I mount con `subPath` non ricevono aggiornamenti automatici; serve ricreare il Pod.

**D15.** I Secret sono pensati per dati sensibili (RBAC, non in etcd in chiaro nei dump casuali), montaggio read-only su tmpfs; le ConfigMap non sono per password/token.

Correzione ConfigMap:

```bash
kubectl -n storage-lab-2 patch configmap nginx-conf --type merge -p '
{"data":{"nginx.conf":"server { listen 8080; location / { return 200 \"ok\\n\"; } }"}}'
kubectl -n storage-lab-2 delete pod -l app=config-worker
```

---

## Area 4: Quota, hostPath, espansione, ciclo di vita

**D16.** `requests.storage: 6Gi` nella ResourceQuota; `backup-claim` (5Gi) + `api-data` (1Gi) saturano la quota (anche in `Pending`). Un terzo PVC da 1Gi supera il limite. Verifica: `kubectl describe resourcequota storage-quota -n storage-lab-2` → `used.requests.storage: 6Gi`, `hard.requests.storage: 6Gi`. Soluzione (senza modificare il Deployment `metrics`):

```bash
kubectl -n storage-lab-2 patch resourcequota storage-quota --type merge -p \
  '{"spec":{"hard":{"requests.storage":"8Gi"}}}'
kubectl apply -f ~/course/storage-lab-2/metrics-pvc.yaml
kubectl -n storage-lab-2 rollout restart deployment/metrics
```

**D17.** `hostPath` con `type: Directory` su `/var/log/cnpe-does-not-exist` — la directory **deve esistere** sul nodo. Fix: creare il path sul nodo (`minikube ssh`) o cambiare `type` a `DirectoryOrCreate` (se il lab consente modificare solo il Pod standalone `node-debug`, non i Deployment).

**D18.** Manca `allowVolumeExpansion: true` sulla StorageClass `cnpe-ssd`:

```bash
kubectl patch storageclass cnpe-ssd -p '{"allowVolumeExpansion":true}'
kubectl -n storage-lab-2 patch pvc api-data -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```

**D19.** Un Pod usa ancora il PVC (`storage object in use protection`). Verifica: `kubectl get pods -n storage-lab-2 -o wide` e `kubectl describe pvc backup-claim`.

**D20.** `emptyDir` con `medium: Memory` usa RAM del nodo/container; conta verso limiti memoria del Pod; rischio OOM se `sizeLimit` superato o pressione memoria sul nodo.

---

## Verifica rapida end-to-end

```bash
kubectl -n storage-lab-2 get pods,pvc,pv
kubectl -n storage-lab-2 exec deploy/file-api -- cat /data/ok
kubectl -n storage-lab-2 exec deploy/secure-api -- cat /etc/creds/api-key
kubectl -n storage-lab-2 exec deploy/config-worker -- cat /etc/nginx/nginx.conf
```
