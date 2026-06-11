# Le 20 domande dell'esame - Platform API and Operator Lab (simulatore lab)

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

Scenario creato da `setup-platform-api-operator-lab.sh`. Manifest e file
starter si trovano in `~/course-platform-api-operator/`.

Le 20 domande sono organizzate in cinque scenari progressivi:

- Q1-Q4: directory `01`, progettazione della Platform API;
- Q5-Q8: directory `02`, RBAC self-service per developer;
- Q9-Q12: directory `03`, RBAC e reconciliation dell'operator;
- Q13-Q16: directory `04`, provisioning tramite Tekton;
- Q17-Q20: directory `05`, finalizer e lifecycle.

Vincoli:

- Non concedere `cluster-admin` e non usare regole RBAC wildcard.
- I developer devono creare risorse tramite `PlatformService`, non
  direttamente tramite Deployment o Service.
- Non modificare i componenti core di Kubernetes o Tekton.
- Conservare nomi, Namespace e API group indicati nei file starter.
- Applicare il principio del minimo privilegio all'operator e ai workflow.
- Eseguire realmente i test positivi e negativi richiesti.

Le domande di ogni scenario sono progressive e condividono gli stessi file.
Completa Q1-Q4 nell'ordine, poi Q5-Q8 e così via.

Comandi utili:

```bash
kubectl get crd platformservices.platform.cnpe.io
kubectl explain platformservice.spec
kubectl get platformservices --all-namespaces
kubectl auth can-i --as=system:serviceaccount:tenant-a:developer --list
kubectl -n platform-system logs deploy/platform-service-operator
kubectl -n self-service get pipeline,pipelinerun,taskrun
```

---

### Q1 - Schema strutturale della CRD
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/01`.

Correggi `platformservice-crd.yaml`:

1. Rimuovi `x-kubernetes-preserve-unknown-fields`.
2. Definisci uno schema strutturale per l'oggetto root.
3. Definisci `spec` come object con `owner`, `plan`, `image` e `replicas`.
4. Definisci `owner` come object contenente `team`.
5. Definisci `status` come object con `phase` e `message`.
6. Applica la CRD corretta e verifica che la condizione `Established` sia
   `True`.

---

### Q2 - Validazione PlatformService
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/01`.

Completa le validazioni OpenAPI:

1. Rendi obbligatori `spec.owner`, `spec.plan` e `spec.image`.
2. Rendi obbligatorio `spec.owner.team`.
3. Limita `plan` ai valori `small` e `medium`.
4. Definisci `replicas` come integer, minimo `1`, massimo `5`.
5. Imposta il default di `replicas` a `1`.
6. Riapplica la CRD.

---

### Q3 - Status e printer columns
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/01`.

Nella versione `v1alpha1`:

1. abilita il subresource `status`;
2. aggiungi la colonna `Plan` da `.spec.plan`;
3. aggiungi la colonna `Replicas` da `.spec.replicas`;
4. aggiungi la colonna `Phase` da `.status.phase`;
5. verifica le colonne con `kubectl get platformservices`.

---

### Q4 - Test della Platform API
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/01`.

1. Usa `kubectl explain` per verificare `spec`, `owner.team`, `plan`,
   `image`, `replicas` e `status`.
2. Applica `service-valid.yaml`: deve essere accettato e ricevere
   `replicas: 1` dal default.
3. Applica `service-invalid-plan.yaml`: deve essere rifiutato.
4. Applica `service-invalid-replicas.yaml`: deve essere rifiutato.
5. Salva comandi, errori di validazione e risorsa valida in `crd-check.txt`.

---

### Q5 - Diagnosi RBAC developer
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/02`.

Il ServiceAccount `developer` possiede inizialmente accesso read-only ai
`PlatformService` nel Namespace `tenant-a`.

1. Esegui `kubectl auth can-i --list` tramite impersonation.
2. Verifica `get`, `list` e `watch` sui PlatformService.
3. Verifica che `create`, `patch`, `update` e `delete` siano inizialmente
   negati.
4. Salva lo stato iniziale in `rbac-check.txt`.

---

### Q6 - RBAC self-service write
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/02`.

Completa `developer-rbac.yaml`:

1. Aggiungi `create`, `update`, `patch` e `delete`.
2. Mantieni la regola limitata a `platformservices`.
3. Non concedere accesso a `platformservices/status`.
4. Non aggiungere altri API group o risorse.
5. Applica il Role aggiornato e verifica i nuovi permessi.

---

### Q7 - Confini del Namespace
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/02`.

Usando impersonation:

1. verifica che il developer possa creare un PlatformService in `tenant-a`;
2. verifica che possa aggiornarlo e cancellarlo;
3. verifica che non possa creare la stessa risorsa in `platform-system`;
4. verifica che non possa elencare PlatformService in tutti i Namespace;
5. salva risultati ed exit code in `rbac-check.txt`.

---

### Q8 - Test dei privilegi negativi
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/02`.

Dimostra che il developer non possa:

1. creare Deployment;
2. creare Service;
3. leggere o creare Secret;
4. creare o modificare CRD;
5. modificare il subresource status dei PlatformService.

Tutti i test devono essere eseguiti con `kubectl auth can-i` e registrati in
`rbac-check.txt`.

---

