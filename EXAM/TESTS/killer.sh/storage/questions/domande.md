# Le 20 domande dell'esame — Storage (broken-app)

Scenario deployato da `setup-lab.sh`. Manifest in `~/course/troubleshooting-lab/`.  
Namespace: **`broken-app`**.

**Vincolo:** non modificare gli YAML di **StatefulSet** `db` e **Deployment** `webapp`.  
Puoi modificare: StorageClass, PVC (ricreazione), ConfigMap, Secret, Service correlati.

Verifica in `risposte.md`. Guida: [storage-test.md](../storage-test.md).

---

### Q1 – PVC postgres Pending

Il PVC `postgres-data-db-0` del StatefulSet `db` resta `Pending`.

1. Identifica la StorageClass richiesta dal PVC
2. Verifica se quella StorageClass esiste nel cluster
3. Salva gli eventi del PVC in `/course/troubleshooting-lab/pvc-events.txt`

---

### Q2 – Eventi provisioning

1. Usa `kubectl describe pvc postgres-data-db-0 -n broken-app` e isola il messaggio di errore provisioning
2. Annota la StorageClass mancante o errata in pvc-events.txt

---

### Q3 – Creazione StorageClass fast-ssd

1. Crea la StorageClass `fast-ssd` con provisioner adatto a Minikube (`k8s.io/minikube-hostpath` o `rancher.io/local-path`)
2. Imposta `volumeBindingMode: Immediate` salvo diversa indicazione del lab
3. Applica al cluster

---

### Q4 – Sblocco binding PVC

1. Se il PVC resta Pending dopo Q3, elimina e ricrea il PVC **solo se** il lab lo consente, oppure attendi rebind automatico
2. Conferma stato `Bound` con `kubectl -n broken-app get pvc`
3. Verifica che il volume sia montabile dal Pod `db-0` dopo fix ConfigMap (Q6+)

---

### Q5 – volumeBindingMode (teoria operativa)

1. Documenta in `/course/troubleshooting-lab/binding-notes.txt` la differenza tra `Immediate` e `WaitForFirstConsumer` per questo StatefulSet
2. Non cambiare la StorageClass se il PVC è già Bound

---

### Q6 – ConfigMap postgres-config (PGDATA)

Il Pod `db-0` crashloopa per path dati errato.

1. Leggi la ConfigMap `postgres-config` e individua il valore errato di `PGDATA`
2. Correggi `PGDATA` in modo che sia compatibile con `subPath: pgdata` e mount `/var/lib/postgresql/data`
3. Applica la ConfigMap

---

### Q7 – Ricarico ConfigMap nel Pod db

1. Elimina il Pod `db-0` per forzare ricreazione da StatefulSet **oppure** usa procedura consentita dal lab per reload
2. Attendi Pod `Running` e PVC Bound
3. Verifica log postgres senza errore su directory data

---

### Q8 – Password in ConfigMap (bad practice)

1. Conferma che `POSTGRES_PASSWORD` è in ConfigMap (non Secret)
2. Annota in binding-notes.txt perché andrebbe migrato a Secret in produzione
3. Non è richiesta migrazione a Secret per completare il lab base

---

### Q9 – ConfigMap webapp-config (DATABASE_HOST)

Il Deployment `webapp` non raggiunge il database.

1. Leggi `webapp-config` e confronta `DATABASE_HOST` con il nome del Service DNS reale del database
2. Correggi l'host (Service headless `db` nel namespace `broken-app`)
3. Applica la ConfigMap

---

### Q10 – Rollout webapp

1. Esegui `kubectl -n broken-app rollout restart deployment/webapp`
2. Attendi Pod Ready
3. Verifica che le env nel Pod riflettano la ConfigMap aggiornata

---

### Q11 – Service headless db

1. Descrivi il Service `db` (`clusterIP: None`)
2. Spiega il FQDN usato dal client: `db.broken-app.svc.cluster.local`
3. Aggiungi nota in binding-notes.txt

---

### Q12 – Test connettività web → DB

1. Port-forward o curl sul Pod webapp: la pagina deve mostrare connessione DB **OK** (verde)
2. Salva output HTML o log in `/course/troubleshooting-lab/web-db-test.txt`

---

### Q13 – Readiness webapp

1. Se readiness fallisce, descrivi la probe nel Deployment (solo lettura YAML)
2. Correggi solo via ConfigMap/Service/DB — non modificare il Deployment

---

### Q14 – get pods wide

```bash
kubectl -n broken-app get pods -o wide
kubectl -n broken-app get pvc,sc
```

1. Esegui i comandi e salva output in web-db-test.txt

---

### Q15 – Eventi namespace

1. `kubectl -n broken-app get events --sort-by='.lastTimestamp' | tail -25`
2. Collega l'ultimo errore risolto (PVC, PGDATA o DNS) all'evento corrispondente

---

### Q16 – StorageClass reclaim policy

1. Documenta quale `reclaimPolicy` hai usato su `fast-ssd` e impatto su delete PVC

---

### Q17 – Capacità PVC

1. Verifica size richiesta dal volumeClaimTemplate (1Gi) e che il provisioner l'abbia soddisfatta

---

### Q18 – SubPath pgdata

1. Spiega perché `subPath: pgdata` richiede che PGDATA punti alla sottodirectory corretta sotto il mount

---

### Q19 – NodePort webapp

1. Ottieni NodePort del Service `webapp` e testa da browser o curl esterno al cluster Minikube

---

### Q20 – Verifica finale end-to-end

1. PVC `postgres-data-db-0` Bound
2. Pod `db-0` Running
3. Pod `webapp` Running/Ready
4. Pagina web mostra DB OK
5. StatefulSet e Deployment YAML non alterati (solo risorse consentite modificate)

---
