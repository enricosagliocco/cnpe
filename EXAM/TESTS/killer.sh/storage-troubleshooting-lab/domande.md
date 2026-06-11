# Le 20 domande dell'esame - Storage Troubleshooting Lab

## Metodo operativo obbligatorio

Ogni domanda e un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale nel cluster;
2. raccogliere il sintomo tramite stato, condizioni, eventi, log o output del controller;
3. identificare e registrare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla con un test runtime positivo e, quando previsto, negativo.

La sola modifica del file, il solo dry-run client-side o una risposta teorica
non completano il ticket. Conserva comando, errore iniziale, correzione e
verifica finale nell'evidence file indicato dalla domanda.

Scenario creato da `setup-storage-troubleshooting-lab.sh`. Ogni domanda è un
incidente indipendente già presente nel cluster. I file starter si trovano in
`~/course-storage-troubleshooting/NN/` e le risorse nel Namespace
`storage-qNN`.

Per ogni ticket:

- individua la causa radice usando stato, eventi e log;
- correggi soltanto le risorse coinvolte nel Namespace della domanda e gli
  eventuali PV o StorageClass indicati;
- non risolvere il problema sostituendo il workload con uno differente;
- conserva diagnosi, comandi e verifica finale in `NN/evidence.txt`.

Comandi utili:

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe pod -n <namespace> <pod>
kubectl get pv,pvc -A
```

---

### Q1 - PVC bloccato in Pending
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q01`. Percorso: `~/course-storage-troubleshooting/01`.

Il Pod `reporting` non viene schedulato perché il PVC `report-data` resta
`Pending`. Ripristina il provisioning usando le risorse disponibili nel
cluster e porta il Pod a `Running`.

### Q2 - Binding statico con selector
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q02`. Percorso: `~/course-storage-troubleshooting/02`.

Il PVC `catalog-data` non si associa al PV predisposto per il catalogo.
Correggi il binding senza rimuovere il selector dal PVC e verifica il Pod
`catalog`.

### Q3 - Capacità incompatibile
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q03`. Percorso: `~/course-storage-troubleshooting/03`.

Il database `ledger` è fermo perché il claim non trova un volume compatibile.
Mantieni invariata la richiesta del PVC, correggi il PV e porta il Pod a
`Running`.

### Q4 - Access mode incompatibile
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q04`. Percorso: `~/course-storage-troubleshooting/04`.

Il workload `media` non parte nonostante esista un PV libero. Ripristina il
binding mantenendo `ReadWriteOnce` come requisito applicativo.

### Q5 - StorageClass incoerente
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q05`. Percorso: `~/course-storage-troubleshooting/05`.

PV e PVC dell'applicazione `billing` restano separati. Correggi la
configurazione della classe di storage senza introdurre provisioning
dinamico.

### Q6 - Pre-binding verso un volume inesistente
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q06`. Percorso: `~/course-storage-troubleshooting/06`.

Il PVC `archive-data` è configurato per il binding esplicito, ma il Pod
`archive` resta `Pending`. Correggi il riferimento mantenendo il pre-binding.

### Q7 - Claim mancante
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q07`. Percorso: `~/course-storage-troubleshooting/07`.

Il Pod `processor` non viene creato correttamente perché uno dei volumi
dichiarati non è disponibile. Ripristina il claim previsto dal workload e
verifica mount e scrittura.

### Q8 - ConfigMap volume non disponibile
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q08`. Percorso: `~/course-storage-troubleshooting/08`.

Il Pod `config-reader` è bloccato durante il setup dei volumi. Ripristina la
configurazione attesa senza modificare command o volumeMount del container.

### Q9 - Secret volume non disponibile
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q09`. Percorso: `~/course-storage-troubleshooting/09`.

Il Pod `credentials-reader` non parte a causa di un errore sul volume delle
credenziali. Correggi il problema senza inserire dati sensibili direttamente
nel Pod.

### Q10 - Chiave ConfigMap non trovata
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q10`. Percorso: `~/course-storage-troubleshooting/10`.

La ConfigMap richiesta esiste, ma il Pod `settings-reader` resta in
`ContainerCreating`. Correggi la sorgente del volume mantenendo il file
montato con nome `application.yaml`.

### Q11 - Volume montato read-only
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q11`. Percorso: `~/course-storage-troubleshooting/11`.

Il PVC è `Bound`, ma `writer` entra in `CrashLoopBackOff` quando inizializza
la directory dati. Correggi il mount senza cambiare il comando applicativo.

### Q12 - Configurazione del mount path
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q12`. Percorso: `~/course-storage-troubleshooting/12`.

L'init container di `postgres` fallisce durante la validazione del volume.
Correggi la configurazione esterna e ricrea il Pod senza modificare il
workload.

### Q13 - Node affinity del volume locale
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q13`. Percorso: `~/course-storage-troubleshooting/13`.

PV e PVC risultano `Bound`, ma `local-reader` non è schedulabile. Correggi la
topologia del PV locale usando un nodo reale e verifica il contenuto del
volume.

### Q14 - Conflitto tra Pod e local PV
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q14`. Percorso: `~/course-storage-troubleshooting/14`.

Il Pod `pinned-writer` e il PV locale impongono vincoli di nodo incompatibili.
Mantieni il Pod sul nodo indicato in `14/target-node.txt` e correggi il
vincolo storage.

### Q15 - StatefulSet senza provisioning
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q15`. Percorso: `~/course-storage-troubleshooting/15`.

Lo StatefulSet `queue` non crea un Pod utilizzabile perché il claim template
non viene provisionato. Correggi il template e verifica StatefulSet `1/1` e
PVC `Bound`.

### Q16 - PV in stato Released
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q16`. Percorso: `~/course-storage-troubleshooting/16`.

Dopo la cancellazione di un vecchio claim, il PV con reclaim policy `Retain`
è rimasto `Released` e il nuovo PVC `recovered-data` è `Pending`. Recupera il
volume senza cancellarne i dati e verifica il Pod `recovery`.

### Q17 - Volume mode incompatibile
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q17`. Percorso: `~/course-storage-troubleshooting/17`.

Esiste un PV libero con capacità e access mode corretti, ma il PVC
`filesystem-data` non effettua il binding. Ripristina il workload mantenendo
un mount filesystem nel Pod.

### Q18 - subPath assente
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q18`. Percorso: `~/course-storage-troubleshooting/18`.

Il Pod `subpath-reader` non avvia il container nonostante PV e PVC siano
`Bound`. Correggi il contenuto del volume o il relativo bootstrap mantenendo
il mount finale su `/etc/app/config.yaml`.

### Q19 - Permessi sul volume
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q19`. Percorso: `~/course-storage-troubleshooting/19`.

Il container principale di `nonroot-writer` non può scrivere sul volume
preparato dall'init container. Correggi ownership e permessi mantenendo il
container applicativo non-root.

### Q20 - Incidente storage multi-causa
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Namespace: `storage-q20`. Percorso: `~/course-storage-troubleshooting/20`.

Il Deployment `orders` non ha repliche disponibili. Il ticket contiene più
di una causa storage indipendente tra claim, volume e configurazione montata.
Ripristina il Deployment `1/1` senza cambiare immagine o comando e documenta
ogni causa radice in `20/evidence.txt`.
