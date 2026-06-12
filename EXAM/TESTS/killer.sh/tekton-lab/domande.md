# Tekton Pipelines and Triggers Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.

Le domande sono autonome: ogni directory contiene Pipeline, RBAC, risorse
Trigger e payload necessari allo scenario. Le risorse delle domande Q11-Q20
usano nomi distinti, quindi non richiedono lo svolgimento delle domande
precedenti. Da Q14 in poi usa `send-event.sh` per effettuare il port-forward,
inviare il payload JSON e salvare la risposta HTTP.


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

1. Esamina `rbac.yaml` e individua i permessi mancanti.
2. Consenti al ServiceAccount `q11-trigger` di creare PipelineRun e leggere
   TriggerBinding e TriggerTemplate nel solo Namespace `tekton-lab`.
3. Completa il RoleBinding.
4. Verifica che possa creare PipelineRun e leggere TriggerBinding, ma non
   leggere Secret né creare risorse fuori da `tekton-lab`.

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
kubectl auth can-i create pipelineruns.tekton.dev -n tekton-lab \
  --as=system:serviceaccount:tekton-lab:q11-trigger
kubectl auth can-i get triggerbindings.triggers.tekton.dev -n tekton-lab \
  --as=system:serviceaccount:tekton-lab:q11-trigger
kubectl auth can-i get secrets -n tekton-lab \
  --as=system:serviceaccount:tekton-lab:q11-trigger
```

---

### Q12 - TriggerTemplate

Percorso: `~/course-tekton/12`.

1. Applica `pipeline.yaml` e tenta di applicare `triggertemplate.yaml`.
2. Dichiara i parametri `repository` e `revision`.
3. Nel resource template genera un PipelineRun con prefisso
   `q12-webhook-build-` per la Pipeline `q12-webhook-build`, passando entrambi
   i valori tramite `$(tt.params.*)`.
4. Applica il TriggerTemplate `q12-git-push` e verifica nello YAML salvato che
   non siano rimasti valori statici o `TODO`.

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
kubectl -n tekton-lab get triggertemplate q12-git-push -o yaml
```

---

### Q13 - TriggerBinding

Percorso: `~/course-tekton/13`.

1. Ispeziona `payload.json` e il binding incompleto.
2. Estrai `body.repository.clone_url` nel parametro `repository`.
3. Estrai `body.after` nel parametro `revision`.
4. Applica il TriggerBinding `q13-git-push` e verifica i campi salvati nel
   cluster. Il payload è un dato di test e non è una risorsa Kubernetes.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f triggerbinding.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/13
kubectl apply -f triggerbinding.yaml
kubectl -n tekton-lab get triggerbinding q13-git-push -o yaml
```

---

### Q14 - EventListener

Percorso: `~/course-tekton/14`.

1. Applica `pipeline.yaml`, `rbac.yaml` e `triggers.yaml`.
2. Diagnostica perché l'EventListener non diventa Ready o non crea il
   PipelineRun.
3. Collega binding e template `q14-git-push` senza modificare Pipeline,
   payload o RBAC.
4. Attendi l'EventListener, invia `payload.json` con `send-event.sh` e verifica
   un solo PipelineRun con label `lab.cnpe.io/question=q14`.
5. Nei log devono comparire
   `https://git.example/portal.git@abc123`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/14` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/14
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q14
run=$(kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q14 -o jsonpath='{.items[0].metadata.name}')
kubectl -n tekton-lab logs \
  -l "tekton.dev/pipelineRun=$run" --all-containers=true
```

---

### Q15 - Filtro CEL sul branch

Percorso: `~/course-tekton/15`.

1. Applica tutti i manifest e invia i due payload allo starter con
   `send-event.sh`.
2. Conferma che, senza interceptor, entrambi generano PipelineRun; elimina
   quindi soltanto i PipelineRun con label `lab.cnpe.io/question=q15`.
3. Aggiungi un interceptor CEL che accetti soltanto
   `body.ref == 'refs/heads/main'`.
4. Riapplica `triggers.yaml`, invia prima feature e poi main, e verifica che
   il conteggio rimanga invariato per feature e aumenti di uno per main.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/15` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/15
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload-feature.json response-feature.json
./send-event.sh payload-main.json response-main.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q15
```

---

### Q16 - Mapping del payload

Percorso: `~/course-tekton/16`.

1. Applica Pipeline, RBAC e risorse Trigger, quindi invia `payload.json` con
   `send-event.sh` e osserva i parametri statici nel PipelineRun.
2. Correggi TriggerBinding e TriggerTemplate affinché propaghino repository,
   revision e nome branch.
3. Non inserire valori statici nel PipelineRun generato.
4. Elimina i PipelineRun Q16 precedenti, riapplica e verifica nello spec e nei
   log: repository `https://git.example/payments.git`, revision `def456` e
   branch `release`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/16` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/16
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q16 -o yaml
```

