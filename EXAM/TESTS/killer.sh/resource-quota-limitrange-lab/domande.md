# Resource Governance Troubleshooting Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
Le soluzioni sono raccolte nella sezione finale del documento.

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
### Q1 - Pod senza resources

Percorso: `~/course-resource-governance/01`.

1. Applica `defaulted-pod.yaml`.
2. Verifica che il Pod venga creato ma che request e limit non corrispondano a
   valori dichiarati nel file.
3. Individua quale risorsa di admission li ha aggiunti.
4. Registra valori effettivi e stato del Pod in `evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q2 - Manifest esplicito

Percorso: `~/course-resource-governance/01`.

1. Crea `explicit-pod.yaml` per un Pod `explicit-pod` con immagine
   `nginx:1.27-alpine`.
2. Dichiara request `cpu: 100m`, `memory: 64Mi` e limit `cpu: 200m`,
   `memory: 128Mi`.
3. Esegui un dry-run server-side, crea il Pod e verifica che i valori non
   vengano modificati.
4. Elimina `explicit-pod` dopo la verifica.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q3 - Request oltre il massimo

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `oversized-pod.yaml`.
2. Usa il messaggio di admission per individuare container, risorsa e soglia
   violata.
3. Correggi solo CPU request e limit portandoli al massimo consentito.
4. Ripeti il dry-run fino a ottenere esito positivo, senza creare il Pod.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q4 - Rapporto limit/request

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `burst-pod.yaml`.
2. Calcola il rapporto CPU configurato e ricava dal cluster quello ammesso.
3. Correggi soltanto il limit CPU usando il valore massimo valido.
4. Verifica con dry-run server-side senza creare il Pod.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q5 - Request sotto il minimo

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `below-minimum-pod.yaml`.
2. Identifica il minimo CPU richiesto dal `LimitRange`.
3. Correggi soltanto la request CPU con il minimo consentito.
4. Crea il Pod, verifica le risorse effettive e poi eliminalo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q6 - Errore nascosto nel sidecar

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `multi-container-pod.yaml`.
2. Individua quale dei due container viola il `LimitRange`; non correggere il
   container già conforme.
3. Correggi il rapporto CPU del solo sidecar.
4. Crea il Pod, verifica entrambi i container e poi eliminalo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q7 - Limite aggiunto automaticamente

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `missing-limit-pod.yaml`.
2. Confronta l'output YAML del dry-run con il file originale.
3. Individua il limit aggiunto dal `LimitRange` e verifica che il rapporto
   risultante sia valido.
4. Crea il Pod e registra request e limit osservati.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q8 - Quota CPU esaurita

Percorso: `~/course-resource-governance/01`.

1. Tenta di applicare `oversized-pod.yaml`, già corretto in Q3.
2. Diagnostica il nuovo rifiuto, distinguendolo dall'errore di `LimitRange`.
3. Identifica quali Pod consumano la quota CPU.
4. Elimina soltanto `missing-limit-pod`, riprova la creazione e verifica che
   `oversized-pod` sia Running.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q9 - ReplicaSet senza Pod

Percorso: `~/course-resource-governance/01`.

1. Applica `batch-worker.yaml`.
2. Diagnostica perché il Deployment esiste ma non raggiunge due repliche.
3. Usa eventi di Deployment e ReplicaSet per dimostrare il rifiuto da parte
   della quota.
4. Elimina `batch-worker` e verifica che non restino Pod associati.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q10 - Ridimensionamento del Deployment

Percorso: `~/course-resource-governance/01`.

1. Elimina `oversized-pod` per liberare il budget usato nel test precedente.
2. Correggi `batch-worker.yaml` mantenendo due repliche e impostando, per
   container, request `100m/64Mi` e limit `200m/128Mi`.
3. Esegui dry-run server-side, applica il Deployment e attendi due Pod Ready.
4. Verifica il consumo aggregato reale.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q11 - Pod count esaurito

Percorso: `~/course-resource-governance/01`.

1. Crea `pod-slot-test.yaml` per un Pod `pod-slot-test` conforme al
   `LimitRange`, con request `50m/64Mi` e limit `100m/128Mi`.
2. Tenta di crearlo e diagnostica il rifiuto.
3. Dimostra con `ResourceQuota` che il problema è il numero di Pod e non CPU o
   memoria.
4. Non eliminare workload per far passare il test.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q12 - Recupero di uno slot Pod

Percorso: `~/course-resource-governance/01`.

1. Elimina soltanto `defaulted-pod`.
2. Applica nuovamente `pod-slot-test.yaml`.
3. Verifica che il Pod sia Running e che la quota Pod sia nuovamente satura.
4. Elimina `pod-slot-test` al termine.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q13 - ConfigMap count

Percorso: `~/course-resource-governance/01`.

1. Applica `temporary-settings.yaml` e `worker-settings.yaml` in quest'ordine.
2. Diagnostica perché solo una delle due creazioni riesce.
3. Identifica gli oggetti che occupano la quota ConfigMap.
4. Elimina soltanto `temporary-settings`, crea `worker-settings` e verifica il
   nuovo valore `used`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q14 - Service negato

Percorso: `~/course-resource-governance/01`.

1. Esegui un dry-run server-side di `extra-service.yaml`.
2. Diagnostica il rifiuto e identifica i Service che occupano gli slot.
3. Verifica che selector e porta del manifest siano altrimenti validi.
4. Non eliminare `platform-api` e non applicare il Service.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q15 - Service senza endpoint

Percorso: `~/course-resource-governance/01`.

1. Ispeziona il Service headless `worker-headless` e i relativi EndpointSlice.
2. Diagnostica perché non produce endpoint pronti nonostante `batch-worker`
   sia disponibile.
3. Esporta il Service in `worker-headless.yaml`.
4. Correggi soltanto il selector, applica il file e verifica gli endpoint.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q16 - Rollout bloccato da resources mancanti

Percorso: `~/course-resource-governance/01`.

1. Applica `broken-rollout.yaml` e osserva il rollout parziale.
2. Ispeziona il Pod creato e individua request e limit aggiunti
   automaticamente.
3. Usa gli eventi del ReplicaSet e la quota per diagnosticare perché la
   seconda replica non viene creata.
4. Non eliminare il Deployment: conserva le evidenze per la correzione
   successiva.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q17 - Creazione entro il budget

Percorso: `~/course-resource-governance/01`.

1. Correggi `broken-rollout.yaml` dichiarando request `50m/64Mi` e limit
   `100m/128Mi`.
2. Applica il manifest e verifica che il nuovo ReplicaSet resti inizialmente
   con una sola replica.
3. Dimostra con quota ed eventi che il quinto Pod impedisce la seconda
   creazione.
4. Scala `batch-worker` a una replica senza modificarne il template e verifica
   che `diagnostic-worker` raggiunga due repliche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q18 - Drift delle risorse

Percorso: `~/course-resource-governance/01`.

1. Modifica nel cluster il Deployment `diagnostic-worker` impostando request
   CPU `300m` e limit CPU `500m`.
2. Osserva il rollout e diagnostica l'eventuale `FailedCreate` senza eliminare
   i Pod sani.
3. Ripristina il Deployment applicando `broken-rollout.yaml`.
4. Verifica che non restino ReplicaSet in errore attivo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q19 - Ripristino stato operativo

Percorso: `~/course-resource-governance/01`.

1. Elimina `worker-headless`, `worker-settings` e `diagnostic-worker`.
2. Riporta `batch-worker` a due repliche.
3. Attendi la riconciliazione e diagnostica qualsiasi Pod non Ready o evento
   di quota residuo.
4. Verifica che `platform-api` non abbia subito modifiche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

### Q20 - Verifica finale

Percorso: `~/course-resource-governance/01`.

1. Conferma che `platform-api` e `batch-worker` siano disponibili con due
   repliche ciascuno.
2. Verifica che non esistano Pod Pending o ReplicaSet con `FailedCreate`
   recente.
3. Registra valori `hard`, `used` e capacità residua di tutte le dimensioni
   della quota.
4. Completa `evidence.txt` con almeno un rifiuto `LimitRange`, un rifiuto
   `ResourceQuota`, una creazione corretta e una correzione di selector.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-resource-governance/01` prima di applicarli.

