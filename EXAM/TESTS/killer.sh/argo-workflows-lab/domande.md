# Le 20 domande dell'esame - Argo Workflows Lab

Scenario creato da `setup-argo-workflows-lab.sh`. Gli starter sono in
`~/course-argo-workflows/` e le risorse degli esercizi nel Namespace
`argo-workflows-lab`.

**Vincolo:** non modificare controller, server o CRD nel Namespace `argo`.
Usa Workflow, WorkflowTemplate, ClusterWorkflowTemplate e CronWorkflow.

---

### Q1 - Workflow container

Completa `01/workflow.yaml` con entrypoint e container template. Il Workflow
deve terminare `Succeeded` e stampare esattamente `hello cnpe`.

### Q2 - Parametri

Correggi `02/workflow.yaml` dichiarando il parametro `name`, default
`platform`, e passandolo al template. Esegui con `name=cnpe`.

### Q3 - Steps sequenziali

Completa `03/workflow.yaml` con gli step `prepare`, `build`, `verify` in
sequenza. Verifica ordine dei node e log.

### Q4 - Steps paralleli

In `04/workflow.yaml`, esegui `lint` e `unit` in parallelo dopo `clone`, poi
`report`. Salva tempi dei node in `04/evidence.txt`.

### Q5 - DAG dependencies

Completa il DAG in `05/workflow.yaml`: `clone`, test paralleli e `package`
dipendente da entrambi.

### Q6 - Output parameters

Fai produrre a `version` il parametro `version=2.3.1` e passalo a `publish`.
Verifica il log `publishing 2.3.1`.

### Q7 - Artifacts

Correggi `07/workflow.yaml`: `generate` crea `/tmp/report.txt`, `consume` lo
riceve come artifact e ne verifica il contenuto.

### Q8 - Volumi

Associa un `emptyDir` al volume `work` in `08/workflow.yaml` e condividi un
file tra due template.

### Q9 - PVC dinamico

Completa `volumeClaimTemplates` in `09/workflow.yaml` richiedendo `100Mi`
ReadWriteOnce. Verifica PVC, mount e garbage collection.

### Q10 - when

Configura `10/workflow.yaml` affinché `deploy` venga eseguito soltanto per
`staging` o `prod`. Prova i valori `dev` e `staging`.

### Q11 - Retry strategy

Imposta una retry strategy che permetta al template instabile di riuscire al
terzo tentativo. Verifica i retry node e il backoff.

### Q12 - Timeout e deadline

Configura timeout del template a 5 secondi e `activeDeadlineSeconds` del
Workflow a 30. Il task che dorme 20 secondi deve fallire per timeout.

### Q13 - Exit handler

Aggiungi `onExit` a `13/workflow.yaml`. L'handler deve essere eseguito anche
dopo il fallimento e stampare `status=<workflow.status>`.

### Q14 - Continue on failure

Configura il DAG affinché `report` venga eseguito anche se `test` fallisce,
usando `depends` con gli stati appropriati.

### Q15 - WorkflowTemplate

Completa e applica `15/template.yaml`, poi referenzialo da `workflow.yaml`
passando il parametro richiesto.

### Q16 - ClusterWorkflowTemplate

Completa il template cluster-scoped e richiamalo dal Namespace del lab.
Verifica il riferimento e limita il ServiceAccount con RBAC.

### Q17 - CronWorkflow

Configura `17/cronworkflow.yaml` ogni cinque minuti, timezone `Europe/Rome`,
concurrency policy `Forbid` e history limit 2/1.

### Q18 - Mutex e sincronizzazione

Completa i due Workflow in `18/` affinché condividano il mutex
`production-deploy`. Verifica che non entrino insieme nella sezione critica.

### Q19 - Troubleshooting

`19/workflow.yaml` contiene entrypoint, argomento e dipendenza errati.
Riproduci, correggi e documenta causa, node status ed eventi in `19/report.md`.

### Q20 - Simulazione a tempo

Completa il DAG finale: clone, lint/unit paralleli, package, scan gate, publish
e exit handler. Esponi `image` e `digest` come output e verifica:

```bash
kubectl -n argo-workflows-lab get workflows,workflowtemplates,cronworkflows
kubectl -n argo-workflows-lab get workflow final-build -o yaml
```

Salva node, output e log in `20/run.log`.
