# Storage Troubleshooting Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.

Per ogni domanda esegui `./create-resources.sh` quando presente e termina
con `./remove-resources.sh`. Non lasciare risorse di uno scenario attive
durante la prova successiva.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - PVC bloccato in Pending

Namespace: `storage-q01`. Percorso: `~/course-storage-troubleshooting/01`.

Il Pod `reporting` non viene schedulato perché il PVC `report-data` resta
`Pending`. Ripristina il provisioning usando le risorse disponibili nel
cluster e porta il Pod a `Running`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q2 - Binding statico con selector

Namespace: `storage-q02`. Percorso: `~/course-storage-troubleshooting/02`.

Il PVC `catalog-data` non si associa al PV predisposto per il catalogo.
Correggi il binding senza rimuovere il selector dal PVC e verifica il Pod
`catalog`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q3 - Capacità incompatibile

Namespace: `storage-q03`. Percorso: `~/course-storage-troubleshooting/03`.

Il database `ledger` è fermo perché il claim non trova un volume compatibile.
Mantieni invariata la richiesta del PVC, correggi il PV e porta il Pod a
`Running`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q4 - Access mode incompatibile

Namespace: `storage-q04`. Percorso: `~/course-storage-troubleshooting/04`.

Il workload `media` non parte nonostante esista un PV libero. Ripristina il
binding mantenendo `ReadWriteOnce` come requisito applicativo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q5 - StorageClass incoerente

Namespace: `storage-q05`. Percorso: `~/course-storage-troubleshooting/05`.

PV e PVC dell'applicazione `billing` restano separati. Correggi la
configurazione della classe di storage senza introdurre provisioning
dinamico.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q6 - Pre-binding verso un volume inesistente

Namespace: `storage-q06`. Percorso: `~/course-storage-troubleshooting/06`.

Il PVC `archive-data` è configurato per il binding esplicito, ma il Pod
`archive` resta `Pending`. Correggi il riferimento mantenendo il pre-binding.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q7 - Claim mancante

Namespace: `storage-q07`. Percorso: `~/course-storage-troubleshooting/07`.

Il Pod `processor` non viene creato correttamente perché uno dei volumi
dichiarati non è disponibile. Ripristina il claim previsto dal workload e
verifica mount e scrittura.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q8 - ConfigMap volume non disponibile

Namespace: `storage-q08`. Percorso: `~/course-storage-troubleshooting/08`.

Il Pod `config-reader` è bloccato durante il setup dei volumi. Ripristina la
configurazione attesa senza modificare command o volumeMount del container.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q9 - Secret volume non disponibile

Namespace: `storage-q09`. Percorso: `~/course-storage-troubleshooting/09`.

Il Pod `credentials-reader` non parte a causa di un errore sul volume delle
credenziali. Correggi il problema senza inserire dati sensibili direttamente
nel Pod.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q10 - Chiave ConfigMap non trovata

Namespace: `storage-q10`. Percorso: `~/course-storage-troubleshooting/10`.

La ConfigMap richiesta esiste, ma il Pod `settings-reader` resta in
`ContainerCreating`. Correggi la sorgente del volume mantenendo il file
montato con nome `application.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl apply -f application.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q11 - Volume montato read-only

Namespace: `storage-q11`. Percorso: `~/course-storage-troubleshooting/11`.

Il PVC è `Bound`, ma `writer` entra in `CrashLoopBackOff` quando inizializza
la directory dati. Correggi il mount senza cambiare il comando applicativo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q12 - Configurazione del mount path

Namespace: `storage-q12`. Percorso: `~/course-storage-troubleshooting/12`.

L'init container di `postgres` fallisce durante la validazione del volume.
Correggi la configurazione esterna e ricrea il Pod senza modificare il
workload.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q13 - Node affinity del volume locale

Namespace: `storage-q13`. Percorso: `~/course-storage-troubleshooting/13`.

PV e PVC risultano `Bound`, ma `local-reader` non è schedulabile. Correggi la
topologia del PV locale usando un nodo reale e verifica il contenuto del
volume.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q14 - Conflitto tra Pod e local PV

Namespace: `storage-q14`. Percorso: `~/course-storage-troubleshooting/14`.

Il Pod `pinned-writer` e il PV locale impongono vincoli di nodo incompatibili.
Mantieni il Pod sul nodo indicato in `14/target-node.txt` e correggi il
vincolo storage.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q15 - StatefulSet senza provisioning

Namespace: `storage-q15`. Percorso: `~/course-storage-troubleshooting/15`.

Lo StatefulSet `queue` non crea un Pod utilizzabile perché il claim template
non viene provisionato. Correggi il template e verifica StatefulSet `1/1` e
PVC `Bound`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q16 - PV in stato Released

Namespace: `storage-q16`. Percorso: `~/course-storage-troubleshooting/16`.

Dopo la cancellazione di un vecchio claim, il PV con reclaim policy `Retain`
è rimasto `Released` e il nuovo PVC `recovered-data` è `Pending`. Recupera il
volume senza cancellarne i dati e verifica il Pod `recovery`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q17 - Volume mode incompatibile

Namespace: `storage-q17`. Percorso: `~/course-storage-troubleshooting/17`.

Esiste un PV libero con capacità e access mode corretti, ma il PVC
`filesystem-data` non effettua il binding. Ripristina il workload mantenendo
un mount filesystem nel Pod.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q18 - subPath assente

Namespace: `storage-q18`. Percorso: `~/course-storage-troubleshooting/18`.

Il Pod `subpath-reader` non avvia il container nonostante PV e PVC siano
`Bound`. Correggi il contenuto del volume o il relativo bootstrap mantenendo
il mount finale su `/etc/app/config.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl apply -f /etc/app/config.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q19 - Permessi sul volume

Namespace: `storage-q19`. Percorso: `~/course-storage-troubleshooting/19`.

Il container principale di `nonroot-writer` non può scrivere sul volume
preparato dall'init container. Correggi ownership e permessi mantenendo il
container applicativo non-root.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Q20 - Incidente storage multi-causa

Namespace: `storage-q20`. Percorso: `~/course-storage-troubleshooting/20`.

Il Deployment `orders` non ha repliche disponibili. Il ticket contiene più
di una causa storage indipendente tra claim, volume e configurazione montata.
Ripristina il Deployment `1/1` senza cambiare immagine o comando e documenta
ogni causa radice in `20/evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-storage-troubleshooting` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-storage-troubleshooting
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```
