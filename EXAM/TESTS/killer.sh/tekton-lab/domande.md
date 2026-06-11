# Tekton Pipelines and Triggers Lab - 20 exam-style tasks

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
### Q1 - Task e parametri

Percorso: `~/course-tekton/01`.

1. Applica `task.yaml` e `taskrun.yaml` e raccogli l'errore iniziale.
2. Completa il Task `greet` con parametro stringa `name`, default `platform`.
3. Passa `name=cnpe` dal TaskRun.
4. Verifica `Succeeded=True` e log esatto `hello cnpe`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f task.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/01
kubectl apply -f task.yaml
kubectl apply -f taskrun.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Workspace condiviso

Percorso: `~/course-tekton/02`.

1. Applica gli starter e diagnostica perché il Task non può produrre
   l'artefatto.
2. Dichiara il workspace `output`.
3. Implementa gli step `prepare`, `build` e `verify` usando lo stesso path.
4. Verifica ordine degli step e presenza di `artifact.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - Result di un Task

Percorso: `~/course-tekton/03`.

1. Esegui il TaskRun e osserva il result errato.
2. Correggi `task.yaml` affinché il result `commit` valga
   `0123456789abcdef`.
3. Crea un nuovo TaskRun.
4. Verifica il valore nello status senza ricavarlo dai log.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f task.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/03
kubectl apply -f task.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Workspace del TaskRun

Percorso: `~/course-tekton/04`.

1. Tenta di applicare Task e TaskRun.
2. Dichiara il workspace `source` nel Task e associa un `emptyDir`.
3. Scrivi `app.txt` in `$(workspaces.source.path)`.
4. Verifica `Succeeded=True`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Workspace persistente

Percorso: `~/course-tekton/05`.

1. Applica Pipeline e PipelineRun e diagnostica il binding mancante.
2. Completa `volumeClaimTemplate` con `100Mi` e `ReadWriteOnce`.
3. Crea un nuovo PipelineRun.
4. Verifica PipelineRun, PVC e TaskRun associato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 - Ordine della Pipeline

Percorso: `~/course-tekton/06`.

1. Esegui la Pipeline e osserva TaskRun ed eventi.
2. Configura l'ordine `clone -> test -> package`.
3. Associa il workspace `source` anche a `test`.
4. Verifica tre TaskRun riusciti nell'ordine richiesto.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/06` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/06
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Task paralleli

Percorso: `~/course-tekton/07`.

1. Applica gli starter e osserva l'ordine iniziale.
2. Esegui `lint` e `unit` in parallelo dopo `clone`.
3. Esegui `report` soltanto dopo entrambi.
4. Registra start e completion time in `result.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/07` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/07
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Propagazione di un result

Percorso: `~/course-tekton/08`.

1. Esegui la Pipeline e diagnostica il parametro mancante.
2. Passa il result `version` al Task `publish`.
3. Crea un nuovo PipelineRun.
4. Verifica il log esatto `publishing 2.3.1`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/08` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/08
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Result della Pipeline

Percorso: `~/course-tekton/09`.

1. Esegui la Pipeline e verifica che il Task produca l'immagine ma il
   PipelineRun non la esponga.
2. Crea il result Pipeline `image`.
3. Collegalo al result del Task `build`.
4. Verifica `registry.example/app:1.0.0` nello status del PipelineRun.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/09` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/09
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 - Deploy condizionale

Percorso: `~/course-tekton/10`.

1. Applica la Pipeline ed esegui `run-dev.yaml`.
2. Diagnostica perché `deploy` viene eseguito anche per `dev`.
3. Accetta soltanto `staging` e `prod` nella `when`.
4. Verifica `Skipped` per dev e `Succeeded` per staging.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f run-dev.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/10
kubectl apply -f run-dev.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - ServiceAccount dell'EventListener

Percorso: `~/course-tekton/11`.

1. Applica `rbac.yaml` e individua i permessi mancanti.
2. Consenti al ServiceAccount `tekton-trigger` di creare PipelineRun e leggere
   TriggerBinding e TriggerTemplate nel solo Namespace `tekton-lab`.
