# Le 20 domande dell'esame — Tekton Lab (simulatore lab)

Scenario deployato da `setup-tekton-lab.sh`. Manifest e file starter in
`~/course-tekton/`. Tutte le risorse degli esercizi devono essere create nel
Namespace `tekton-lab`, salvo diversa indicazione.

**Vincolo:** non disinstallare Tekton Pipelines o Tekton Dashboard. Puoi
modificare Task, Pipeline, TaskRun, PipelineRun, workspace, RBAC e risorse
applicative, ma non i componenti core installati nel Namespace
`tekton-pipelines`.

Accesso GUI (port-forward):

```bash
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30120:9097
```

Credenziali:
- Tekton Dashboard non richiede credenziali in questo lab.
- Apri `http://<node>:30120` oppure `http://127.0.0.1:30120`.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 – Task e parametri

Percorso: `~/course-tekton/01`.


Il Task `greet` e il relativo TaskRun sono incompleti in `01/`.

1. Completa `task.yaml` con il parametro string `name`, default `platform`.
2. Usa il parametro nello step per produrre esattamente `hello <name>`.
3. Completa `taskrun.yaml` passando `name=cnpe`.
4. Applica entrambi i file e verifica un TaskRun `Succeeded=True` con log
   `hello cnpe`.

---

### Q2 – Step sequenziali

Percorso: `~/course-tekton/02`.


Il Task `sequential-build` in `02/task.yaml` non contiene step.

1. Implementa gli step `prepare`, `build` e `verify`.
2. Usa il workspace `output` per creare e verificare
   `/workspace/output/artifact.txt`.
3. Applica `task.yaml` e `taskrun.yaml`.
4. Verifica `Succeeded=True` e che i log mostrino i tre step nell'ordine.

---

### Q3 – Task results

Percorso: `~/course-tekton/03`.


Il Task `git-metadata` in `03/task.yaml` scrive un placeholder nel result.

1. Correggi lo step affinché scriva `0123456789abcdef` nel result `commit`.
2. Applica `task.yaml` e `taskrun.yaml`.
3. Verifica che il TaskRun riesca e che
   `.status.results[?(@.name=="commit")].value` contenga il valore richiesto.

---

### Q4 – Workspace emptyDir

Percorso: `~/course-tekton/04`.


Task e TaskRun in `04/` hanno workspace e percorso mancanti.

1. Dichiara il workspace `source` nel Task.
2. Scrivi `app.txt` in `$(workspaces.source.path)`.
3. Associa il workspace a un `emptyDir` nel TaskRun.
4. Applica i file e verifica `Succeeded=True`.

---

### Q5 – Workspace PVC

Percorso: `~/course-tekton/05`.


La Pipeline `build-pipeline` è completa, ma `05/pipelinerun.yaml` non fornisce
lo storage richiesto.

1. Completa il binding `source` con `volumeClaimTemplate`.
2. Richiedi `100Mi` e access mode `ReadWriteOnce`.
3. Applica Pipeline e PipelineRun.
4. Verifica PipelineRun riuscito, PVC creato e TaskRun associato al PVC.

---

### Q6 – Pipeline ordering

Percorso: `~/course-tekton/06`.


La Pipeline `ordered-build` contiene i tre Task ma `test` e `package` possono
partire nel momento sbagliato e `test` non vede il workspace.

1. Esegui `test` dopo `clone`.
2. Esegui `package` dopo `test`.
3. Associa `source` al Task `test`.
4. Applica `pipeline.yaml` e `pipelinerun.yaml`.
5. Verifica tre TaskRun riusciti nell'ordine `clone`, `test`, `package`.

---

### Q7 – Parallel tasks

Percorso: `~/course-tekton/07`.


La Pipeline `parallel-tests` non definisce le dipendenze tra i Task.

1. Fai partire `lint` e `unit` in parallelo dopo `clone`.
2. Fai attendere a `report` il completamento di entrambi.
3. Applica Pipeline e PipelineRun.
4. Verifica dalla Dashboard che gli intervalli temporali di `lint` e `unit`
   si sovrappongano.
5. Salva start time e completion time dei TaskRun in `07/result.txt`.

---

### Q8 – Result propagation

Percorso: `~/course-tekton/08`.


La Pipeline `release` esegue `version` e `publish`, ma non passa il result.

1. Applica `version-task.yaml`.
2. Passa `$(tasks.version.results.version)` al parametro `release` di
   `publish`.
3. Applica Pipeline e PipelineRun.
4. Verifica `Succeeded=True` e il log esatto `publishing 2.3.1`.

---

### Q9 – Pipeline results

Percorso: `~/course-tekton/09`.


La Pipeline `image-build` produce l'immagine nel Task `build`, ma non la
espone nello status della Pipeline.

1. Aggiungi il result Pipeline `image` collegato al result del Task `build`.
2. Applica Pipeline e PipelineRun.
3. Verifica `Succeeded=True` e il result
   `registry.example/app:1.0.0` nello status del PipelineRun.

---

### Q10 – When expression

Percorso: `~/course-tekton/10`.


Il Task `deploy` della Pipeline `conditional-deploy` viene sempre eseguito.

