# Le 20 domande dell'esame - ResourceQuota e LimitRange Lab

Scenario creato da `setup-resource-quota-limitrange-lab.sh`. I manifest
modificabili si trovano in `~/course-resource-governance/01/`; le risorse sono
nel Namespace `resource-governance`.

Vincoli:

- non modificare o eliminare il Deployment `platform-api`;
- non eliminare `ResourceQuota` o `LimitRange`;
- correggere soltanto i file starter indicati;
- usare il dry-run server-side quando richiesto;
- salvare comandi, errori e risultati in `01/evidence.txt`.

---

### Q1 - Inventario iniziale

Percorso: `~/course-resource-governance/01`.

1. Elenca Pod, Deployment, Service, ConfigMap, ResourceQuota e LimitRange.
2. Registra stato e risorse richieste dal Deployment `platform-api`.
3. Non effettuare modifiche.

### Q2 - Analisi del ResourceQuota

Percorso: `~/course-resource-governance/01`.

1. Descrivi `team-budget`.
2. Registra valori `hard` e `used` per CPU, memoria, Pod, Service e ConfigMap.
3. Calcola la capacità residua per ogni risorsa.

### Q3 - Analisi del LimitRange

Percorso: `~/course-resource-governance/01`.

1. Descrivi `container-policy`.
2. Identifica default request, default limit, minimo, massimo e
   `maxLimitRequestRatio`.
3. Spiega che la validazione avviene per singolo container.

### Q4 - Correlazione admission

Percorso: `~/course-resource-governance/01`.

1. Spiega l'ordine logico tra defaulting del LimitRange, validazione dei
   container e controllo aggregato del ResourceQuota.
2. Prevedi le risorse assegnate a un container che non dichiara `resources`.
3. Salva la previsione in `evidence.txt`.

---

### Q5 - Default automatici

Percorso: `~/course-resource-governance/01`.

1. Applica `defaulted-pod.yaml`.
2. Ispeziona il Pod creato e registra request e limit effettivi.
3. Confrontali con i default del LimitRange.

### Q6 - Aggiornamento della quota usata

Percorso: `~/course-resource-governance/01`.

1. Attendi l'aggiornamento di `team-budget`.
2. Registra il nuovo consumo di Pod, CPU e memoria.
3. Calcola nuovamente la capacità residua.

### Q7 - Superamento del massimo

Percorso: `~/course-resource-governance/01`.

1. Esegui un dry-run server-side di `oversized-pod.yaml`.
2. Identifica il campo che supera il massimo imposto dal LimitRange.
3. Registra integralmente il messaggio di admission.

### Q8 - Correzione del massimo

Percorso: `~/course-resource-governance/01`.

1. Correggi `oversized-pod.yaml` impostando request CPU non superiore a
   `500m` e limit CPU non superiore a `500m`.
2. Mantieni memoria e immagine invariate.
3. Verifica con dry-run server-side che il manifest superi il LimitRange.
4. Non creare ancora il Pod.

---

### Q9 - Rapporto limit/request

Percorso: `~/course-resource-governance/01`.

1. Esegui un dry-run server-side di `burst-pod.yaml`.
2. Calcola il rapporto CPU limit/request.
3. Identifica il rapporto massimo consentito e registra il rifiuto.

### Q10 - Correzione del rapporto

Percorso: `~/course-resource-governance/01`.

1. Correggi soltanto il limit CPU di `burst-pod.yaml`.
2. Mantieni request CPU a `100m`.
3. Usa il limit massimo ammesso dal rapporto.
4. Conferma con dry-run server-side che il manifest sia valido.

### Q11 - Quota aggregata del Deployment

Percorso: `~/course-resource-governance/01`.

1. Applica `batch-worker.yaml` e attendi la riconciliazione del ReplicaSet.
2. Distingui le risorse per replica dal consumo totale delle due repliche.
3. Descrivi Deployment e ReplicaSet e identifica l'evento `FailedCreate`
   causato dalla quota aggregata.
4. Elimina il Deployment `batch-worker` dopo aver raccolto le evidenze.
5. Verifica che i relativi Pod siano stati rimossi.

### Q12 - Dimensionamento entro budget

Percorso: `~/course-resource-governance/01`.

1. Correggi `batch-worker.yaml` mantenendo due repliche.
2. Imposta per container request `cpu: 100m`, `memory: 64Mi`.
3. Imposta limit `cpu: 200m`, `memory: 128Mi`.
4. Verifica il manifest con dry-run server-side senza applicarlo.

---

### Q13 - Quota dei ConfigMap

Percorso: `~/course-resource-governance/01`.

1. Conta i ConfigMap presenti escludendo quelli di sistema fuori Namespace.
2. Applica prima `temporary-settings.yaml`, poi `worker-settings.yaml`.
3. Identifica quale oggetto viene accettato e quale supera la quota.
4. Registra l'errore e lo stato aggiornato di `team-budget`.

### Q14 - Recupero object count

Percorso: `~/course-resource-governance/01`.

1. Elimina soltanto il ConfigMap `temporary-settings`.
2. Applica nuovamente `worker-settings.yaml`.
3. Verifica che il numero usato resti entro `configmaps: 3`.

### Q15 - Quota dei Service

Percorso: `~/course-resource-governance/01`.

1. Esegui un dry-run server-side di `extra-service.yaml`.
2. Identifica la quota per numero di Service che impedisce la creazione.
3. Non eliminare il Service `platform-api`.

### Q16 - Scelta operativa

Percorso: `~/course-resource-governance/01`.

1. Spiega perché aumentare una quota e ridurre il consumo sono decisioni
   diverse, non semplici correzioni sintattiche.
2. Non modificare `team-budget`.
3. Lascia `extra-service.yaml` non applicato e registra la decisione.

---

### Q17 - Applicazione del worker

Percorso: `~/course-resource-governance/01`.

1. Applica il `batch-worker.yaml` corretto.
2. Attendi due Pod Ready.
3. Verifica request e limit effettivi su entrambi i Pod.

### Q18 - Stato finale della quota

Percorso: `~/course-resource-governance/01`.

1. Attendi la riconciliazione di `team-budget`.
2. Registra `hard`, `used` e capacità residua.
3. Conferma che nessun valore `used` superi il corrispondente `hard`.

### Q19 - Test negativo finale

Percorso: `~/course-resource-governance/01`.

1. Riesegui il dry-run server-side di `extra-service.yaml`.
2. Conferma che il rifiuto sia ancora dovuto alla quota Service.
3. Verifica che il rifiuto non abbia creato oggetti parziali.

### Q20 - Evidenza conclusiva

Percorso: `~/course-resource-governance/01`.

1. Conferma `platform-api` e `batch-worker` disponibili.
2. Conferma che `defaulted-pod` sia Running.
3. Riassumi in `evidence.txt` un caso di defaulting, un rifiuto LimitRange, un
   rifiuto ResourceQuota e lo stato finale conforme.
4. Includi i comandi usati e i relativi output essenziali.