---

### Q17 - Trigger multipli

Percorso: `~/course-tekton/17`.

1. Applica Pipeline e RBAC, poi completa l'EventListener
   `q17-release-events` con due trigger.
2. Il trigger `main-push` deve accettare `refs/heads/main`.
3. Il trigger `tag-push` deve accettare riferimenti con prefisso
   `refs/tags/`.
4. Entrambi devono usare binding e template `q17-release-event`.
5. Applica `triggers.yaml`, invia i tre payload con `send-event.sh` e verifica
   esattamente due PipelineRun Q17: uno per main e uno per tag.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/17` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/17
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload-feature.json response-feature.json
./send-event.sh payload-main.json response-main.json
./send-event.sh payload-tag.json response-tag.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q17
```

---

### Q18 - Sicurezza del webhook

Percorso: `~/course-tekton/18`.

1. Applica `pipeline.yaml`, `rbac.yaml` e `triggers.yaml`, quindi verifica i
   privilegi iniziali del ServiceAccount `q18-trigger`.
2. Rimuovi accesso a Secret, wildcard e verbi non necessari.
3. Mantieni soltanto `create` sui PipelineRun e `get` su TriggerBinding e
   TriggerTemplate nel Namespace `tekton-lab`.
4. Invia `payload.json` con `send-event.sh`, verifica un PipelineRun Q18
   riuscito e salva in `rbac-check.txt` test RBAC positivi e negativi.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/18` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/18
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload.json
kubectl auth can-i create pipelineruns.tekton.dev -n tekton-lab \
  --as=system:serviceaccount:tekton-lab:q18-trigger
kubectl auth can-i get secrets -n tekton-lab \
  --as=system:serviceaccount:tekton-lab:q18-trigger
```

---

### Q19 - Troubleshooting EventListener

Percorso: `~/course-tekton/19`.

Lo scenario contiene più errori: ServiceAccount errato, binding inesistente e
parametro non dichiarato.

1. Applica Pipeline, RBAC e Trigger, quindi raccogli condizioni, eventi e log
   dell'EventListener `q19-broken-hook`.
2. Correggi i tre errori usando ServiceAccount `q19-trigger`, binding
   `q19-broken-hook` e parametro template `revision`, senza rinominare le
   risorse.
3. Riapplica `triggers.yaml` e invia `payload.json` con `send-event.sh`.
4. Verifica un solo PipelineRun con label `lab.cnpe.io/question=q19`,
   `Succeeded=True`, e documenta causa, evidenze e fix in `report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/19` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/19
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
kubectl -n tekton-lab describe eventlistener q19-broken-hook
./send-event.sh payload.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q19
```

---

### Q20 - Webhook end-to-end

Percorso: `~/course-tekton/20`.

1. Completa Pipeline, RBAC, TriggerBinding, TriggerTemplate ed EventListener.
2. Accetta soltanto push sul branch `main`.
3. Genera un PipelineRun con repository e revision estratti dal payload.
4. Il PipelineRun deve avere prefisso `final-webhook-build-` e label
   `lab.cnpe.io/question=q20`.
5. Applica tutte le risorse e invia prima `payload-feature.json`, poi
   `payload-main.json`, usando `send-event.sh`.
6. Verifica che soltanto main crei un PipelineRun riuscito e che i log
   contengano `https://git.example/final.git@final123`.
7. Salva risposta HTTP, risorse Trigger, PipelineRun e log in `run.log`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-tekton/20` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server \
  -f pipeline.yaml -f rbac.yaml -f triggers.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-tekton/20
kubectl apply -f pipeline.yaml -f rbac.yaml -f triggers.yaml
./send-event.sh payload-feature.json response-feature.json
./send-event.sh payload-main.json response-main.json
kubectl -n tekton-lab get pipelineruns \
  -l lab.cnpe.io/question=q20
```
