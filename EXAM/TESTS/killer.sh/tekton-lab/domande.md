# Le 20 domande dell'esame - Tekton Pipelines and Triggers Lab

## Metodo operativo obbligatorio

Ogni domanda è un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale;
2. raccogliere condizioni, eventi, log o risposta HTTP;
3. identificare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla nel cluster.

La sola modifica del file o una risposta teorica non completano il ticket.
Salva comando, errore iniziale, correzione e verifica finale nel file
`evidence.txt` della domanda.

Scenario creato da `setup-tekton-lab.sh`. Gli starter si trovano in
`~/course-tekton/`; tutte le risorse devono essere create nel Namespace
`tekton-lab`.

Vincoli:

- non modificare o disinstallare Tekton Pipelines, Triggers o Dashboard;
- non concedere `cluster-admin` e non usare wildcard RBAC;
- non creare manualmente i PipelineRun che devono provenire da un webhook;
- non esporre Secret nei log;
- conservare nomi e Namespace indicati negli starter.

Comandi utili:

```bash
kubectl -n tekton-lab get task,pipeline,taskrun,pipelinerun
kubectl -n tekton-lab get triggerbinding,triggertemplate,eventlistener
kubectl -n tekton-lab get events --sort-by=.lastTimestamp
kubectl -n tekton-lab logs deploy/el-<nome-eventlistener>
```

---

### Q1 - Task e parametri
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/01`.

1. Applica `task.yaml` e `taskrun.yaml` e raccogli l'errore iniziale.
2. Completa il Task `greet` con parametro stringa `name`, default `platform`.
3. Passa `name=cnpe` dal TaskRun.
4. Verifica `Succeeded=True` e log esatto `hello cnpe`.

### Q2 - Workspace condiviso
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/02`.

1. Applica gli starter e diagnostica perché il Task non può produrre
   l'artefatto.
2. Dichiara il workspace `output`.
3. Implementa gli step `prepare`, `build` e `verify` usando lo stesso path.
4. Verifica ordine degli step e presenza di `artifact.txt`.

### Q3 - Result di un Task
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/03`.

1. Esegui il TaskRun e osserva il result errato.
2. Correggi `task.yaml` affinché il result `commit` valga
   `0123456789abcdef`.
3. Crea un nuovo TaskRun.
4. Verifica il valore nello status senza ricavarlo dai log.

### Q4 - Workspace del TaskRun
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/04`.

1. Tenta di applicare Task e TaskRun.
2. Dichiara il workspace `source` nel Task e associa un `emptyDir`.
3. Scrivi `app.txt` in `$(workspaces.source.path)`.
4. Verifica `Succeeded=True`.

### Q5 - Workspace persistente
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/05`.

1. Applica Pipeline e PipelineRun e diagnostica il binding mancante.
2. Completa `volumeClaimTemplate` con `100Mi` e `ReadWriteOnce`.
3. Crea un nuovo PipelineRun.
4. Verifica PipelineRun, PVC e TaskRun associato.

### Q6 - Ordine della Pipeline
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/06`.

1. Esegui la Pipeline e osserva TaskRun ed eventi.
2. Configura l'ordine `clone -> test -> package`.
3. Associa il workspace `source` anche a `test`.
4. Verifica tre TaskRun riusciti nell'ordine richiesto.

### Q7 - Task paralleli
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/07`.

1. Applica gli starter e osserva l'ordine iniziale.
2. Esegui `lint` e `unit` in parallelo dopo `clone`.
3. Esegui `report` soltanto dopo entrambi.
4. Registra start e completion time in `result.txt`.

### Q8 - Propagazione di un result
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/08`.

1. Esegui la Pipeline e diagnostica il parametro mancante.
2. Passa il result `version` al Task `publish`.
3. Crea un nuovo PipelineRun.
4. Verifica il log esatto `publishing 2.3.1`.

### Q9 - Result della Pipeline
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/09`.

1. Esegui la Pipeline e verifica che il Task produca l'immagine ma il
   PipelineRun non la esponga.
2. Crea il result Pipeline `image`.
3. Collegalo al result del Task `build`.
4. Verifica `registry.example/app:1.0.0` nello status del PipelineRun.

### Q10 - Deploy condizionale
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/10`.

1. Applica la Pipeline ed esegui `run-dev.yaml`.
2. Diagnostica perché `deploy` viene eseguito anche per `dev`.
3. Accetta soltanto `staging` e `prod` nella `when`.
4. Verifica `Skipped` per dev e `Succeeded` per staging.

