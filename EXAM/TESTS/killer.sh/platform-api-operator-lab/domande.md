# Platform API and Operator Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - Schema strutturale della CRD

Percorso: `~/course-platform-api-operator/01`.

Correggi `platformservice-crd.yaml`:

1. Rimuovi `x-kubernetes-preserve-unknown-fields`.
2. Definisci uno schema strutturale per l'oggetto root.
3. Definisci `spec` come object con `owner`, `plan`, `image` e `replicas`.
4. Definisci `owner` come object contenente `team`.
5. Definisci `status` come object con `phase` e `message`.
6. Applica la CRD corretta e verifica che la condizione `Established` sia
   `True`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f platformservice-crd.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/01
kubectl apply -f platformservice-crd.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Validazione PlatformService

Percorso: `~/course-platform-api-operator/01`.

Completa le validazioni OpenAPI:

1. Rendi obbligatori `spec.owner`, `spec.plan` e `spec.image`.
2. Rendi obbligatorio `spec.owner.team`.
3. Limita `plan` ai valori `small` e `medium`.
4. Definisci `replicas` come integer, minimo `1`, massimo `5`.
5. Imposta il default di `replicas` a `1`.
6. Riapplica la CRD.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - Status e printer columns

Percorso: `~/course-platform-api-operator/01`.

Nella versione `v1alpha1`:

1. abilita il subresource `status`;
2. aggiungi la colonna `Plan` da `.spec.plan`;
3. aggiungi la colonna `Replicas` da `.spec.replicas`;
4. aggiungi la colonna `Phase` da `.status.phase`;
5. verifica le colonne con `kubectl get platformservices`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Test della Platform API

Percorso: `~/course-platform-api-operator/01`.

1. Usa `kubectl explain` per verificare `spec`, `owner.team`, `plan`,
   `image`, `replicas` e `status`.
2. Applica `service-valid.yaml`: deve essere accettato e ricevere
   `replicas: 1` dal default.
3. Applica `service-invalid-plan.yaml`: deve essere rifiutato.
4. Applica `service-invalid-replicas.yaml`: deve essere rifiutato.
5. Salva comandi, errori di validazione e risorsa valida in `crd-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f service-valid.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/01
kubectl apply -f service-valid.yaml
kubectl apply -f service-invalid-plan.yaml
kubectl apply -f service-invalid-replicas.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Diagnosi RBAC developer

Percorso: `~/course-platform-api-operator/02`.

Il ServiceAccount `developer` possiede inizialmente accesso read-only ai
`PlatformService` nel Namespace `tenant-a`.

1. Esegui `kubectl auth can-i --list` tramite impersonation.
2. Verifica `get`, `list` e `watch` sui PlatformService.
3. Verifica che `create`, `patch`, `update` e `delete` siano inizialmente
   negati.
4. Salva lo stato iniziale in `rbac-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 - RBAC self-service write

Percorso: `~/course-platform-api-operator/02`.

Completa `developer-rbac.yaml`:

1. Aggiungi `create`, `update`, `patch` e `delete`.
2. Mantieni la regola limitata a `platformservices`.
3. Non concedere accesso a `platformservices/status`.
4. Non aggiungere altri API group o risorse.
5. Applica il Role aggiornato e verifica i nuovi permessi.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f developer-rbac.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/02
kubectl apply -f developer-rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Confini del Namespace

Percorso: `~/course-platform-api-operator/02`.

Usando impersonation:

1. verifica che il developer possa creare un PlatformService in `tenant-a`;
2. verifica che possa aggiornarlo e cancellarlo;
3. verifica che non possa creare la stessa risorsa in `platform-system`;
4. verifica che non possa elencare PlatformService in tutti i Namespace;
5. salva risultati ed exit code in `rbac-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Test dei privilegi negativi

Percorso: `~/course-platform-api-operator/02`.

Dimostra che il developer non possa:

1. creare Deployment;
2. creare Service;
3. leggere o creare Secret;
4. creare o modificare CRD;
5. modificare il subresource status dei PlatformService.

Tutti i test devono essere eseguiti con `kubectl auth can-i` e registrati in
`rbac-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Diagnosi dell'operator

Percorso: `~/course-platform-api-operator/03`.

L'operator e il PlatformService `catalog` sono già presenti, ma il Role è
incompleto.

