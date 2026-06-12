# Argo Workflows Lab - 20 exam-style tasks

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
### Q1 - Workflow container

Percorso: `~/course-argo-workflows/01`.

1. Completa `01/workflow.yaml` con entrypoint e container template.

2. Il Workflow deve terminare `Succeeded` e stampare esattamente `hello cnpe`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 01/workflow.yaml
```

---

### Q2 - Parametri

Percorso: `~/course-argo-workflows/02`.

1. Correggi `02/workflow.yaml` dichiarando il parametro `name`, default
   `platform`, e passandolo al template.

2. Esegui con `name=cnpe`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/workflow.yaml
```

---

### Q3 - Steps sequenziali

Percorso: `~/course-argo-workflows/03`.

1. Completa `03/workflow.yaml` con gli step `prepare`, `build`, `verify` in
   sequenza.

2. Verifica ordine dei node e log.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/workflow.yaml
```

---

### Q4 - Steps paralleli

Percorso: `~/course-argo-workflows/04`.

1. In `04/workflow.yaml`, esegui `lint` e `unit` in parallelo dopo `clone`,
   poi `report`.

2. Salva tempi dei node in `04/evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 04/workflow.yaml
```

---

### Q5 - DAG dependencies

Percorso: `~/course-argo-workflows/05`.

1. Completa il DAG in `05/workflow.yaml`: `clone`, test paralleli e `package`
   dipendente da entrambi.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 05/workflow.yaml
```

---

### Q6 - Output parameters

Percorso: `~/course-argo-workflows/06`.

1. Fai produrre a `version` il parametro `version=2.3.1` e passalo a
   `publish`.

2. Verifica il log `publishing 2.3.1`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/06` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Artifacts

Percorso: `~/course-argo-workflows/07`.

1. Correggi `07/workflow.yaml`: `generate` crea `/tmp/report.txt`, `consume`
   lo riceve come artifact e ne verifica il contenuto.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/07` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 07/workflow.yaml
```

---

### Q8 - Volumi

Percorso: `~/course-argo-workflows/08`.

1. Associa un `emptyDir` al volume `work` in `08/workflow.yaml` e condividi un
   file tra due template.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/08` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 08/workflow.yaml
```

---

### Q9 - PVC dinamico

Percorso: `~/course-argo-workflows/09`.

1. Completa `volumeClaimTemplates` in `09/workflow.yaml` richiedendo `100Mi`
   ReadWriteOnce.

2. Verifica PVC, mount e garbage collection.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/09` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 09/workflow.yaml
```

---

### Q10 - when

Percorso: `~/course-argo-workflows/10`.

1. Configura `10/workflow.yaml` affinché `deploy` venga eseguito soltanto per
   `staging` o `prod`.

2. Prova i valori `dev` e `staging`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 10/workflow.yaml
```

---

### Q11 - Retry strategy

Percorso: `~/course-argo-workflows/11`.

1. Imposta una retry strategy che permetta al template instabile di riuscire
   al terzo tentativo.

2. Verifica i retry node e il backoff.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/11` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Timeout e deadline

Percorso: `~/course-argo-workflows/12`.

1. Configura timeout del template a 5 secondi e `activeDeadlineSeconds` del
   Workflow a 30.

2. Il task che dorme 20 secondi deve fallire per timeout.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/12` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Exit handler

Percorso: `~/course-argo-workflows/13`.

1. Aggiungi `onExit` a `13/workflow.yaml`.

2. L'handler deve essere eseguito anche dopo il fallimento e stampare
   `status=<workflow.status>`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 13/workflow.yaml
```

---

### Q14 - Continue on failure

Percorso: `~/course-argo-workflows/14`.

1. Configura il DAG affinché `report` venga eseguito anche se `test` fallisce,
   usando `depends` con gli stati appropriati.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/14` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - WorkflowTemplate

Percorso: `~/course-argo-workflows/15`.

1. Completa e applica `15/template.yaml`, poi referenzialo da `workflow.yaml`
   passando il parametro richiesto.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/15` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 15/template.yaml
```

---

### Q16 - ClusterWorkflowTemplate

Percorso: `~/course-argo-workflows/16`.

1. Completa il template cluster-scoped e richiamalo dal Namespace del lab.

2. Verifica il riferimento e limita il ServiceAccount con RBAC.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/16` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - CronWorkflow

Percorso: `~/course-argo-workflows/17`.

1. Configura `17/cronworkflow.yaml` ogni cinque minuti, timezone
   `Europe/Rome`, concurrency policy `Forbid` e history limit 2/1.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/17` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 17/cronworkflow.yaml
```

---

### Q18 - Mutex e sincronizzazione

Percorso: `~/course-argo-workflows/18`.

1. Completa i due Workflow in `18/` affinché condividano il mutex
   `production-deploy`.

2. Verifica che non entrino insieme nella sezione critica.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/18` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Troubleshooting

Percorso: `~/course-argo-workflows/19`.

1. `19/workflow.yaml` contiene entrypoint, argomento e dipendenza errati.

2. Riproduci, correggi e documenta causa, node status ed eventi in
   `19/report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/19` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 19/workflow.yaml
```

---

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-workflows/20` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Workflow container

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/01
kubectl apply -f 01/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Parametri

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/02
kubectl apply -f 02/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - Steps sequenziali

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/03
kubectl apply -f 03/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - Steps paralleli

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/04
kubectl apply -f 04/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - DAG dependencies

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/05
kubectl apply -f 05/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - Output parameters

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/06
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - Artifacts

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/07
kubectl apply -f 07/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Volumi

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/08
kubectl apply -f 08/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - PVC dinamico

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/09
kubectl apply -f 09/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - when

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/10
kubectl apply -f 10/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - Retry strategy

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/11
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - Timeout e deadline

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/12
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - Exit handler

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/13
kubectl apply -f 13/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Continue on failure

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/14
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - WorkflowTemplate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/15
kubectl apply -f 15/template.yaml
kubectl apply -f workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - ClusterWorkflowTemplate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/16
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - CronWorkflow

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/17
kubectl apply -f 17/cronworkflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - Mutex e sincronizzazione

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/18
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - Troubleshooting

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/19
kubectl apply -f 19/workflow.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - Simulazione a tempo

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-workflows/20
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
