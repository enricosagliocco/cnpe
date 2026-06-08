# Le 20 domande dell'esame — Platform API and Operator Lab

Scenario creato da `setup-platform-api-operator-lab.sh`. Gli starter sono in
`~/course-platform-api-operator/`.

**Vincolo:** non concedere `cluster-admin`. I developer devono usare la
Platform API e non creare direttamente Deployment o Service. Mantieni il
principio del minimo privilegio.

---

### Q1 – Schema strutturale CRD

Rimuovi `x-kubernetes-preserve-unknown-fields` da
`01/platformservice-crd.yaml` e definisci `spec` e `status` strutturali.

### Q2 – Validazione PlatformService

Rendi obbligatori team, plan e image; limita plan a `small|medium` e replicas
tra 1 e 5 con default 1.

### Q3 – Status e printer columns

Abilita il subresource status e aggiungi colonne per Plan, Replicas e Phase.

### Q4 – Test API

Verifica con `kubectl explain`, una risorsa valida e due richieste rifiutate.
Salva tutto in `01/crd-check.txt`.

---

### Q5 – RBAC developer read

Verifica tramite impersonation i permessi iniziali del ServiceAccount
`developer` nel Namespace `tenant-a`.

### Q6 – RBAC self-service write

Completa `02/developer-rbac.yaml` con create, update, patch e delete sui soli
PlatformService namespaced.

### Q7 – Test confini Namespace

Dimostra che il developer opera in `tenant-a` ma non in `platform-system`.

### Q8 – Test privilegi negativi

Dimostra che non può creare Deployment, Service, Secret o CRD e salva i test
in `02/rbac-check.txt`.

---

### Q9 – Diagnosi operator

Analizza log ed eventi del Deployment operator e identifica le operazioni
RBAC negate durante il reconcile di `catalog`.

### Q10 – RBAC custom resource e status

Consenti watch dei PlatformService e get/patch/update del subresource status.

### Q11 – RBAC risorse gestite

Consenti create/update/patch/delete di Deployment, Service e ConfigMap senza
aggiungere accesso a Secret o Node.

### Q12 – Reconciliation e drift

Riavvia l'operator, verifica `catalog` Ready, modifica replicas e introduci
drift nel Deployment. Salva la correzione in `03/operator-check.txt`.

---

### Q13 – Dipendenza Pipeline

In `04/provisioning-pipeline.yaml`, esegui `create-platform-request` soltanto
dopo `validate-request`.

### Q14 – ServiceAccount provisioner

Completa RBAC e imposta nel PipelineRun il ServiceAccount `provisioner`.

### Q15 – Provisioning positivo

Esegui il PipelineRun per `checkout`, verifica PlatformService e risorse
riconciliate dall'operator.

### Q16 – Provisioning negativo

Esegui una richiesta `plan=large`, dimostra che fallisce prima della creazione
e salva TaskRun e log in `04/workflow-check.txt`.

---

### Q17 – Finalizer

Aggiungi `platform.cnpe.io/cleanup` a `05/lifecycle-service.yaml` e fai in
modo che l'operator lo gestisca.

### Q18 – Cleanup dipendenze

Durante deletion elimina Deployment, Service e ConfigMap prima di rimuovere
il finalizer.

### Q19 – Idempotenza e recovery

Dimostra reconcile ripetibile, assenza di duplicati e diagnosi di una risorsa
temporaneamente bloccata in `Terminating`.

### Q20 – Verifica finale Platform API

```bash
kubectl get crd platformservices.platform.cnpe.io
kubectl get platformservices --all-namespaces
kubectl -n platform-system get deployment,pods
kubectl -n tenant-a get platformservices,deployments,services,configmaps
kubectl -n self-service get pipelines,pipelineruns,taskruns
```

Completa `05/lifecycle-check.txt` con timeline, cleanup e stato finale.
