# Le 20 domande dell'esame — Storage Troubleshooting Lab (simulatore lab)

Scenario creato da `setup-storage-troubleshooting-lab.sh`. I file modificabili
sono in `~/course-storage-troubleshooting/01/`; le risorse sono nel Namespace
`storage-lab`.

**Vincolo:** non modificare, sostituire o scalare il Deployment `orders-app`
e lo StatefulSet `database`. Non usare `kubectl edit`, `patch`, `set`,
`scale` o `rollout restart` su questi controller. Puoi correggere soltanto
ConfigMap e PV ed eliminare i Pod per farli ricreare.

Le domande descrivono un unico incidente progressivo. Conserva comandi,
output e conclusioni in `01/diagnosi.txt`.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 – Triage dei workload

Percorso: `~/course-storage-troubleshooting/01`.

1. Elenca Pod, Deployment, StatefulSet, PVC e PV e identifica tutti gli stati
   anomali senza effettuare modifiche.

### Q2 – Eventi del database

Percorso: `~/course-storage-troubleshooting/01`.

1. Descrivi `database-0` e il PVC `data-database-0`.

2. Salva eventi e messaggi di scheduling rilevanti.

### Q3 – Analisi PVC

Percorso: `~/course-storage-troubleshooting/01`.

1. Rileva richiesta storage, access mode, StorageClass e selector del PVC
   senza modificarne lo spec.

### Q4 – Analisi PV

Percorso: `~/course-storage-troubleshooting/01`.

1. Confronta `01/database-pv.yaml` con il PVC e documenta ogni incompatibilità
   che impedisce il binding.

---

### Q5 – Capacità e access mode

Percorso: `~/course-storage-troubleshooting/01`.

1. Correggi il PV con capacità `1Gi` e access mode `ReadWriteOnce`.

### Q6 – StorageClass e selector

Percorso: `~/course-storage-troubleshooting/01`.

1. Imposta StorageClass `cnpe-manual` e una label compatibile con il selector
   del PVC.

### Q7 – Reclaim policy

Percorso: `~/course-storage-troubleshooting/01`.

1. Configura `persistentVolumeReclaimPolicy: Retain` e spiega perché è adatta
   ai dati del database.

### Q8 – Verifica binding

Percorso: `~/course-storage-troubleshooting/01`.

1. Applica il PV e verifica PV e PVC `Bound` senza eliminare il claim.

2. Registra claimRef, capacità e StorageClass.

---

### Q9 – Log init container database

Percorso: `~/course-storage-troubleshooting/01`.

1. Analizza i log di `verify-volume-config` e identifica il valore di
   configurazione errato.

### Q10 – Mount path effettivo

Percorso: `~/course-storage-troubleshooting/01`.

1. Ispeziona lo StatefulSet in sola lettura e determina il path esatto sul
   quale il PVC è montato.

### Q11 – Correzione ConfigMap database

Percorso: `~/course-storage-troubleshooting/01`.

1. Correggi soltanto `01/database-config.yaml` impostando `data-path` al mount
   path rilevato e applica il file.

### Q12 – Ricreazione database

Percorso: `~/course-storage-troubleshooting/01`.

1. Elimina soltanto `database-0`, attendi la ricreazione e verifica Pod Ready
   e StatefulSet pronto `1/1`.

---

### Q13 – Log init container applicativo

Percorso: `~/course-storage-troubleshooting/01`.

1. Analizza i log di `wait-for-database` e identifica host e porta usati
   dall'applicazione.

### Q14 – Service discovery

Percorso: `~/course-storage-troubleshooting/01`.

1. Ispeziona Service ed EndpointSlice del database e determina il nome DNS
   Kubernetes corretto.

### Q15 – Correzione ConfigMap applicativa

Percorso: `~/course-storage-troubleshooting/01`.

1. Correggi soltanto `01/app-config.yaml` usando il Service database e
   mantenendo la porta `5432`.

### Q16 – Ricreazione applicazione

Percorso: `~/course-storage-troubleshooting/01`.

1. Elimina soltanto il Pod di `orders-app`, attendi la ricreazione e verifica
   Deployment disponibile `1/1`.

---

### Q17 – Persistenza dei dati

Percorso: `~/course-storage-troubleshooting/01`.

1. Scrivi un file di prova nel volume dal Pod database, ricrea il Pod e
   dimostra che il contenuto persiste.

### Q18 – Test di connettività

Percorso: `~/course-storage-troubleshooting/01`.

1. Dal Pod applicativo verifica risoluzione DNS e connessione TCP al Service
   database.

2. Salva output e timestamp.

### Q19 – Root cause analysis

Percorso: `~/course-storage-troubleshooting/01`.

1. Riassumi in `01/diagnosi.txt` le tre cause radice: binding PV/PVC,
   configurazione volume e endpoint database.

2. Associa a ciascuna sintomo e fix.

### Q20 – Verifica finale end-to-end

Percorso: `~/course-storage-troubleshooting/01`.

```bash
kubectl -n storage-lab get pods,pvc
kubectl get pv cnpe-database-pv
kubectl -n storage-lab get deploy orders-app
kubectl -n storage-lab get sts database
```

1. Conferma PV/PVC `Bound`, Pod Ready e controller `1/1`, spiegando perché non
   è stato necessario modificare Deployment o StatefulSet.