3. Completa il RoleBinding.
4. Verifica i permessi con `kubectl auth can-i` e conferma che non possa
   leggere Secret.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/11` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f rbac.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/11
kubectl apply -f rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - TriggerTemplate

Percorso: `~/course-tekton/12`.

1. Applica `pipeline.yaml` e tenta di applicare `triggertemplate.yaml`.
2. Dichiara i parametri `repository` e `revision`.
3. Genera un PipelineRun della Pipeline `webhook-build`, passando entrambi i
   valori.
4. Verifica server-side il template completato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/12` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pipeline.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/12
kubectl apply -f pipeline.yaml
kubectl apply -f triggertemplate.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - TriggerBinding

Percorso: `~/course-tekton/13`.

1. Ispeziona `payload.json` e il binding incompleto.
2. Estrai `body.repository.clone_url` nel parametro `repository`.
3. Estrai `body.after` nel parametro `revision`.
4. Applica il TriggerBinding e verifica i campi salvati nel cluster.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/13
kubectl apply -f payload.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - EventListener

Percorso: `~/course-tekton/14`.

1. Applica Pipeline, RBAC e risorse Trigger incomplete.
2. Diagnostica perché l'EventListener non diventa Ready o non crea il
   PipelineRun.
3. Collega binding `git-push` e template `git-push`.
4. Invia `payload.json` al Service `el-git-push` e verifica un PipelineRun
   riuscito.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/14` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/14
kubectl apply -f payload.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Filtro CEL sul branch

Percorso: `~/course-tekton/15`.

1. Invia `payload-main.json` e `payload-feature.json` allo starter.
2. Diagnostica perché entrambi generano PipelineRun.
3. Aggiungi un interceptor CEL che accetti soltanto
   `body.ref == 'refs/heads/main'`.
4. Verifica che main crei un PipelineRun e feature non ne crei alcuno.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/15` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload-main.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/15
kubectl apply -f payload-main.json
kubectl apply -f payload-feature.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 - Mapping del payload

Percorso: `~/course-tekton/16`.

1. Invia `payload.json` e osserva i parametri errati nel PipelineRun.
2. Correggi TriggerBinding e TriggerTemplate affinché propaghino repository,
   revision e nome branch.
3. Non inserire valori statici nel PipelineRun generato.
4. Verifica i tre parametri nello spec e nei log.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/16` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/16
kubectl apply -f payload.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - Trigger multipli

Percorso: `~/course-tekton/17`.

1. Completa l'EventListener `release-events` con due trigger.
2. Il trigger `main-push` deve accettare `refs/heads/main`.
3. Il trigger `tag-push` deve accettare riferimenti con prefisso
   `refs/tags/`.
4. Invia i tre payload forniti e verifica due PipelineRun creati e il payload
   feature rifiutato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/17` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/17
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 - Sicurezza del webhook

Percorso: `~/course-tekton/18`.

1. Applica lo scenario e verifica i privilegi iniziali del ServiceAccount.
2. Rimuovi accesso a Secret, wildcard e verbi non necessari.
3. Mantieni soltanto i permessi richiesti dall'EventListener per generare
   PipelineRun.
4. Verifica che il webhook continui a funzionare e salva test RBAC positivi e
   negativi in `rbac-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/18` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/18
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Troubleshooting EventListener

Percorso: `~/course-tekton/19`.

Lo scenario contiene più errori: ServiceAccount errato, binding inesistente e
parametro non dichiarato.

1. Applica tutti gli starter e raccogli condizioni, eventi e log
   dell'EventListener.
2. Correggi i tre errori senza rinominare le risorse.
3. Invia `payload.json`.
4. Verifica un solo PipelineRun `Succeeded=True` e documenta causa e fix in
   `report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/19` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/19
kubectl apply -f payload.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 - Webhook end-to-end

Percorso: `~/course-tekton/20`.

1. Completa Pipeline, RBAC, TriggerBinding, TriggerTemplate ed EventListener.
2. Accetta soltanto push sul branch `main`.
3. Genera un PipelineRun con repository e revision estratti dal payload.
4. Invia prima `payload-feature.json`, poi `payload-main.json`.
5. Verifica che soltanto main crei un PipelineRun riuscito.
6. Salva risposta HTTP, risorse Trigger, PipelineRun e log in `run.log`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/20` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload-feature.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/20
kubectl apply -f payload-feature.json
kubectl apply -f payload-main.json
kubectl get events -A --sort-by=.lastTimestamp
```