### Q11 - ServiceAccount dell'EventListener
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/11`.

1. Applica `rbac.yaml` e individua i permessi mancanti.
2. Consenti al ServiceAccount `tekton-trigger` di creare PipelineRun e leggere
   TriggerBinding e TriggerTemplate nel solo Namespace `tekton-lab`.
3. Completa il RoleBinding.
4. Verifica i permessi con `kubectl auth can-i` e conferma che non possa
   leggere Secret.

### Q12 - TriggerTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/12`.

1. Applica `pipeline.yaml` e tenta di applicare `triggertemplate.yaml`.
2. Dichiara i parametri `repository` e `revision`.
3. Genera un PipelineRun della Pipeline `webhook-build`, passando entrambi i
   valori.
4. Verifica server-side il template completato.

### Q13 - TriggerBinding
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/13`.

1. Ispeziona `payload.json` e il binding incompleto.
2. Estrai `body.repository.clone_url` nel parametro `repository`.
3. Estrai `body.after` nel parametro `revision`.
4. Applica il TriggerBinding e verifica i campi salvati nel cluster.

### Q14 - EventListener
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/14`.

1. Applica Pipeline, RBAC e risorse Trigger incomplete.
2. Diagnostica perché l'EventListener non diventa Ready o non crea il
   PipelineRun.
3. Collega binding `git-push` e template `git-push`.
4. Invia `payload.json` al Service `el-git-push` e verifica un PipelineRun
   riuscito.

### Q15 - Filtro CEL sul branch
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/15`.

1. Invia `payload-main.json` e `payload-feature.json` allo starter.
2. Diagnostica perché entrambi generano PipelineRun.
3. Aggiungi un interceptor CEL che accetti soltanto
   `body.ref == 'refs/heads/main'`.
4. Verifica che main crei un PipelineRun e feature non ne crei alcuno.

### Q16 - Mapping del payload
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/16`.

1. Invia `payload.json` e osserva i parametri errati nel PipelineRun.
2. Correggi TriggerBinding e TriggerTemplate affinché propaghino repository,
   revision e nome branch.
3. Non inserire valori statici nel PipelineRun generato.
4. Verifica i tre parametri nello spec e nei log.

### Q17 - Trigger multipli
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/17`.

1. Completa l'EventListener `release-events` con due trigger.
2. Il trigger `main-push` deve accettare `refs/heads/main`.
3. Il trigger `tag-push` deve accettare riferimenti con prefisso
   `refs/tags/`.
4. Invia i tre payload forniti e verifica due PipelineRun creati e il payload
   feature rifiutato.

### Q18 - Sicurezza del webhook
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/18`.

1. Applica lo scenario e verifica i privilegi iniziali del ServiceAccount.
2. Rimuovi accesso a Secret, wildcard e verbi non necessari.
3. Mantieni soltanto i permessi richiesti dall'EventListener per generare
   PipelineRun.
4. Verifica che il webhook continui a funzionare e salva test RBAC positivi e
   negativi in `rbac-check.txt`.

### Q19 - Troubleshooting EventListener
**Ticket:** riproduci il sintomo, identifica la causa radice, correggi e verifica nel cluster.

Percorso: `~/course-tekton/19`.

Lo scenario contiene più errori: ServiceAccount errato, binding inesistente e
parametro non dichiarato.

1. Applica tutti gli starter e raccogli condizioni, eventi e log
   dell'EventListener.
2. Correggi i tre errori senza rinominare le risorse.
3. Invia `payload.json`.
4. Verifica un solo PipelineRun `Succeeded=True` e documenta causa e fix in
   `report.md`.

### Q20 - Webhook end-to-end
**Ticket:** riproduci il sintomo, identifica la causa radice, crea gli elementi mancanti e verifica nel cluster.

Percorso: `~/course-tekton/20`.

1. Completa Pipeline, RBAC, TriggerBinding, TriggerTemplate ed EventListener.
2. Accetta soltanto push sul branch `main`.
3. Genera un PipelineRun con repository e revision estratti dal payload.
4. Invia prima `payload-feature.json`, poi `payload-main.json`.
5. Verifica che soltanto main crei un PipelineRun riuscito.
6. Salva risposta HTTP, risorse Trigger, PipelineRun e log in `run.log`.
