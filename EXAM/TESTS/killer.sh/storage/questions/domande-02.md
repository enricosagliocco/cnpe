# Le 20 domande dell'esame — Storage avanzato (storage-lab-2)

Scenario deployato da `setup-lab-v2.sh`. Manifest in `~/course/storage-lab-2/`.  
Namespace: **`storage-lab-2`**.

**Vincolo:** non modificare gli YAML di **Deployment** e **StatefulSet** del lab.  
Puoi modificare: StorageClass, PV, PVC (ricreazione), Secret, ConfigMap, ResourceQuota.

Verifica in `risposte-02.md`.

---

### Q1 – PVC api-data Pending

Il PVC `api-data` resta `Pending`; il Deployment `file-api` non parte.

1. Identifica la `storageClassName` richiesta dal PVC
2. Verifica esistenza della StorageClass nel cluster
3. Salva eventi PVC in `/course/storage-lab-2/events.txt`

---

### Q2 – describe pvc api-data

1. Esegui `kubectl -n storage-lab-2 describe pvc api-data`
2. Copia la riga Events principale in events.txt

---

### Q3 – Creare StorageClass cnpe-ssd

1. Crea StorageClass `cnpe-ssd` con provisioner Minikube e `volumeBindingMode: Immediate`
2. Applica al cluster
3. Attendi binding PVC o ricrea PVC se necessario senza toccare Deployment `file-api`

---

### Q4 – Pod file-api dopo binding

1. Quando `api-data` è Bound, elimina Pod del Deployment `file-api` per remount
2. Verifica Pod Running
3. `kubectl -n storage-lab-2 exec deploy/file-api -- cat /data/ok` deve funzionare dopo fix completo

---

### Q5 – WaitForFirstConsumer (documentazione)

1. Aggiungi in events.txt nota su cosa cambierebbe con `WaitForFirstConsumer` per `cnpe-ssd`

---

### Q6 – backup-claim vs static-backup-pv

Il PVC `backup-claim` non si lega al PV `static-backup-pv`.

1. Confronta `accessModes`, `storage`, `storageClassName` tra PV e PVC
2. Elenca tutti i mismatch in events.txt

---

### Q7 – Allineamento binding statico

1. Correggi PV e/o PVC **senza** modificare Deployment `backup-agent` (elimina/ricrea PVC, patch PV)
2. Allinea capacity, accessMode e storageClassName
3. Applica modifiche

---

### Q8 – Conferma backup Bound

1. `kubectl -n storage-lab-2 get pvc backup-claim` deve mostrare `Bound` e nome volume
2. Riavvia Deployment `backup-agent` se necessario
3. `kubectl -n storage-lab-2 exec deploy/backup-agent -- ls -la /backup`

---

### Q9 – Provisioning statico (nota)

1. Documenta in events.txt un caso d'uso produzione per PV statico vs dinamico

---

### Q10 – Secret api-credentials

Il Deployment `secure-api` è in `ContainerCreating` per mount Secret.

1. Confronta chiavi Secret con `items.key` nel volume del Deployment (sola lettura YAML)
2. Correggi Secret affinché esista chiave **`api-key`**
3. Applica Secret e ricrea Pod `secure-api`

---

### Q11 – Verifica mount secure-api

1. `kubectl -n storage-lab-2 exec deploy/secure-api -- cat /etc/creds/api-key`
2. Output atteso: token presente

---

### Q12 – ConfigMap nginx-conf

1. Correggi ConfigMap `nginx-conf`: chiave file deve essere **`nginx.conf`** (contenuto server nginx)
2. Applica ConfigMap
3. Ricrea Pod `config-worker`

---

### Q13 – subPath e hot reload

1. Documenta in events.txt perché con `subPath` la ConfigMap non aggiorna il file in place
2. Conferma che dopo ricreazione Pod il mount sia corretto

---

### Q14 – Secret vs ConfigMap per credenziali

1. Aggiungi nota in events.txt: perché Secret è preferito per credenziali CNPE

---

### Q15 – ResourceQuota e metrics-data

I PVC `backup-claim` (5Gi) e `api-data` (1Gi) saturano `requests.storage: 6Gi`. Il PVC `metrics-data` non esiste.

1. `kubectl describe resourcequota storage-quota -n storage-lab-2`
2. Aumenta `requests.storage` almeno a **8Gi** (patch ResourceQuota)
3. Applica `/course/storage-lab-2/metrics-pvc.yaml`

---

### Q16 – Deployment metrics

1. Riavvia Deployment `metrics` dopo Q15
2. Verifica Pod Running con volume montato

---

### Q17 – hostPath node-debug

Il Pod `node-debug` è `ContainerCreating` per hostPath.

1. Identifica path e `type: Directory` nel Pod spec (sola lettura)
2. Crea directory sul nodo Minikube (`minikube ssh -- mkdir -p ...`) **oppure** correggi solo il Pod standalone se il lab consente modifica Pod `node-debug`
3. Conferma Pod Running

---

### Q18 – Espansione PVC api-data a 2Gi

1. Aggiungi `allowVolumeExpansion: true` sulla StorageClass `cnpe-ssd`
2. Patch PVC `api-data` richiesta storage a `2Gi`
3. Verifica espansione in status PVC

---

### Q19 – PVC Terminating backup-claim

1. Simula o documenta: PVC in Terminating perché Pod ancora monta il volume
2. Comando per identificare Pod che usano il PVC

---

### Q20 – Verifica finale storage-lab-2

1. `kubectl -n storage-lab-2 get pods,pvc,pv,sc`
2. `api-data`, `backup-claim` Bound; `metrics-data` Bound dopo Q15
3. `file-api`, `secure-api`, `config-worker`, `metrics` funzionanti
4. `events.txt` completo in `/course/storage-lab-2/`
5. Deployment/StatefulSet YAML non modificati

---
