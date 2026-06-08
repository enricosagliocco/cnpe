# Le 20 domande dell'esame — Platform Architecture and Efficiency Lab

Scenario creato da `setup-platform-efficiency-lab.sh`. Gli starter sono in
`~/course-platform-efficiency/`.

**Vincolo:** non modificare OpenCost o Prometheus, non rimuovere label
topology dai Node e non usare `nodeName`. Mantieni isolamento e limiti
distinti per tenant.

---

### Q1 – Diagnosi networking multi-tenant

Testa `tenant-a-client` e `tenant-b-client` verso `shared-api` e analizza le
NetworkPolicy starter.

### Q2 – Ingress shared service

Consenti TCP 80 verso `shared-api` soltanto dal Namespace
`tenant=tenant-a`.

### Q3 – Egress tenant-a

Consenti a tenant-a DNS UDP/TCP 53 e TCP 80 esclusivamente verso
`shared-api`.

### Q4 – Verifica isolamento

Dimostra tenant-a consentito, tenant-b negato ed egress esterno bloccato.
Salva in `01/connectivity.txt`.

---

### Q5 – Diagnosi storage locale

Analizza StorageClass, PV, PVC, Pod e topology dei Node in
`02/storage.yaml`.

### Q6 – StorageClass

Imposta `WaitForFirstConsumer`, reclaim `Retain` ed espansione disabilitata.

### Q7 – PV e node affinity

Sostituisci `TODO_NODE` con un worker schedulabile e verifica affinity,
capacità e access mode.

### Q8 – Binding e scheduling

Verifica PV/PVC Bound, Pod sul Node corretto e `/data/status`. Documenta in
`02/storage-check.txt`.

---

### Q9 – Diagnosi topology spread

Individua topology key errata e causa dello scheduling incompleto di
`resilient-api`.

### Q10 – Spread e anti-affinity

Usa `topology.kubernetes.io/zone`, maxSkew 1, DoNotSchedule e preferred
anti-affinity hostname.

### Q11 – PodDisruptionBudget

Imposta `minAvailable: 2` e verifica Deployment disponibile `3/3`.

### Q12 – Test drain

Esegui drain di un worker, verifica due repliche disponibili, quindi uncordon
e salva eventi in `03/scheduling.txt`.

---

### Q13 – Baseline OpenCost

Esporta l'allocazione tenant-a in `04/allocation-before.json` e analizza costi
ed efficienza.

### Q14 – Calcolo right-sizing

Da `04/usage.csv`, calcola request massimo +20%, arrotondamenti richiesti e
limit doppi. Scrivi in `04/calculation.txt`.

### Q15 – Applicazione right-sizing

Completa `04/right-sized-deployment.yaml`, mantenendo repliche e label
`cost-center=payments`, quindi verifica il rollout.

### Q16 – Confronto costi

Esporta `04/allocation-after.json` e confronta request cost ed efficienza
CPU/memory.

---

### Q17 – Diagnosi quote tenant

Applica `05/workload.yaml`, osserva il Pod mancante e confronta quota generale
e scoped quota.

### Q18 – ResourceQuota e LimitRange

Configura quota `2 CPU/2Gi` request, `4 CPU/4Gi` limit, 10 Pod, 3 PVC e
default `100m/128Mi`, `500m/512Mi`.

### Q19 – Scoped quota

Per `tenant-standard` consenti 4 Pod e request `1 CPU/1Gi`; verifica quinto
Pod negato e Pod senza PriorityClass escluso.

### Q20 – Verifica finale efficienza

```bash
kubectl get nodes -L topology.kubernetes.io/zone
kubectl -n shared-services get networkpolicy,svc,pods
kubectl -n architecture-lab get storageclass,pv,pvc,deploy,pods,pdb
kubectl -n tenant-a get resourcequota,limitrange,deploy,pods
kubectl -n opencost get pods,svc
```

Completa `05/tenant-checks.txt` verificando isolamento, resilienza,
right-sizing e accounting separato.
