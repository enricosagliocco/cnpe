# Tekton Lab - 20 domande

Namespace: `tekton-lab`. File: `~/course-tekton`.

### Q1 - Task e parametri
Completa `01/task.yaml`: Task `greet`, parametro string `name` default
`platform`, output esatto `hello <name>`. Esegui `taskrun.yaml` con `name=cnpe`.

### Q2 - Step sequenziali
In `02/task.yaml`, crea tre step `prepare`, `build`, `verify`; scrivono e
verificano `/workspace/output/artifact.txt`. Il log deve mostrare l'ordine.

### Q3 - Task results
Il Task `git-metadata` deve scrivere `0123456789abcdef` nel result `commit`.
Il TaskRun deve esporre quel valore in status.

### Q4 - Workspace emptyDir
Completa Task e TaskRun in `04`: workspace `source`, scrittura di
`source/app.txt`, binding `emptyDir`. Il TaskRun deve riuscire.

### Q5 - Workspace PVC
Completa `05/pipelinerun.yaml` con `volumeClaimTemplate` da `100Mi`,
accessMode `ReadWriteOnce`, workspace `source`.

### Q6 - Pipeline ordering
In `06/pipeline.yaml`: `clone`, poi `test`, poi `package` usando `runAfter` e
workspace condiviso. Verifica tre TaskRun riusciti.

### Q7 - Parallel tasks
Esegui `lint` e `unit` in parallelo dopo `clone`; `report` attende entrambi.
Salva start/completion time in `07/result.txt`.

### Q8 - Result propagation
Passa `$(tasks.version.results.version)` al parametro `release` di `publish`.
Il log deve contenere `publishing 2.3.1`.

### Q9 - Pipeline results
Esponi il result Pipeline `image` dal result del Task `build`, valore
`registry.example/app:1.0.0`.

### Q10 - When expression
Esegui `deploy` solo se parametro `environment` è `staging` o `prod`. Il run
`dev` deve saltarlo, il run `staging` deve eseguirlo.

### Q11 - Finally
Aggiungi `notify` in `finally`; deve stampare
`status=$(tasks.status)` anche quando il Task `build` fallisce.

### Q12 - Retries
Configura `unstable` con `retries: 2`. Il Task fallisce nei primi due tentativi
e riesce al terzo usando `$(context.task.retry-count)`.

### Q13 - Timeout
Imposta timeout PipelineRun `tasks: 30s` e Task `slow` timeout `5s`. Il run
deve fallire per timeout in meno di 30 secondi.

### Q14 - Matrix
Abilita API beta e completa la matrix di `test` per `python=3.11,3.12` e
`os=alpine,debian`. Devono essere creati quattro TaskRun.

### Q15 - Optional workspace
Il Task `sign` deve eseguire lo step di firma solo se workspace `credentials`
è bound. Verifica un run skipped e uno con Secret.

### Q16 - Secret credentials
Crea Secret `registry-credentials`, ServiceAccount `pipeline`, e monta il
Secret read-only nel workspace `dockerconfig`. Il Task deve leggere solo la
chiave `config.json`.

### Q17 - RBAC del ServiceAccount
Completa Role/RoleBinding per consentire al ServiceAccount `pipeline` soltanto
get/list/create di ConfigMap in `tekton-lab`. Il Task crea `build-metadata` ma
non può leggere Secret.

### Q18 - Supply chain pipeline
Completa Pipeline `secure-build`: `clone -> test -> sbom -> scan -> publish`.
`publish` usa una when expression sul result `scan=passed`; `finally` stampa
lo stato aggregato.

### Q19 - Troubleshooting
`19/pipelinerun.yaml` fallisce per tre motivi: parametro errato, workspace non
bound e TaskRef inesistente. Correggili senza cambiare i nomi delle risorse e
scrivi diagnosi in `19/report.md`.

### Q20 - Simulazione a tempo
In 25 minuti completa `20/pipeline.yaml`: parametri repo/revision/image,
workspace PVC, clone, test paralleli lint/unit, build, scan gate, publish,
finally cleanup e Pipeline results commit/image. Salva log in `20/run.log`.
