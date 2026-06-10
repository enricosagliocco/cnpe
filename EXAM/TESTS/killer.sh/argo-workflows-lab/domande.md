# Le 20 domande dell'esame - Argo Workflows Lab (simulatore lab)

Scenario creato da `setup-argo-workflows-lab.sh`. Gli starter sono in
`~/course-argo-workflows/` e le risorse degli esercizi nel Namespace
`argo-workflows-lab`.

**Vincolo:** non modificare controller, server o CRD nel Namespace `argo`.
Usa Workflow, WorkflowTemplate, ClusterWorkflowTemplate e CronWorkflow.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 - Workflow container

Percorso: `~/course-argo-workflows/01`.

1. Completa `01/workflow.yaml` con entrypoint e container template.

2. Il Workflow deve terminare `Succeeded` e stampare esattamente `hello cnpe`.

### Q2 - Parametri

Percorso: `~/course-argo-workflows/02`.

1. Correggi `02/workflow.yaml` dichiarando il parametro `name`, default
   `platform`, e passandolo al template.

2. Esegui con `name=cnpe`.

### Q3 - Steps sequenziali

Percorso: `~/course-argo-workflows/03`.

1. Completa `03/workflow.yaml` con gli step `prepare`, `build`, `verify` in
   sequenza.

2. Verifica ordine dei node e log.

### Q4 - Steps paralleli

Percorso: `~/course-argo-workflows/04`.

1. In `04/workflow.yaml`, esegui `lint` e `unit` in parallelo dopo `clone`,
   poi `report`.

2. Salva tempi dei node in `04/evidence.txt`.

### Q5 - DAG dependencies

Percorso: `~/course-argo-workflows/05`.

1. Completa il DAG in `05/workflow.yaml`: `clone`, test paralleli e `package`
   dipendente da entrambi.

### Q6 - Output parameters

Percorso: `~/course-argo-workflows/06`.

1. Fai produrre a `version` il parametro `version=2.3.1` e passalo a
   `publish`.

2. Verifica il log `publishing 2.3.1`.

### Q7 - Artifacts

Percorso: `~/course-argo-workflows/07`.

1. Correggi `07/workflow.yaml`: `generate` crea `/tmp/report.txt`, `consume`
   lo riceve come artifact e ne verifica il contenuto.

### Q8 - Volumi

Percorso: `~/course-argo-workflows/08`.

1. Associa un `emptyDir` al volume `work` in `08/workflow.yaml` e condividi un
   file tra due template.

### Q9 - PVC dinamico

Percorso: `~/course-argo-workflows/09`.

1. Completa `volumeClaimTemplates` in `09/workflow.yaml` richiedendo `100Mi`
   ReadWriteOnce.

2. Verifica PVC, mount e garbage collection.

### Q10 - when

Percorso: `~/course-argo-workflows/10`.

1. Configura `10/workflow.yaml` affinché `deploy` venga eseguito soltanto per
   `staging` o `prod`.

2. Prova i valori `dev` e `staging`.

### Q11 - Retry strategy

Percorso: `~/course-argo-workflows/11`.

1. Imposta una retry strategy che permetta al template instabile di riuscire
   al terzo tentativo.

2. Verifica i retry node e il backoff.

### Q12 - Timeout e deadline

Percorso: `~/course-argo-workflows/12`.

1. Configura timeout del template a 5 secondi e `activeDeadlineSeconds` del
   Workflow a 30.

2. Il task che dorme 20 secondi deve fallire per timeout.

### Q13 - Exit handler

Percorso: `~/course-argo-workflows/13`.

1. Aggiungi `onExit` a `13/workflow.yaml`.

2. L'handler deve essere eseguito anche dopo il fallimento e stampare
   `status=<workflow.status>`.

### Q14 - Continue on failure

Percorso: `~/course-argo-workflows/14`.

1. Configura il DAG affinché `report` venga eseguito anche se `test` fallisce,
   usando `depends` con gli stati appropriati.

### Q15 - WorkflowTemplate

Percorso: `~/course-argo-workflows/15`.

1. Completa e applica `15/template.yaml`, poi referenzialo da `workflow.yaml`
   passando il parametro richiesto.

### Q16 - ClusterWorkflowTemplate

Percorso: `~/course-argo-workflows/16`.

1. Completa il template cluster-scoped e richiamalo dal Namespace del lab.

2. Verifica il riferimento e limita il ServiceAccount con RBAC.

### Q17 - CronWorkflow

Percorso: `~/course-argo-workflows/17`.

1. Configura `17/cronworkflow.yaml` ogni cinque minuti, timezone
   `Europe/Rome`, concurrency policy `Forbid` e history limit 2/1.

### Q18 - Mutex e sincronizzazione

Percorso: `~/course-argo-workflows/18`.

1. Completa i due Workflow in `18/` affinché condividano il mutex
   `production-deploy`.

2. Verifica che non entrino insieme nella sezione critica.

### Q19 - Troubleshooting

Percorso: `~/course-argo-workflows/19`.

1. `19/workflow.yaml` contiene entrypoint, argomento e dipendenza errati.

2. Riproduci, correggi e documenta causa, node status ed eventi in
   `19/report.md`.

### Q20 - Simulazione a tempo

Percorso: `~/course-argo-workflows/20`.

1. Completa il DAG finale: clone, lint/unit paralleli, package, scan gate,
   publish e exit handler.

2. Esponi `image` e `digest` come output e verifica:

```bash
kubectl -n argo-workflows-lab get workflows,workflowtemplates,cronworkflows
kubectl -n argo-workflows-lab get workflow final-build -o yaml
```

3. Salva node, output e log in `20/run.log`.