### Q9 - Diagnosi dell'operator
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/03`.

L'operator e il PlatformService `catalog` sono già presenti, ma il Role è
incompleto.

1. Controlla Pod, log ed eventi dell'operator.
2. Individua i dinieghi RBAC durante la creazione delle risorse gestite.
3. Verifica il fallimento della patch sul subresource status.
4. Conferma che l'operator non abbia accesso a Secret o Node.
5. Salva la diagnosi iniziale in `operator-check.txt`.

---

### Q10 - RBAC su custom resource e status
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/03`.

Completa `operator-rbac.yaml`:

1. Mantieni `get`, `list` e `watch` sui PlatformService.
2. Aggiungi `get`, `patch` e `update` su `platformservices/status`.
3. Non concedere delete sulla custom resource.
4. Applica il ClusterRole aggiornato.
5. Verifica i permessi tramite impersonation del ServiceAccount operator.

---

### Q11 - RBAC sulle risorse gestite
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/03`.

1. Aggiungi `create`, `update`, `patch` e `delete` sui Deployment.
2. Aggiungi gli stessi verbi su Service e ConfigMap.
3. Mantieni `get`, `list` e `watch`.
4. Non aggiungere accesso a Secret, Namespace, Node o risorse RBAC.
5. Applica il file e riavvia il Deployment operator.

---

### Q12 - Reconciliation e drift
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/03`.

1. Attendi che `catalog` raggiunga `status.phase=Ready`.
2. Verifica Deployment, Service e ConfigMap generati.
3. Modifica `spec.replicas` del PlatformService e verifica il reconcile.
4. Introduci drift modificando direttamente le repliche del Deployment.
5. Attendi che l'operator ripristini il valore dichiarato.
6. Salva timeline, status e correzione del drift in `operator-check.txt`.

---

### Q13 - Dipendenza della Pipeline
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/04`.

Completa `provisioning-pipeline.yaml`:

1. Aggiungi `runAfter` a `create-platform-request`.
2. Imposta come dipendenza `validate-request`.
3. Verifica che il task di creazione non parta se la validazione fallisce.
4. Applica la Pipeline completata nel Namespace `self-service`.

---

### Q14 - ServiceAccount provisioner
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/04`.

1. Completa `pipeline-rbac.yaml` con `create`, `update` e `patch` sui soli
   PlatformService in `tenant-a`.
2. Non concedere permessi diretti su Deployment, Service o ConfigMap.
3. Applica il file RBAC.
4. Imposta `serviceAccountName: provisioner` in `provisioning-run.yaml`.
5. Verifica i permessi del ServiceAccount tramite impersonation.

---

### Q15 - Provisioning positivo
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/04`.

1. Crea un PipelineRun da `provisioning-run.yaml`.
2. Attendi il completamento dei TaskRun.
3. Verifica la creazione di `tenant-a/checkout`.
4. Verifica che l'operator generi Deployment, Service e ConfigMap.
5. Verifica `status.phase=Ready`.
6. Salva PipelineRun, TaskRun e risorse in `workflow-check.txt`.

---

### Q16 - Provisioning negativo
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/04`.

1. Crea un nuovo PipelineRun da `provisioning-run-invalid.yaml`.
2. Verifica che `validate-request` fallisca per `plan=large`.
3. Verifica che `create-platform-request` non venga eseguito.
4. Verifica che `rejected-service` non esista.
5. Salva condizioni, TaskRun e log in `workflow-check.txt`.

---

### Q17 - Finalizer
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/05`.

1. Aggiungi `platform.cnpe.io/cleanup` ai finalizer di
   `lifecycle-service.yaml`.
2. In `03/operator-rbac.yaml`, consenti all'operator di eseguire `patch` sui
   PlatformService per aggiornare `metadata.finalizers`.
3. Mantieni invariati gli altri limiti RBAC.
4. Applica RBAC, operator aggiornato e risorsa lifecycle.
5. Verifica che `reports` venga riconciliato e mostri il finalizer.

---

### Q18 - Cleanup delle dipendenze
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/05`.

Completa il ramo di deletion in `03/operator.yaml`:

1. rileva `metadata.deletionTimestamp`;
2. elimina Deployment `reports`;
3. elimina Service `reports`;
4. elimina ConfigMap `reports-platform`;
5. rimuovi il finalizer soltanto dopo il cleanup riuscito;
6. non eseguire il reconcile normale durante la deletion.

Riapplica il ConfigMap e riavvia l'operator.

---

### Q19 - Idempotenza e recovery
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/05`.

1. Applica più volte `lifecycle-service.yaml`.
2. Verifica che esista una sola copia di ciascuna risorsa gestita.
3. Elimina il PlatformService e osserva la fase `Terminating`.
4. Simula temporaneamente un errore nel cleanup senza rimuovere manualmente
   il finalizer.
5. Ripristina l'operator e verifica il completamento automatico.
6. Salva timeline e diagnosi in `lifecycle-check.txt`.

---

### Q20 - Verifica finale Platform API
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-api-operator/05`.

Esegui:

```bash
kubectl get crd platformservices.platform.cnpe.io
kubectl get platformservices --all-namespaces
kubectl -n platform-system get deployment,pods
kubectl -n tenant-a get platformservices,deployments,services,configmaps
kubectl -n self-service get pipelines,pipelineruns,taskruns
```

Completa `lifecycle-check.txt` con:

1. schema e printer columns della Platform API;
2. confini RBAC di developer, operator e provisioner;
3. stato dei provisioning positivo e negativo;
4. timeline di deletion e cleanup;
5. prova dell'assenza finale di `reports` e delle sue risorse gestite.
