# Le 20 domande dell'esame - Resource Governance Troubleshooting Lab

Lo script `setup-resource-quota-limitrange-lab.sh` genera soltanto i file del
corso: non crea cluster e non applica risorse. Ogni domanda usa una cartella
indipendente `~/course-resource-governance/qNN/`; tutte le risorse devono
essere create nel Namespace `resource-governance`.

Il laboratorio simula una coda di incidenti. Per ogni domanda devi tentare
l'operazione richiesta, osservare il sintomo, identificare la causa, applicare
la correzione minima e verificarne l'esito.

Vincoli:

- all'inizio eseguire `./create-resources.sh`;
- alla fine eseguire `./remove-resources.sh`, anche dopo una prova fallita;
- non modificare o eliminare il Deployment e il Service `platform-api`;
- non modificare o eliminare `ResourceQuota` e `LimitRange`;
- non aumentare la quota per aggirare un errore;
- non eliminare risorse estranee all'incidente corrente;
- usare il dry-run server-side quando richiesto;
- salvare comandi, errori e verifiche in `evidence.txt`.

---

### Q1 - Pod senza resources

Percorso: `~/course-resource-governance/01`.

1. Applica `defaulted-pod.yaml`.
2. Verifica che il Pod venga creato ma che request e limit non corrispondano a
   valori dichiarati nel file.
3. Individua quale risorsa di admission li ha aggiunti.
4. Registra valori effettivi e stato del Pod in `evidence.txt`.

### Q2 - Manifest esplicito

Percorso: `~/course-resource-governance/01`.

1. Crea `explicit-pod.yaml` per un Pod `explicit-pod` con immagine
   `nginx:1.27-alpine`.
2. Dichiara request `cpu: 100m`, `memory: 64Mi` e limit `cpu: 200m`,
   `memory: 128Mi`.
3. Esegui un dry-run server-side, crea il Pod e verifica che i valori non
   vengano modificati.
4. Elimina `explicit-pod` dopo la verifica.

### Q3 - Request oltre il massimo

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `oversized-pod.yaml`.
2. Usa il messaggio di admission per individuare container, risorsa e soglia
   violata.
3. Correggi solo CPU request e limit portandoli al massimo consentito.
4. Ripeti il dry-run fino a ottenere esito positivo, senza creare il Pod.

### Q4 - Rapporto limit/request

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `burst-pod.yaml`.
2. Calcola il rapporto CPU configurato e ricava dal cluster quello ammesso.
3. Correggi soltanto il limit CPU usando il valore massimo valido.
4. Verifica con dry-run server-side senza creare il Pod.

### Q5 - Request sotto il minimo

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `below-minimum-pod.yaml`.
2. Identifica il minimo CPU richiesto dal `LimitRange`.
3. Correggi soltanto la request CPU con il minimo consentito.
4. Crea il Pod, verifica le risorse effettive e poi eliminalo.

### Q6 - Errore nascosto nel sidecar

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `multi-container-pod.yaml`.
2. Individua quale dei due container viola il `LimitRange`; non correggere il
   container già conforme.
3. Correggi il rapporto CPU del solo sidecar.
4. Crea il Pod, verifica entrambi i container e poi eliminalo.

### Q7 - Limite aggiunto automaticamente

Percorso: `~/course-resource-governance/01`.

1. Tenta la creazione server-side di `missing-limit-pod.yaml`.
2. Confronta l'output YAML del dry-run con il file originale.
3. Individua il limit aggiunto dal `LimitRange` e verifica che il rapporto
   risultante sia valido.
4. Crea il Pod e registra request e limit osservati.

### Q8 - Quota CPU esaurita

Percorso: `~/course-resource-governance/01`.

1. Tenta di applicare `oversized-pod.yaml`, già corretto in Q3.
2. Diagnostica il nuovo rifiuto, distinguendolo dall'errore di `LimitRange`.
3. Identifica quali Pod consumano la quota CPU.
4. Elimina soltanto `missing-limit-pod`, riprova la creazione e verifica che
   `oversized-pod` sia Running.

### Q9 - ReplicaSet senza Pod

Percorso: `~/course-resource-governance/01`.