1. Completa la `when` expression per accettare soltanto `staging` o `prod`.
2. Applica la Pipeline.
3. Esegui `run-dev.yaml` e verifica che `deploy` sia `Skipped`.
4. Esegui `run-staging.yaml` e verifica che `deploy` sia `Succeeded`.

---

### Q11 – Finally

Percorso: `~/course-tekton/11`.


La Pipeline `failing-build` fallisce intenzionalmente e non ha cleanup finale.

1. Aggiungi il Task `notify` nella sezione `finally`.
2. Fagli stampare `status=$(tasks.status)`.
3. Applica Pipeline e PipelineRun.
4. Verifica che `build` fallisca, che `notify` venga comunque eseguito e che
   il suo log riporti lo stato aggregato.

---

### Q12 – Retries

Percorso: `~/course-tekton/12`.


Il Task `unstable` fallisce al primo tentativo perché `retries` è impostato a
zero.

1. Configura `retries: 2`.
2. Applica Pipeline e PipelineRun.
3. Verifica nei log i retry count `0`, `1` e `2`.
4. Verifica che il PipelineRun termini `Succeeded=True` al terzo tentativo.

---

### Q13 – Timeout

Percorso: `~/course-tekton/13`.


Il Task `slow` dorme 20 secondi e i timeout correnti sono troppo permissivi.

1. Imposta il timeout del Task `slow` a `5s`.
2. Imposta `timeouts.tasks: 30s` nel PipelineRun.
3. Applica i file.
4. Verifica che il Task termini per timeout dopo circa 5 secondi e che il
   PipelineRun fallisca in meno di 30 secondi.

---

### Q14 – Matrix

Percorso: `~/course-tekton/14`.


La Pipeline `matrix-tests` contiene una matrix vuota.

1. Abilita le API beta Tekton se richiesto dalla versione installata.
2. Configura `python=3.11,3.12` e `os=alpine,debian`.
3. Applica Pipeline e PipelineRun.
4. Verifica la creazione di quattro combinazioni TaskRun e quattro log
   distinti.

---

### Q15 – Optional workspace

Percorso: `~/course-tekton/15`.


Il Task `sign` dichiara un workspace opzionale, ma firma anche quando non è
associato.

1. Condiziona lo step con `$(workspaces.credentials.bound)`.
2. Applica Secret e Task.
3. Esegui `run-unbound.yaml` e verifica che lo step sia saltato.
4. Esegui `run-bound.yaml` e verifica il log `signed`.

---

### Q16 – Secret credentials

Percorso: `~/course-tekton/16`.


Secret, ServiceAccount e Task sono presenti, ma il TaskRun non monta le
credenziali.

1. Applica `security.yaml` e `task.yaml`.
2. Completa il workspace `dockerconfig` del TaskRun usando il Secret
   `registry-credentials` in sola lettura.
3. Assicurati che sia esposta soltanto la chiave `config.json`.
4. Verifica `Succeeded=True` senza stampare il contenuto del Secret nei log.

---

### Q17 – RBAC del ServiceAccount

Percorso: `~/course-tekton/17`.


Il ServiceAccount `pipeline` esiste, ma Role e RoleBinding sono vuoti.

1. Concedi soltanto `get`, `list` e `create` sui ConfigMap in `tekton-lab`.
2. Collega il Role al ServiceAccount `pipeline`.
3. Applica RBAC, Task e TaskRun.
4. Verifica che venga creato il ConfigMap `build-metadata`.
5. Verifica con `kubectl auth can-i` che il ServiceAccount non possa leggere
   Secret.

---

### Q18 – Supply chain pipeline

Percorso: `~/course-tekton/18`.


La Pipeline `secure-build` in `18/pipeline.yaml` è priva di Task.

1. Implementa `clone -> test -> sbom -> scan -> publish`.
2. Fai produrre a `scan` il result `passed`.
3. Esegui `publish` solo quando il result vale `passed`.
4. Aggiungi un Task `finally` che stampi lo stato aggregato.
5. Crea ed esegui un PipelineRun con workspace `emptyDir`.
6. Verifica ordine, gate di scansione, pubblicazione e Task finale.

---

### Q19 – Troubleshooting

Percorso: `~/course-tekton/19`.


`19/pipelinerun.yaml` punta a una Pipeline inesistente, usa un parametro errato
e non associa il workspace richiesto.

1. Riproduci il fallimento applicando il file e raccogli il messaggio.
2. Crea o correggi la Pipeline mantenendo i nomi indicati.
3. Correggi parametro e workspace senza rinominare il PipelineRun.
4. Verifica un nuovo PipelineRun `Succeeded=True`.
5. Documenta causa, fix e verifica in `19/report.md`.

---

### Q20 – Simulazione a tempo

Percorso: `~/course-tekton/20`.


`20/pipeline.yaml` e `20/pipelinerun.yaml` contengono soltanto lo scheletro
della supply chain finale.

1. Completa parametri `repo`, `revision`, `image` e workspace PVC.
2. Implementa clone, test paralleli `lint`/`unit`, build, scan gate e publish.
3. Aggiungi cleanup in `finally` e Pipeline results `commit`/`image`.
4. Correggi il PipelineRun e avvialo.
5. Verifica `Succeeded=True`, risultati valorizzati e cleanup eseguito.
6. Salva i log completi in `20/run.log`.
