# Platform Architecture and Efficiency Lab - 20 exam-style tasks

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
### Q1 - Diagnosi networking multi-tenant

Percorso: `~/course-platform-efficiency/01`.

1. Testa `tenant-a-client` e `tenant-b-client` verso `shared-api` e analizza
   le NetworkPolicy starter.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Ingress shared service

Percorso: `~/course-platform-efficiency/01`.

1. Consenti TCP 80 verso `shared-api` soltanto dal Namespace
   `tenant=tenant-a`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - Egress tenant-a

Percorso: `~/course-platform-efficiency/01`.

1. Consenti a tenant-a DNS UDP/TCP 53 e TCP 80 esclusivamente verso
   `shared-api`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Verifica isolamento

Percorso: `~/course-platform-efficiency/01`.

1. Dimostra tenant-a consentito, tenant-b negato ed egress esterno bloccato.

2. Salva in `01/connectivity.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Diagnosi storage locale

Percorso: `~/course-platform-efficiency/02`.

1. Analizza StorageClass, PV, PVC, Pod e topology dei Node in
   `02/storage.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/storage.yaml
```

---

### Q6 - StorageClass

Percorso: `~/course-platform-efficiency/02`.

1. Imposta `WaitForFirstConsumer`, reclaim `Retain` ed espansione
   disabilitata.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - PV e node affinity

Percorso: `~/course-platform-efficiency/02`.

1. Sostituisci `TODO_NODE` con un worker schedulabile e verifica affinity,
   capacità e access mode.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Binding e scheduling

Percorso: `~/course-platform-efficiency/02`.

1. Verifica PV/PVC Bound, Pod sul Node corretto e `/data/status`.

2. Documenta in `02/storage-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Diagnosi topology spread

Percorso: `~/course-platform-efficiency/03`.

1. Individua topology key errata e causa dello scheduling incompleto di
   `resilient-api`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 - Spread e anti-affinity

Percorso: `~/course-platform-efficiency/03`.

1. Usa `topology.kubernetes.io/zone`, maxSkew 1, DoNotSchedule e preferred
   anti-affinity hostname.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - PodDisruptionBudget

Percorso: `~/course-platform-efficiency/03`.

1. Imposta `minAvailable: 2` e verifica Deployment disponibile `3/3`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Test drain

Percorso: `~/course-platform-efficiency/03`.

1. Esegui drain di un worker, verifica due repliche disponibili, quindi
   uncordon e salva eventi in `03/scheduling.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Baseline OpenCost

Percorso: `~/course-platform-efficiency/04`.

1. Esporta l'allocazione tenant-a in `04/allocation-before.json` e analizza
   costi ed efficienza.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/allocation-before.json
```

---

### Q14 - Calcolo right-sizing

Percorso: `~/course-platform-efficiency/04`.

1. Da `04/usage.csv`, calcola request massimo +20%, arrotondamenti richiesti e
   limit doppi.

2. Scrivi in `04/calculation.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Applicazione right-sizing

Percorso: `~/course-platform-efficiency/04`.

1. Completa `04/right-sized-deployment.yaml`, mantenendo repliche e label
   `cost-center=payments`, quindi verifica il rollout.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/right-sized-deployment.yaml
```

---

### Q16 - Confronto costi

Percorso: `~/course-platform-efficiency/04`.

1. Esporta `04/allocation-after.json` e confronta request cost ed efficienza
   CPU/memory.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/allocation-after.json
```

---

### Q17 - Diagnosi quote tenant

Percorso: `~/course-platform-efficiency/05`.

1. Applica `05/workload.yaml`, osserva il Pod mancante e confronta quota
   generale e scoped quota.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 05/workload.yaml
```

---

### Q18 - ResourceQuota e LimitRange

Percorso: `~/course-platform-efficiency/05`.

1. Configura quota `2 CPU/2Gi` request, `4 CPU/4Gi` limit, 10 Pod, 3 PVC e
   default `100m/128Mi`, `500m/512Mi`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Scoped quota

Percorso: `~/course-platform-efficiency/05`.

1. Per `tenant-standard` consenti 4 Pod e request `1 CPU/1Gi`; verifica quinto
   Pod negato e Pod senza PriorityClass escluso.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 - Verifica finale efficienza

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-efficiency/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Diagnosi networking multi-tenant

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Ingress shared service

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - Egress tenant-a

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - Verifica isolamento

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - Diagnosi storage locale

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/02
kubectl apply -f 02/storage.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - StorageClass

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - PV e node affinity

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Binding e scheduling

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - Diagnosi topology spread

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - Spread e anti-affinity

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - PodDisruptionBudget

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - Test drain

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - Baseline OpenCost

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/04
kubectl apply -f 04/allocation-before.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Calcolo right-sizing

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - Applicazione right-sizing

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/04
kubectl apply -f 04/right-sized-deployment.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - Confronto costi

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/04
kubectl apply -f 04/allocation-after.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - Diagnosi quote tenant

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/05
kubectl apply -f 05/workload.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - ResourceQuota e LimitRange

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - Scoped quota

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - Verifica finale efficienza

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-efficiency/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
