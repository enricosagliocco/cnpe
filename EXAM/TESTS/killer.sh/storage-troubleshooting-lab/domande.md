# CNPE Storage Troubleshooting Lab

Scenario creato da `setup-storage-troubleshooting-lab.sh`. I file modificabili
sono in `~/course-storage-troubleshooting/01/`; le risorse applicative sono nel
Namespace `storage-lab`.

## Vincolo d'esame

**Non modificare, sostituire o scalare il Deployment `orders-app` e lo
StatefulSet `database`.** Non usare `kubectl edit`, `kubectl patch`, `kubectl
set`, `kubectl scale` o `kubectl rollout restart` su questi controller.

Puoi:

- modificare e applicare le ConfigMap fornite;
- correggere e applicare il PersistentVolume fornito;
- eliminare esclusivamente i Pod per farli ricreare dai controller;
- usare comandi di osservazione, log, eventi e debug.

La soluzione deve mantenere i nomi delle risorse esistenti.

---

Il team segnala che l'applicazione ordini non diventa Ready. Anche il database
non parte e il PVC resta in `Pending`.

Risolvi l'intero incidente senza modificare Deployment e StatefulSet.

---

### Q1 – Diagnosi iniziale

1. Individua perché il Pod del database non viene schedulato.
2. Confronta richiesta del PVC, PersistentVolume disponibile, StorageClass,
   access mode, capacità e selector.
3. Individua perché l'init container dell'applicazione fallisce.
4. Salva in `01/diagnosi.txt`:
   - output rilevante di `kubectl get`;
   - eventi del PVC;
   - log dell'init container applicativo;
   - causa radice dei tre guasti.

---

### Q2 – Binding PV/PVC

Correggi `01/database-pv.yaml` affinché soddisfi il PVC creato dallo
StatefulSet.

Requisiti finali:

- PV `cnpe-database-pv`;
- capacità `1Gi`;
- access mode `ReadWriteOnce`;
- StorageClass `cnpe-manual`;
- reclaim policy `Retain`;
- label compatibile con il selector del PVC;
- PVC `data-database-0` in stato `Bound`.

Non eliminare il PVC e non modificare il suo spec.

---

### Q3 – Configurazione del database

Dopo il binding, il Pod `database-0` raggiunge l'init container ma non parte.

1. Analizza i log di `verify-volume-config`.
2. Correggi soltanto `01/database-config.yaml`.
3. Il valore `data-path` deve indicare esattamente il path sul quale il PVC è
   montato dallo StatefulSet.
4. Applica la ConfigMap ed elimina il solo Pod `database-0`.
5. Attendi che lo StatefulSet ricrei il Pod e che il database sia `Ready`.

---

### Q4 – Configurazione dell'applicazione

L'app continua a non partire perché usa un endpoint database errato.

1. Analizza ConfigMap, Service e log di `wait-for-database`.
2. Correggi soltanto `01/app-config.yaml`.
3. Usa il nome DNS Kubernetes del Service database e conserva la porta 5432.
4. Applica la ConfigMap ed elimina il solo Pod dell'applicazione.
5. Verifica che il Deployment torni disponibile senza modificarne lo spec.

---

### Q5 – Verifica finale end-to-end

Lo scenario è risolto quando:

```bash
kubectl -n storage-lab get pods,pvc
kubectl get pv cnpe-database-pv
kubectl -n storage-lab get deploy orders-app
kubectl -n storage-lab get sts database
```

mostra:

- PVC e PV `Bound`;
- `database-0` `Running` e `Ready`;
- Pod applicativo `Running` e `Ready`;
- Deployment `orders-app` disponibile `1/1`;
- StatefulSet `database` pronto `1/1`.

Completa `01/diagnosi.txt` con i comandi di verifica e una breve spiegazione
del motivo per cui non era necessario modificare i workload controller.