**Tip 2**

```bash
./create-resources.sh
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Pod senza resources

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f defaulted-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q2 - Manifest esplicito

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f explicit-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q3 - Request oltre il massimo

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f oversized-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q4 - Rapporto limit/request

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f burst-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q5 - Request sotto il minimo

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f below-minimum-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q6 - Errore nascosto nel sidecar

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f multi-container-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q7 - Limite aggiunto automaticamente

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f missing-limit-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q8 - Quota CPU esaurita

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f oversized-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q9 - ReplicaSet senza Pod

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f batch-worker.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q10 - Ridimensionamento del Deployment

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f batch-worker.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q11 - Pod count esaurito

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f pod-slot-test.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q12 - Recupero di uno slot Pod

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f pod-slot-test.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q13 - ConfigMap count

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f temporary-settings.yaml
kubectl apply -f worker-settings.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q14 - Service negato

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f extra-service.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q15 - Service senza endpoint

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f worker-headless.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q16 - Rollout bloccato da resources mancanti

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f broken-rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q17 - Creazione entro il budget

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f broken-rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q18 - Drift delle risorse

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl apply -f broken-rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q19 - Ripristino stato operativo

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```

---

### Soluzione Q20 - Verifica finale

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-resource-governance/01
./create-resources.sh
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
./remove-resources.sh
```
