# CNPE Platform Architecture and Efficiency Lab

Scenario creato da `setup-platform-efficiency-lab.sh`. Gli starter sono in
`~/course-platform-efficiency/`.

## Vincoli d'esame

- Non modificare i componenti OpenCost o Prometheus.
- Non rimuovere label topology dai Node.
- Non usare `nodeName` nei workload.
- Mantieni isolamento e limiti distinti per ciascun tenant.
- Ogni modifica deve essere verificata sul cluster, non soltanto validata
  come YAML.

---

### Q1 – Networking multi-tenant

Il Service `shared-api.shared-services.svc` deve essere raggiungibile da
`tenant-a`, ma non da `tenant-b`. Le NetworkPolicy starter bloccano tutto.

Completa `01/network-policies.yaml`:

1. consenti ingress TCP 80 verso `shared-api` soltanto dai Pod del Namespace
   con label `tenant=tenant-a`;
2. nel Namespace `tenant-a`, consenti egress:
   - DNS UDP/TCP 53 verso `kube-system`;
   - TCP 80 verso `shared-services` e i Pod `app=shared-api`;
3. non consentire altro egress dai Pod di tenant-a.

Verifica:

- `tenant-a-client` risolve il DNS e riceve risposta HTTP;
- `tenant-b-client` non raggiunge il Service;
- tenant-a non raggiunge endpoint esterni non consentiti.

Salva comandi e risultati in `01/connectivity.txt`.

---

### Q2 – Storage architecture

Completa `02/storage.yaml` applicando le best practice per volumi locali:

1. StorageClass `architecture-local` con:
   - provisioner `kubernetes.io/no-provisioner`;
   - `volumeBindingMode: WaitForFirstConsumer`;
   - reclaim policy `Retain`;
   - `allowVolumeExpansion: false`, perché il provisioner statico locale non
     implementa l'espansione;
2. sostituisci `TODO_NODE` con il nome di un Node worker schedulabile;
3. applica StorageClass, PV, PVC e Pod;
4. verifica PVC e PV `Bound`;
5. verifica che il Pod sia schedulato sul Node indicato dalla node affinity;
6. verifica il contenuto `/data/status`.

Spiega in `02/storage-check.txt` perché `WaitForFirstConsumer` evita decisioni
di binding incompatibili con lo scheduling e perché `Retain` è appropriato
per dati persistenti.

---

### Q3 – Compute resilience e scheduling

Il Deployment `resilient-api` richiede tre repliche, ma usa una topology key
inesistente. Il PDB inoltre impedisce qualsiasi disruption volontaria.

Correggi `03/compute.yaml`:

1. distribuisci i Pod usando `topology.kubernetes.io/zone`;
2. mantieni `maxSkew: 1` e `DoNotSchedule`;
3. aggiungi preferred pod anti-affinity su `kubernetes.io/hostname`;
4. imposta il PDB con `minAvailable: 2`.

Verifica:

- Deployment disponibile `3/3`;
- Pod distribuiti tra le zone disponibili;
- skew massimo pari a uno;
- un drain di un Node worker rispetta il PDB e mantiene almeno due repliche
  disponibili;
- dopo `uncordon`, il Deployment torna allo stato atteso.

Salva distribuzione, eventi e risultato del drain in `03/scheduling.txt`.

---

### Q4 – OpenCost e right-sizing

Il Deployment `overprovisioned-api` richiede molte più risorse rispetto ai
campioni in `04/usage.csv`.

1. Accedi all'API OpenCost:

   ```bash
   kubectl -n opencost port-forward svc/opencost 9003:9003
   ```

2. Esporta l'allocazione del Namespace `tenant-a` in
   `04/allocation-before.json`.
3. Calcola:
   - request CPU uguale al valore massimo osservato più 20%, arrotondato ai
     10m superiori;
   - request memory uguale al massimo più 20%, arrotondato ai 16Mi superiori;
   - limit CPU e memory pari a due volte le request.
4. Documenta il calcolo in `04/calculation.txt`.
5. Completa e applica `04/right-sized-deployment.yaml`.
6. Attendi il rollout e verifica le risorse nei Pod.
7. Dopo una nuova finestra di raccolta, esporta l'allocazione in
   `04/allocation-after.json`.
8. Confronta request cost, efficienza CPU/memory e costo allocato.

Non ridurre le repliche e non rimuovere la label `cost-center=payments`.

---

### Q5 – Ottimizzazione multi-tenancy

Il Namespace `tenant-a` non ha limiti generali né default per container. La
quota associata alla PriorityClass `tenant-standard` consente un solo Pod,
quindi il Deployment `tenant-worker` non può raggiungere due repliche.

1. Applica inizialmente `05/workload.yaml` e verifica che venga creato un solo
   Pod.
2. Elimina il Deployment di test prima di applicare i controlli corretti.

Completa `05/tenant-controls.yaml`:

3. ResourceQuota generale:
   - requests.cpu `2`;
   - requests.memory `2Gi`;
   - limits.cpu `4`;
   - limits.memory `4Gi`;
   - pods `10`;
   - PVC `3`;
4. LimitRange:
   - default request `100m/128Mi`;
   - default limit `500m/512Mi`;
   - massimo container `2 CPU/2Gi`;
5. quota scoped alla PriorityClass `tenant-standard`:
   - pods `4`;
   - requests.cpu `1`;
   - requests.memory `1Gi`.

Applica i controlli e quindi ricrea `05/workload.yaml`.

Verifica:

- Deployment disponibile `2/2`;
- request e limit inseriti automaticamente;
- quota generale e quota scoped contabilizzano i Pod;
- un quinto Pod con `tenant-standard` viene rifiutato;
- un Pod senza PriorityClass non consuma la quota scoped;
- tenant-b non consuma le quote di tenant-a.

Salva tutti i controlli in `05/tenant-checks.txt`.

---

### Verifica finale

```bash
kubectl get nodes -L topology.kubernetes.io/zone
kubectl -n shared-services get networkpolicy,svc,pods
kubectl -n architecture-lab get storageclass,pv,pvc,deploy,pods,pdb
kubectl -n tenant-a get resourcequota,limitrange,deploy,pods
kubectl -n opencost get pods,svc
```

La prova è completa quando networking, storage e compute rispettano i vincoli
architetturali, OpenCost mostra allocazioni attribuibili al cost center e le
risorse dei tenant sono limitate senza impedire il normale funzionamento.
