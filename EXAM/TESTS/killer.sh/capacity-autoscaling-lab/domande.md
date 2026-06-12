# Capacity and Autoscaling Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
Le soluzioni sono raccolte nella sezione finale del documento.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 – Diagnosi ResourceQuota

Percorso: `~/course-capacity-autoscaling/01`.

1. Nel Namespace `quota-lab`, individua perché `quota-api` non raggiunge due
   repliche.

2. Analizza Deployment, ReplicaSet, eventi e quota e salva la causa in
   `01/diagnosi.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 – Correzione ResourceQuota

Percorso: `~/course-capacity-autoscaling/01`.

1. Completa `01/resourcequota.yaml` con request `1 CPU/1Gi`, limit `2 CPU/2Gi`
   e massimo `5` Pod.

2. Applica il file senza riavviare il Deployment.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 01/resourcequota.yaml
```

---

### Q3 – Accounting della quota

Percorso: `~/course-capacity-autoscaling/01`.

1. Verifica che `quota-api` diventi disponibile `2/2`.

2. Registra hard, used, request e limit effettivi in `01/diagnosi.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 – Test di saturazione quota

Percorso: `~/course-capacity-autoscaling/01`.

1. Prova a creare Pod aggiuntivi fino al superamento del limite.

2. Documenta il rifiuto admission e rimuovi soltanto i Pod di test.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 – Riproduzione errore LimitRange

Percorso: `~/course-capacity-autoscaling/02`.

1. Applica `02/pod.yaml`, acquisisci il messaggio di rifiuto e confronta
   LimitRange e ResourceQuota in `limits-lab`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/pod.yaml
```

---

### Q6 – Default request e limit

Percorso: `~/course-capacity-autoscaling/02`.

1. Correggi `02/limitrange.yaml` con request `100m/128Mi` e limit
   `500m/512Mi`, senza modificare `02/pod.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/limitrange.yaml
```

---

### Q7 – Limiti massimi container

Percorso: `~/course-capacity-autoscaling/02`.

1. Imposta nel LimitRange massimo `1 CPU/1Gi`.

2. Applica il file e verifica che il Pod riceva automaticamente request e
   limit.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 – Test positivo e negativo LimitRange

Percorso: `~/course-capacity-autoscaling/02`.

1. Dimostra che `defaults-demo` viene ammesso e che un Pod di test oltre il
   massimo viene rifiutato.

2. Salva entrambe le prove in `02/diagnosi.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 – Diagnosi VPA

Percorso: `~/course-capacity-autoscaling/03`.

1. Analizza `TargetRef`, condizioni ed eventi del VPA in `vpa-lab`.

2. Registra perché non produce raccomandazioni.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 – Correzione TargetRef VPA

Percorso: `~/course-capacity-autoscaling/03`.

1. Correggi `03/vpa.yaml` affinché punti al Deployment `recommendation-api`,
   mantenendo `updateMode: "Off"` e i limiti min/max esistenti.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/vpa.yaml
```

---

### Q11 – Lettura raccomandazioni VPA

Percorso: `~/course-capacity-autoscaling/03`.

1. Attendi una recommendation e salva target, lower bound, recommendation,
   upper bound e uncapped target in `03/recommendation.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 – Verifica modalità recommendation-only

Percorso: `~/course-capacity-autoscaling/03`.

1. Dimostra che il VPA non modifica né ricrea i Pod.

2. Spiega perché VPA e HPA CPU non devono controllare contemporaneamente lo
   stesso workload.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 – Diagnosi HPA

Percorso: `~/course-capacity-autoscaling/04`.

1. Verifica metriche Pod e condizioni dello starter HPA in `hpa-lab`.

2. Individua target e configurazioni errate.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 – Configurazione HPA CPU

Percorso: `~/course-capacity-autoscaling/04`.

1. Correggi `04/hpa.yaml`: Deployment `hpa-api`, minimo `1`, massimo `5`, CPU
   media target `50%`.

2. Verifica che la metrica non sia `<unknown>`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/hpa.yaml
```

---

### Q15 – Scale-up sotto carico

Percorso: `~/course-capacity-autoscaling/04`.

1. Applica `04/load-generator.yaml`, osserva HPA e Deployment finché le
   repliche superano uno e salva il massimo osservato in `04/result.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/load-generator.yaml
```

---

### Q16 – Stabilizzazione e scale-down

Percorso: `~/course-capacity-autoscaling/04`.

1. Elimina il generatore, osserva il ritorno al minimo e registra condizioni,
   tempi e comportamento di stabilizzazione.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 – Diagnosi ScaledObject

Percorso: `~/course-capacity-autoscaling/05`.

1. In `keda-lab`, analizza condizioni, eventi e target dello ScaledObject.

2. Spiega perché `queue-worker` resta a zero.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 – Correzione KEDA

Percorso: `~/course-capacity-autoscaling/05`.

1. Correggi `05/scaledobject.yaml` per controllare `queue-worker`, con minimo
   `0`, massimo `4`, timezone `Europe/Rome`, finestra `00:00–23:59` e desired
   replicas `3`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 05/scaledobject.yaml
```

---

### Q19 – HPA gestito da KEDA

Percorso: `~/course-capacity-autoscaling/05`.

1. Identifica l'HPA generato automaticamente, verifica ownership e condizioni
   `Ready=True` e `Active=True`.

2. Non creare un secondo HPA.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 – Verifica finale autoscaling

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-capacity-autoscaling/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Diagnosi ResourceQuota

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Correzione ResourceQuota

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/01
kubectl apply -f 01/resourcequota.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - Accounting della quota

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - Test di saturazione quota

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - Riproduzione errore LimitRange

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/02
kubectl apply -f 02/pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - Default request e limit

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/02
kubectl apply -f 02/limitrange.yaml
kubectl apply -f 02/pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - Limiti massimi container

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Test positivo e negativo LimitRange

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - Diagnosi VPA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - Correzione TargetRef VPA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/03
kubectl apply -f 03/vpa.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - Lettura raccomandazioni VPA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - Verifica modalità recommendation-only

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - Diagnosi HPA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Configurazione HPA CPU

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/04
kubectl apply -f 04/hpa.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - Scale-up sotto carico

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/04
kubectl apply -f 04/load-generator.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - Stabilizzazione e scale-down

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - Diagnosi ScaledObject

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - Correzione KEDA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/05
kubectl apply -f 05/scaledobject.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - HPA gestito da KEDA

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - Verifica finale autoscaling

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-capacity-autoscaling/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