1. Controlla Pod, log ed eventi dell'operator.
2. Individua i dinieghi RBAC durante la creazione delle risorse gestite.
3. Verifica il fallimento della patch sul subresource status.
4. Conferma che l'operator non abbia accesso a Secret o Node.
5. Salva la diagnosi iniziale in `operator-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 - RBAC su custom resource e status

Percorso: `~/course-platform-api-operator/03`.

Completa `operator-rbac.yaml`:

1. Mantieni `get`, `list` e `watch` sui PlatformService.
2. Aggiungi `get`, `patch` e `update` su `platformservices/status`.
3. Non concedere delete sulla custom resource.
4. Applica il ClusterRole aggiornato.
5. Verifica i permessi tramite impersonation del ServiceAccount operator.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f operator-rbac.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/03
kubectl apply -f operator-rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - RBAC sulle risorse gestite

Percorso: `~/course-platform-api-operator/03`.

1. Aggiungi `create`, `update`, `patch` e `delete` sui Deployment.
2. Aggiungi gli stessi verbi su Service e ConfigMap.
3. Mantieni `get`, `list` e `watch`.
4. Non aggiungere accesso a Secret, Namespace, Node o risorse RBAC.
5. Applica il file e riavvia il Deployment operator.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Reconciliation e drift

Percorso: `~/course-platform-api-operator/03`.

1. Attendi che `catalog` raggiunga `status.phase=Ready`.
2. Verifica Deployment, Service e ConfigMap generati.
3. Modifica `spec.replicas` del PlatformService e verifica il reconcile.
4. Introduci drift modificando direttamente le repliche del Deployment.
5. Attendi che l'operator ripristini il valore dichiarato.
6. Salva timeline, status e correzione del drift in `operator-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Dipendenza della Pipeline

Percorso: `~/course-platform-api-operator/04`.

Completa `provisioning-pipeline.yaml`:

1. Aggiungi `runAfter` a `create-platform-request`.
2. Imposta come dipendenza `validate-request`.
3. Verifica che il task di creazione non parta se la validazione fallisce.
4. Applica la Pipeline completata nel Namespace `self-service`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f provisioning-pipeline.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/04
kubectl apply -f provisioning-pipeline.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - ServiceAccount provisioner

Percorso: `~/course-platform-api-operator/04`.

1. Completa `pipeline-rbac.yaml` con `create`, `update` e `patch` sui soli
   PlatformService in `tenant-a`.
2. Non concedere permessi diretti su Deployment, Service o ConfigMap.
3. Applica il file RBAC.
4. Imposta `serviceAccountName: provisioner` in `provisioning-run.yaml`.
5. Verifica i permessi del ServiceAccount tramite impersonation.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pipeline-rbac.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/04
kubectl apply -f pipeline-rbac.yaml
kubectl apply -f provisioning-run.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Provisioning positivo

Percorso: `~/course-platform-api-operator/04`.

1. Crea un PipelineRun da `provisioning-run.yaml`.
2. Attendi il completamento dei TaskRun.
3. Verifica la creazione di `tenant-a/checkout`.
4. Verifica che l'operator generi Deployment, Service e ConfigMap.
5. Verifica `status.phase=Ready`.
6. Salva PipelineRun, TaskRun e risorse in `workflow-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f provisioning-run.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/04
kubectl apply -f provisioning-run.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 - Provisioning negativo

Percorso: `~/course-platform-api-operator/04`.

1. Crea un nuovo PipelineRun da `provisioning-run-invalid.yaml`.
2. Verifica che `validate-request` fallisca per `plan=large`.
3. Verifica che `create-platform-request` non venga eseguito.
4. Verifica che `rejected-service` non esista.
5. Salva condizioni, TaskRun e log in `workflow-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f provisioning-run-invalid.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/04
kubectl apply -f provisioning-run-invalid.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - Finalizer

Percorso: `~/course-platform-api-operator/05`.

1. Aggiungi `platform.cnpe.io/cleanup` ai finalizer di
   `lifecycle-service.yaml`.
2. In `03/operator-rbac.yaml`, consenti all'operator di eseguire `patch` sui
   PlatformService per aggiornare `metadata.finalizers`.
3. Mantieni invariati gli altri limiti RBAC.
4. Applica RBAC, operator aggiornato e risorsa lifecycle.
5. Verifica che `reports` venga riconciliato e mostri il finalizer.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f lifecycle-service.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/05
kubectl apply -f lifecycle-service.yaml
kubectl apply -f 03/operator-rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 - Cleanup delle dipendenze

Percorso: `~/course-platform-api-operator/05`.

Completa il ramo di deletion in `03/operator.yaml`:

1. rileva `metadata.deletionTimestamp`;
2. elimina Deployment `reports`;
3. elimina Service `reports`;
4. elimina ConfigMap `reports-platform`;
5. rimuovi il finalizer soltanto dopo il cleanup riuscito;
6. non eseguire il reconcile normale durante la deletion.

Riapplica il ConfigMap e riavvia l'operator.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/operator.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/05
kubectl apply -f 03/operator.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Idempotenza e recovery

Percorso: `~/course-platform-api-operator/05`.

1. Applica più volte `lifecycle-service.yaml`.
2. Verifica che esista una sola copia di ciascuna risorsa gestita.
3. Elimina il PlatformService e osserva la fase `Terminating`.
4. Simula temporaneamente un errore nel cleanup senza rimuovere manualmente
   il finalizer.
5. Ripristina l'operator e verifica il completamento automatico.
6. Salva timeline e diagnosi in `lifecycle-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f lifecycle-service.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/05
kubectl apply -f lifecycle-service.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 - Verifica finale Platform API

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-api-operator/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-api-operator/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
