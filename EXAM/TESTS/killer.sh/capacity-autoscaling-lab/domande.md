# Le 20 domande dell'esame — Capacity and Autoscaling Lab (simulatore lab)

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

Scenario creato da `setup-capacity-autoscaling-lab.sh`. Gli starter sono in
`~/course-capacity-autoscaling/`.

**Vincolo:** non modificare i Deployment installati dal setup e non
disinstallare Metrics Server, VPA o KEDA. Puoi modificare ResourceQuota,
LimitRange, VPA, HPA, ScaledObject e i Pod di test forniti.

Le domande sono progressive a gruppi di quattro. Applica ogni modifica e
salva le evidenze nei file presenti nella directory indicata.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 – Diagnosi ResourceQuota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/01`.

1. Nel Namespace `quota-lab`, individua perché `quota-api` non raggiunge due
   repliche.

2. Analizza Deployment, ReplicaSet, eventi e quota e salva la causa in
   `01/diagnosi.txt`.

### Q2 – Correzione ResourceQuota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/01`.

1. Completa `01/resourcequota.yaml` con request `1 CPU/1Gi`, limit `2 CPU/2Gi`
   e massimo `5` Pod.

2. Applica il file senza riavviare il Deployment.

### Q3 – Accounting della quota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/01`.

1. Verifica che `quota-api` diventi disponibile `2/2`.

2. Registra hard, used, request e limit effettivi in `01/diagnosi.txt`.

### Q4 – Test di saturazione quota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/01`.

1. Prova a creare Pod aggiuntivi fino al superamento del limite.

2. Documenta il rifiuto admission e rimuovi soltanto i Pod di test.

---

### Q5 – Riproduzione errore LimitRange
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/02`.

1. Applica `02/pod.yaml`, acquisisci il messaggio di rifiuto e confronta
   LimitRange e ResourceQuota in `limits-lab`.

### Q6 – Default request e limit
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/02`.

1. Correggi `02/limitrange.yaml` con request `100m/128Mi` e limit
   `500m/512Mi`, senza modificare `02/pod.yaml`.

### Q7 – Limiti massimi container
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/02`.

1. Imposta nel LimitRange massimo `1 CPU/1Gi`.

2. Applica il file e verifica che il Pod riceva automaticamente request e
   limit.

### Q8 – Test positivo e negativo LimitRange
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/02`.

1. Dimostra che `defaults-demo` viene ammesso e che un Pod di test oltre il
   massimo viene rifiutato.

2. Salva entrambe le prove in `02/diagnosi.txt`.

---

### Q9 – Diagnosi VPA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/03`.

1. Analizza `TargetRef`, condizioni ed eventi del VPA in `vpa-lab`.

2. Registra perché non produce raccomandazioni.

### Q10 – Correzione TargetRef VPA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/03`.

1. Correggi `03/vpa.yaml` affinché punti al Deployment `recommendation-api`,
   mantenendo `updateMode: "Off"` e i limiti min/max esistenti.

### Q11 – Lettura raccomandazioni VPA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/03`.

1. Attendi una recommendation e salva target, lower bound, recommendation,
   upper bound e uncapped target in `03/recommendation.txt`.

### Q12 – Verifica modalità recommendation-only
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/03`.

1. Dimostra che il VPA non modifica né ricrea i Pod.

2. Spiega perché VPA e HPA CPU non devono controllare contemporaneamente lo
   stesso workload.

---

### Q13 – Diagnosi HPA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/04`.

1. Verifica metriche Pod e condizioni dello starter HPA in `hpa-lab`.

2. Individua target e configurazioni errate.

### Q14 – Configurazione HPA CPU
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/04`.

1. Correggi `04/hpa.yaml`: Deployment `hpa-api`, minimo `1`, massimo `5`, CPU
   media target `50%`.

2. Verifica che la metrica non sia `<unknown>`.

### Q15 – Scale-up sotto carico
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/04`.

1. Applica `04/load-generator.yaml`, osserva HPA e Deployment finché le
   repliche superano uno e salva il massimo osservato in `04/result.txt`.

### Q16 – Stabilizzazione e scale-down
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/04`.

1. Elimina il generatore, osserva il ritorno al minimo e registra condizioni,
   tempi e comportamento di stabilizzazione.

---

### Q17 – Diagnosi ScaledObject
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/05`.

1. In `keda-lab`, analizza condizioni, eventi e target dello ScaledObject.

2. Spiega perché `queue-worker` resta a zero.

### Q18 – Correzione KEDA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/05`.

1. Correggi `05/scaledobject.yaml` per controllare `queue-worker`, con minimo
   `0`, massimo `4`, timezone `Europe/Rome`, finestra `00:00–23:59` e desired
   replicas `3`.

### Q19 – HPA gestito da KEDA
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/05`.

1. Identifica l'HPA generato automaticamente, verifica ownership e condizioni
   `Ready=True` e `Active=True`.

2. Non creare un secondo HPA.

### Q20 – Verifica finale autoscaling
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-capacity-autoscaling/05`.

1. Verifica quota, default, recommendation VPA, scale-up/down HPA e scaling
   KEDA:

```bash
kubectl -n quota-lab get resourcequota,deploy,pods
kubectl -n limits-lab get limitrange,resourcequota,pods
kubectl -n vpa-lab get vpa,deploy,pods
kubectl -n hpa-lab get hpa,deploy,pods
kubectl -n keda-lab get scaledobject,hpa,deploy,pods
```

2. Completa tutti i file di evidenza e conferma che nessun Deployment sia
   stato modificato direttamente.
