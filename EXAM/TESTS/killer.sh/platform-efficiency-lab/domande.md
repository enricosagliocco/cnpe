# Le 20 domande dell'esame — Platform Architecture and Efficiency Lab (simulatore lab)

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

Scenario creato da `setup-platform-efficiency-lab.sh`. Gli starter sono in
`~/course-platform-efficiency/`.

**Vincolo:** non modificare OpenCost o Prometheus, non rimuovere label
topology dai Node e non usare `nodeName`. Mantieni isolamento e limiti
distinti per tenant.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 – Diagnosi networking multi-tenant
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/01`.

1. Testa `tenant-a-client` e `tenant-b-client` verso `shared-api` e analizza
   le NetworkPolicy starter.

### Q2 – Ingress shared service
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/01`.

1. Consenti TCP 80 verso `shared-api` soltanto dal Namespace
   `tenant=tenant-a`.

### Q3 – Egress tenant-a
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/01`.

1. Consenti a tenant-a DNS UDP/TCP 53 e TCP 80 esclusivamente verso
   `shared-api`.

### Q4 – Verifica isolamento
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/01`.

1. Dimostra tenant-a consentito, tenant-b negato ed egress esterno bloccato.

2. Salva in `01/connectivity.txt`.

---

### Q5 – Diagnosi storage locale
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/02`.

1. Analizza StorageClass, PV, PVC, Pod e topology dei Node in
   `02/storage.yaml`.

### Q6 – StorageClass
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/02`.

1. Imposta `WaitForFirstConsumer`, reclaim `Retain` ed espansione
   disabilitata.

### Q7 – PV e node affinity
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/02`.

1. Sostituisci `TODO_NODE` con un worker schedulabile e verifica affinity,
   capacità e access mode.

### Q8 – Binding e scheduling
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/02`.

1. Verifica PV/PVC Bound, Pod sul Node corretto e `/data/status`.

2. Documenta in `02/storage-check.txt`.

---

### Q9 – Diagnosi topology spread
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/03`.

1. Individua topology key errata e causa dello scheduling incompleto di
   `resilient-api`.

### Q10 – Spread e anti-affinity
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/03`.

1. Usa `topology.kubernetes.io/zone`, maxSkew 1, DoNotSchedule e preferred
   anti-affinity hostname.

### Q11 – PodDisruptionBudget
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/03`.

1. Imposta `minAvailable: 2` e verifica Deployment disponibile `3/3`.

### Q12 – Test drain
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/03`.

1. Esegui drain di un worker, verifica due repliche disponibili, quindi
   uncordon e salva eventi in `03/scheduling.txt`.

---

### Q13 – Baseline OpenCost
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/04`.

1. Esporta l'allocazione tenant-a in `04/allocation-before.json` e analizza
   costi ed efficienza.

### Q14 – Calcolo right-sizing
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/04`.

1. Da `04/usage.csv`, calcola request massimo +20%, arrotondamenti richiesti e
   limit doppi.

2. Scrivi in `04/calculation.txt`.

### Q15 – Applicazione right-sizing
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/04`.

1. Completa `04/right-sized-deployment.yaml`, mantenendo repliche e label
   `cost-center=payments`, quindi verifica il rollout.

### Q16 – Confronto costi
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/04`.

1. Esporta `04/allocation-after.json` e confronta request cost ed efficienza
   CPU/memory.

---

### Q17 – Diagnosi quote tenant
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/05`.

1. Applica `05/workload.yaml`, osserva il Pod mancante e confronta quota
   generale e scoped quota.

### Q18 – ResourceQuota e LimitRange
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/05`.

1. Configura quota `2 CPU/2Gi` request, `4 CPU/4Gi` limit, 10 Pod, 3 PVC e
   default `100m/128Mi`, `500m/512Mi`.

### Q19 – Scoped quota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/05`.

1. Per `tenant-standard` consenti 4 Pod e request `1 CPU/1Gi`; verifica quinto
   Pod negato e Pod senza PriorityClass escluso.

### Q20 – Verifica finale efficienza
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-efficiency/05`.

```bash
kubectl get nodes -L topology.kubernetes.io/zone
kubectl -n shared-services get networkpolicy,svc,pods
kubectl -n architecture-lab get storageclass,pv,pvc,deploy,pods,pdb
kubectl -n tenant-a get resourcequota,limitrange,deploy,pods
kubectl -n opencost get pods,svc
```

1. Completa `05/tenant-checks.txt` verificando isolamento, resilienza,
   right-sizing e accounting separato.