1. Applica `batch-worker.yaml`.
2. Diagnostica perché il Deployment esiste ma non raggiunge due repliche.
3. Usa eventi di Deployment e ReplicaSet per dimostrare il rifiuto da parte
   della quota.
4. Elimina `batch-worker` e verifica che non restino Pod associati.

### Q10 - Ridimensionamento del Deployment

Percorso: `~/course-resource-governance/01`.

1. Elimina `oversized-pod` per liberare il budget usato nel test precedente.
2. Correggi `batch-worker.yaml` mantenendo due repliche e impostando, per
   container, request `100m/64Mi` e limit `200m/128Mi`.
3. Esegui dry-run server-side, applica il Deployment e attendi due Pod Ready.
4. Verifica il consumo aggregato reale.

### Q11 - Pod count esaurito

Percorso: `~/course-resource-governance/01`.

1. Crea `pod-slot-test.yaml` per un Pod `pod-slot-test` conforme al
   `LimitRange`, con request `50m/64Mi` e limit `100m/128Mi`.
2. Tenta di crearlo e diagnostica il rifiuto.
3. Dimostra con `ResourceQuota` che il problema è il numero di Pod e non CPU o
   memoria.
4. Non eliminare workload per far passare il test.

### Q12 - Recupero di uno slot Pod

Percorso: `~/course-resource-governance/01`.

1. Elimina soltanto `defaulted-pod`.
2. Applica nuovamente `pod-slot-test.yaml`.
3. Verifica che il Pod sia Running e che la quota Pod sia nuovamente satura.
4. Elimina `pod-slot-test` al termine.

### Q13 - ConfigMap count

Percorso: `~/course-resource-governance/01`.

1. Applica `temporary-settings.yaml` e `worker-settings.yaml` in quest'ordine.
2. Diagnostica perché solo una delle due creazioni riesce.
3. Identifica gli oggetti che occupano la quota ConfigMap.
4. Elimina soltanto `temporary-settings`, crea `worker-settings` e verifica il
   nuovo valore `used`.

### Q14 - Service negato

Percorso: `~/course-resource-governance/01`.

1. Esegui un dry-run server-side di `extra-service.yaml`.
2. Diagnostica il rifiuto e identifica i Service che occupano gli slot.
3. Verifica che selector e porta del manifest siano altrimenti validi.
4. Non eliminare `platform-api` e non applicare il Service.

### Q15 - Service senza endpoint

Percorso: `~/course-resource-governance/01`.

1. Ispeziona il Service headless `worker-headless` e i relativi EndpointSlice.
2. Diagnostica perché non produce endpoint pronti nonostante `batch-worker`
   sia disponibile.
3. Esporta il Service in `worker-headless.yaml`.
4. Correggi soltanto il selector, applica il file e verifica gli endpoint.

### Q16 - Rollout bloccato da resources mancanti

Percorso: `~/course-resource-governance/01`.

1. Applica `broken-rollout.yaml` e osserva il rollout parziale.
2. Ispeziona il Pod creato e individua request e limit aggiunti
   automaticamente.
3. Usa gli eventi del ReplicaSet e la quota per diagnosticare perché la
   seconda replica non viene creata.
4. Non eliminare il Deployment: conserva le evidenze per la correzione
   successiva.

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

### Q18 - Drift delle risorse

Percorso: `~/course-resource-governance/01`.

1. Modifica nel cluster il Deployment `diagnostic-worker` impostando request
   CPU `300m` e limit CPU `500m`.
2. Osserva il rollout e diagnostica l'eventuale `FailedCreate` senza eliminare
   i Pod sani.
3. Ripristina il Deployment applicando `broken-rollout.yaml`.
4. Verifica che non restino ReplicaSet in errore attivo.

### Q19 - Ripristino stato operativo

Percorso: `~/course-resource-governance/01`.

1. Elimina `worker-headless`, `worker-settings` e `diagnostic-worker`.
2. Riporta `batch-worker` a due repliche.
3. Attendi la riconciliazione e diagnostica qualsiasi Pod non Ready o evento
   di quota residuo.
4. Verifica che `platform-api` non abbia subito modifiche.

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
