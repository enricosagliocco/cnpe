# CNPE Hard Lab — Argo Workflows

Scenario: `argo-workflows-hard`  
Namespace: `wf-lab`  
Directory: `/course/argo-workflows-hard`  
Tempo consigliato: 75–90 minuti.

## Q1 — Stato iniziale

Verifica Argo Workflows, WorkflowTemplate, CronWorkflow e RBAC.

Salva:

```bash
/course/argo-workflows-hard/q1-status.txt
```

---

## Q2 — Esegui workflow iniziale

Crea il Workflow:

```bash
kubectl create -f /course/argo-workflows-hard/20-workflow-broken.yaml
```

Trova il primo nodo fallito e salva describe/log in:

```bash
/course/argo-workflows-hard/q2-first-failure.txt
```

---

## Q3 — Fix artifact path

Il task `security-scan` riceve l’artifact in un path, ma lo script legge da un altro path.

Correggi il `WorkflowTemplate` senza cambiare il task `generate`.

Rilancia il Workflow e salva il template aggiornato in:

```bash
/course/argo-workflows-hard/q3-template-artifact.yaml
```

---

## Q4 — DAG dependencies

Il task `create-summary` non aspetta tutti i controlli.

Correggi il DAG:

- `create-summary` deve partire solo dopo `validate` e `security-scan`;
- `validate` e `security-scan` devono essere paralleli dopo `generate`.

Salva il DAG corretto in:

```bash
/course/argo-workflows-hard/q4-dag.txt
```

---

## Q5 — RBAC ConfigMap

Il Workflow deve creare/patchare una ConfigMap in `wf-lab`.

Correggi la Role `workflow-basic` senza usare cluster-admin.

Verifica:

```bash
kubectl auth can-i create configmaps -n wf-lab --as system:serviceaccount:wf-lab:workflow
kubectl auth can-i patch configmaps -n wf-lab --as system:serviceaccount:wf-lab:workflow
```

Salva in:

```bash
/course/argo-workflows-hard/q5-rbac.txt
```

---

## Q6 — Workflow succeeded

Rilancia il Workflow con:

- `app-name=payments`
- `environment=staging`

Verifica:

- Workflow `Succeeded`;
- ConfigMap `summary-payments` esiste;
- contiene `environment=staging`.

Salva:

```bash
/course/argo-workflows-hard/q6-workflow-succeeded.txt
```

---

## Q7 — Parametri diversi

Esegui un nuovo Workflow usando lo stesso `WorkflowTemplate` con:

- `app-name=inventory`
- `environment=prod`

Verifica ConfigMap `summary-inventory`.

Salva:

```bash
/course/argo-workflows-hard/q7-params.txt
```

---

## Q8 — CronWorkflow hardening

Correggi `nightly-app-check`:

- schedule giornaliero alle 02:30;
- `concurrencyPolicy: Forbid`;
- `successfulJobsHistoryLimit: 3`;
- `failedJobsHistoryLimit: 3`.

Salva:

```bash
/course/argo-workflows-hard/q8-cronworkflow.yaml
```

---

## Q9 — Esecuzione manuale da CronWorkflow

Crea un Workflow manuale partendo dalla spec del CronWorkflow o usando il template equivalente.

Deve usare:

- `app-name=catalog`
- `environment=prod`

Salva stato finale:

```bash
/course/argo-workflows-hard/q9-cron-manual.txt
```

---

## Q10 — Logs e artifact

Per l’ultimo Workflow riuscito:

- salva i log di tutti i pod;
- salva il contenuto dell’artifact/report se accessibile via pod log o output.

File:

```bash
/course/argo-workflows-hard/q10-logs.txt
```

---

## Q11 — Resubmit

Prendi un Workflow fallito precedente, correggi la causa e rieseguilo/resubmittalo oppure documenta perché ne hai creato uno nuovo.

Salva:

```bash
/course/argo-workflows-hard/q11-resubmit.txt
```

---

## Q12 — Cleanup

Mantieni solo gli ultimi 3 Workflow in `wf-lab`.

Non cancellare:

- WorkflowTemplate;
- CronWorkflow;
- ServiceAccount/RBAC.

Salva:

```bash
/course/argo-workflows-hard/q12-cleanup.txt
```

---

## Q13 — Report finale

Crea:

```bash
/course/argo-workflows-hard/final-report.txt
```

Deve contenere:

- WorkflowTemplate valido;
- ultimo Workflow succeeded;
- ConfigMap create;
- CronWorkflow corretto;
- differenza tra Workflow, WorkflowTemplate, CronWorkflow, DAG task, artifact e parameter.
