# CNPE Platform API, CRD and Operator Lab

Scenario creato da `setup-platform-api-operator-lab.sh`. Gli starter sono in
`~/course-platform-api-operator/`.

## Vincoli d'esame

- Non concedere privilegi `cluster-admin`.
- I developer devono usare la Platform API, non creare direttamente
  Deployment o Service.
- Non modificare le risorse gestite per correggere il desired state.
- Mantieni il principio del minimo privilegio.
- Tutti i manifest devono essere YAML block-style leggibili.

---

### Q1 – Progettazione della CRD

La CRD `PlatformService` accetta qualsiasi contenuto e non espone stato o
colonne utili.

Correggi `01/platformservice-crd.yaml`:

1. rimuovi `x-kubernetes-preserve-unknown-fields`;
2. definisci uno schema strutturale per:
   - `spec.owner.team`, stringa obbligatoria con almeno 2 caratteri;
   - `spec.plan`, obbligatorio e limitato a `small` o `medium`;
   - `spec.image`, stringa obbligatoria;
   - `spec.replicas`, integer tra 1 e 5, default 1;
   - `status.phase` e `status.message`;
3. abilita il subresource `status`;
4. aggiungi printer column per Plan, Replicas e Phase;
5. mantieni `v1alpha1` come versione served e storage.

Verifica con `kubectl explain`, crea una risorsa valida e dimostra che plan
non supportati e repliche maggiori di 5 vengono rifiutati.

Salva schema, test positivi e test negativi in `01/crd-check.txt`.

---

### Q2 – API self-service e RBAC

Il ServiceAccount `developer` può leggere le richieste ma non crearle.

Completa `02/developer-rbac.yaml` affinché possa gestire `PlatformService`
solo nel Namespace `tenant-a`.

Verifica tramite impersonation che il developer possa:

- creare, leggere, aggiornare, patchare ed eliminare PlatformService;
- elencare e osservare le richieste;
- non creare Deployment, Service, Secret o CRD;
- non creare PlatformService in `platform-system`.

Salva tutti i test `kubectl auth can-i` in `02/rbac-check.txt`.

---

### Q3 – Troubleshooting dell'operator

Il Pod dell'operator è Running, ma `catalog` non viene riconciliato. Analizza
i log e correggi soltanto `03/operator-rbac.yaml`.

L'operator deve poter:

1. osservare PlatformService in tutti i Namespace;
2. aggiornare il relativo subresource `status`;
3. riconciliare Deployment, Service e ConfigMap;
4. eliminare le risorse gestite durante il cleanup;
5. non leggere Secret, Node o altre risorse non necessarie.

Dopo la correzione riavvia il Deployment dell'operator e verifica:

- Deployment `catalog` disponibile con 2 repliche;
- Service e ConfigMap creati;
- `status.phase` uguale a `Ready`;
- una modifica di `spec.replicas` riconciliata automaticamente;
- una modifica manuale al Deployment corretta dal loop di reconciliation.

Salva log, RBAC effettivo, stato e prove di drift in
`03/operator-check.txt`.

---

### Q4 – Workflow automatizzato di provisioning

La Pipeline Tekton modella un portale self-service, ma il Task di creazione
può partire prima della validazione e usa il ServiceAccount errato.

Correggi i file in `04/`:

1. il Task `create-platform-request` deve dipendere da `validate-request`;
2. il PipelineRun deve usare il ServiceAccount `provisioner`;
3. il provisioner deve avere i soli permessi necessari nel Namespace
   `tenant-a`;
4. la Pipeline deve creare una PlatformService, non Deployment o Service;
5. una richiesta con plan non supportato deve fallire prima della creazione.

Applica Pipeline e PipelineRun e verifica:

- ordine corretto dei TaskRun;
- creazione di `checkout`;
- riconciliazione delle risorse applicative da parte dell'operator;
- nessuna credenziale privilegiata nei Task;
- fallimento controllato con `plan=large`.

Salva PipelineRun, TaskRun, log e risorse risultanti in
`04/workflow-check.txt`.

---

### Q5 – Lifecycle, finalizer e idempotenza

Estendi l'operator e `05/lifecycle-service.yaml` per gestire correttamente la
cancellazione.

1. usa il finalizer `platform.cnpe.io/cleanup`;
2. quando `deletionTimestamp` è presente:
   - elimina Deployment, Service e ConfigMap gestiti;
   - aggiorna lo stato o genera un evento utile;
   - rimuovi il finalizer soltanto dopo il cleanup;
3. il reconcile ripetuto non deve produrre errori né duplicati;
4. una risorsa bloccata in `Terminating` deve essere diagnosticabile dai log;
5. non rimuovere manualmente il finalizer come soluzione ordinaria.

Applica `reports`, verifica il provisioning, cancellalo e dimostra che le
risorse dipendenti vengono rimosse prima della Custom Resource.

Salva timeline, log e controlli finali in `05/lifecycle-check.txt`.

---

### Verifica finale

```bash
kubectl get crd platformservices.platform.cnpe.io
kubectl get platformservices --all-namespaces
kubectl -n platform-system get deployment,pods
kubectl -n tenant-a get platformservices,deployments,services,configmaps
kubectl -n self-service get pipelines,pipelineruns,taskruns
```

La prova è completa quando la CRD espone un contratto validato, gli utenti
operano tramite API con privilegi minimi, l'operator riconcilia desired state
e lifecycle, e Tekton fornisce un workflow self-service ripetibile.
