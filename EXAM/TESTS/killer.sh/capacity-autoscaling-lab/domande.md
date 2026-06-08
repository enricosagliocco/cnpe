# Le 20 domande dell'esame — Capacity and Autoscaling Lab (simulatore lab)

Scenario creato da `setup-capacity-autoscaling-lab.sh`. Gli starter sono in
`~/course-capacity-autoscaling/`.

**Vincolo:** non modificare i Deployment installati dal setup e non
disinstallare Metrics Server, VPA o KEDA. Puoi modificare ResourceQuota,
LimitRange, VPA, HPA, ScaledObject e i Pod di test forniti.

Le domande sono progressive a gruppi di quattro. Applica ogni modifica e
salva le evidenze nei file presenti nella directory indicata.

---

### Q1 – Diagnosi ResourceQuota

Nel Namespace `quota-lab`, individua perché `quota-api` non raggiunge due
repliche. Analizza Deployment, ReplicaSet, eventi e quota e salva la causa in
`01/diagnosi.txt`.

### Q2 – Correzione ResourceQuota

Completa `01/resourcequota.yaml` con request `1 CPU/1Gi`, limit `2 CPU/2Gi` e
massimo `5` Pod. Applica il file senza riavviare il Deployment.

### Q3 – Accounting della quota

Verifica che `quota-api` diventi disponibile `2/2`. Registra hard, used,
request e limit effettivi in `01/diagnosi.txt`.

### Q4 – Test di saturazione quota

Prova a creare Pod aggiuntivi fino al superamento del limite. Documenta il
rifiuto admission e rimuovi soltanto i Pod di test.

---

### Q5 – Riproduzione errore LimitRange

Applica `02/pod.yaml`, acquisisci il messaggio di rifiuto e confronta
LimitRange e ResourceQuota in `limits-lab`.

### Q6 – Default request e limit

Correggi `02/limitrange.yaml` con request `100m/128Mi` e limit
`500m/512Mi`, senza modificare `02/pod.yaml`.

### Q7 – Limiti massimi container

Imposta nel LimitRange massimo `1 CPU/1Gi`. Applica il file e verifica che il
Pod riceva automaticamente request e limit.

### Q8 – Test positivo e negativo LimitRange

Dimostra che `defaults-demo` viene ammesso e che un Pod di test oltre il
massimo viene rifiutato. Salva entrambe le prove in `02/diagnosi.txt`.

---

### Q9 – Diagnosi VPA

Analizza `TargetRef`, condizioni ed eventi del VPA in `vpa-lab`. Registra
perché non produce raccomandazioni.

### Q10 – Correzione TargetRef VPA

Correggi `03/vpa.yaml` affinché punti al Deployment `recommendation-api`,
mantenendo `updateMode: "Off"` e i limiti min/max esistenti.

### Q11 – Lettura raccomandazioni VPA

Attendi una recommendation e salva target, lower bound, recommendation,
upper bound e uncapped target in `03/recommendation.txt`.

### Q12 – Verifica modalità recommendation-only

Dimostra che il VPA non modifica né ricrea i Pod. Spiega perché VPA e HPA CPU
non devono controllare contemporaneamente lo stesso workload.

---

### Q13 – Diagnosi HPA

Verifica metriche Pod e condizioni dello starter HPA in `hpa-lab`. Individua
target e configurazioni errate.

### Q14 – Configurazione HPA CPU

Correggi `04/hpa.yaml`: Deployment `hpa-api`, minimo `1`, massimo `5`, CPU
media target `50%`. Verifica che la metrica non sia `<unknown>`.

### Q15 – Scale-up sotto carico

Applica `04/load-generator.yaml`, osserva HPA e Deployment finché le repliche
superano uno e salva il massimo osservato in `04/result.txt`.

### Q16 – Stabilizzazione e scale-down

Elimina il generatore, osserva il ritorno al minimo e registra condizioni,
tempi e comportamento di stabilizzazione.

---

### Q17 – Diagnosi ScaledObject

In `keda-lab`, analizza condizioni, eventi e target dello ScaledObject.
Spiega perché `queue-worker` resta a zero.

### Q18 – Correzione KEDA

Correggi `05/scaledobject.yaml` per controllare `queue-worker`, con minimo
`0`, massimo `4`, timezone `Europe/Rome`, finestra `00:00–23:59` e desired
replicas `3`.

### Q19 – HPA gestito da KEDA

Identifica l'HPA generato automaticamente, verifica ownership e condizioni
`Ready=True` e `Active=True`. Non creare un secondo HPA.

### Q20 – Verifica finale autoscaling

Verifica quota, default, recommendation VPA, scale-up/down HPA e scaling KEDA:

```bash
kubectl -n quota-lab get resourcequota,deploy,pods
kubectl -n limits-lab get limitrange,resourcequota,pods
kubectl -n vpa-lab get vpa,deploy,pods
kubectl -n hpa-lab get hpa,deploy,pods
kubectl -n keda-lab get scaledobject,hpa,deploy,pods
```

Completa tutti i file di evidenza e conferma che nessun Deployment sia stato
modificato direttamente.
