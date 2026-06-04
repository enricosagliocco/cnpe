# Le 20 domande dell'esame — Tekton (simulatore lab)

Scenario deployato da `setup-lab.sh`. Manifest in `~/course/tekton-lab/`.  
**Vincolo:** tutte le Pipeline e i PipelineRun devono usare il namespace `builder`. Non disinstallare Tekton.

Verifica le soluzioni in `risposte.md`.

---

### Q1 – Verifica installazione Tekton

Tekton Pipelines e Dashboard sono installati nel cluster (release v0.68). I controller risiedono in `tekton-pipelines`.

1. Verifica che `tekton-pipelines-webhook` e `tekton-pipelines-controller` siano Available
2. Verifica che il namespace `builder` esista
3. Elenca Task e Pipeline presenti in `builder` con label `cnpe-lab=true`

---

### Q2 – Accesso Tekton Dashboard

Il Dashboard è esposto su NodePort **30220** (override con variabile `DASHBOARD_NODEPORT` nello script).

Accesso GUI (port-forward):

```bash
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30220:9097
```

Credenziali:

- Il Dashboard in lab non richiede login dedicato
- Se richiesto token, verifica ServiceAccount/Secret:

```bash
kubectl -n tekton-pipelines get sa,secret
```

1. Apri il Dashboard da `http://<node>:30220` (sostituisci `<node>` con l'IP Minikube)
2. Conferma di vedere il namespace `builder` nella UI

---

### Q3 – RBAC ServiceAccount pipeline-runner

Il ServiceAccount `pipeline-runner` nel namespace `builder` deve poter eseguire `kubectl` nei Task. Il file `/course/tekton-lab/rbac.yaml` contiene un RoleBinding errato.

1. Identifica perché `onboard-butter` fallisce con errori RBAC
2. Correggi il RoleBinding `pipeline-runner-binding` affinché il subject punti al ServiceAccount nel namespace **builder**
3. Verifica con `kubectl auth can-i create namespaces --as=system:serviceaccount:builder:pipeline-runner`

---

### Q4 – Task cnpe-build-image (parametri)

Il Task `cnpe-build-image` in `builder` fallisce perché lo script referenzia un parametro inesistente.

1. Correggi il Task in `/course/tekton-lab/tekton-resources.yaml` (o con `kubectl edit`) sostituendo `$(params.git-revision)` con il nome parametro corretto
2. Applica la modifica al cluster
3. Conferma che il parametro dichiarato sia `gitRevision` di tipo string

---

### Q5 – Pipeline cnpe-release (DAG e finally)

Il Pipeline `cnpe-release` in `builder` non esegue correttamente la catena fetch → build → deploy e il task `finally` non reagisce ai fallimenti.

1. Correggi `runAfter` del task `build`: deve dipendere dal task **fetch**, non da `checkout`
2. Correggi la condizione `when` del task `alert-on-fail` usando lo status del task **build** (non `build-image`)
3. Applica il Pipeline aggiornato

---

### Q6 – PipelineRun cnpe-release (ServiceAccount e workspace)

Esegui una release verso il namespace `cnpe-staging` usando il PVC workspace preparato dal lab.

1. Crea un PipelineRun da `/course/tekton-lab/` con:
   - `pipelineRef.name: cnpe-release`
   - `serviceAccountName: pipeline-runner`
   - parametro `gitRevision: v1.2.3`
   - parametro `targetNamespace: cnpe-staging`
   - workspace `shared-manifests` bound al PVC `cnpe-manifests-ws`
2. Attendi completamento con `tkn pipelinerun logs -f -n builder`
3. Verifica che esista il ConfigMap `cnpe-built` nel namespace `cnpe-staging`

---

### Q7 – Pipeline cnpe-team-onboard (team butter)

Dopo il fix RBAC, esegui l'onboarding del team **butter**.

1. Elimina il PipelineRun fallito `onboard-butter` se ancora presente
2. Avvia `cnpe-team-onboard` con parametro `team-name=butter` e `serviceAccountName: pipeline-runner`
3. Verifica che esista il namespace `team-butter` e un RoleBinding `team-butter-view`

---

### Q8 – Pipeline cnpe-team-onboard (team croissant)

1. Avvia `cnpe-team-onboard` con parametro `team-name=croissant` e `serviceAccountName: pipeline-runner`
2. Verifica che esista il namespace `team-croissant`
3. Conferma che entrambi i PipelineRun di onboarding siano in stato Succeeded

---

### Q9 – Correzione Pipeline cnpe-policy-scan

Il Pipeline `cnpe-policy-scan` deve eseguire due scan con pattern diversi. Attualmente il secondo task riusa il parametro sbagliato.

1. Apri `/course/tekton-lab/tekton-resources.yaml` e correggi il task **scan-b** del Pipeline `cnpe-policy-scan`
2. Il parametro `forbidden` del task `scan-b` deve usare `$(params.forbidden2)`, non `forbidden1`
3. Applica la modifica

---

### Q10 – Esecuzione scan team-sandwich

Nel namespace `team-sandwich` è presente il Pod `crypto-miner` (caricato dallo script di setup).

1. Esegui `cnpe-policy-scan` con:
   - `team-name: sandwich`
   - `forbidden1: miner`
   - `forbidden2: crypto`
   - `serviceAccountName: pipeline-runner`
2. Il PipelineRun deve **fallire** (pattern vietato trovato)
3. Scrivi i log del PipelineRun in `/course/tekton-lab/scan-sandwich.log`

---

### Q11 – Task cnpe-fetch-config e workspace

Il Task `cnpe-fetch-config` scrive file nel workspace condiviso.

1. Spiega (in note o README locale) quale path usa lo step `write-manifest` nel workspace
2. Dopo un PipelineRun `cnpe-release` riuscito, verifica che i TaskRun `fetch` e `build` abbiano completato senza errori di mount workspace

---

### Q12 – Debug TaskRun fallito

Un TaskRun del task `build` è in stato Failed.

1. Ottieni il nome del Pod del TaskRun con `kubectl -n builder get pods -l tekton.dev/taskRun`
2. Mostra i log del container step `step-build`
3. Incolla l'errore principale in `/course/tekton-lab/build-error.txt`

---

### Q13 – Pulizia PipelineRun

1. Elimina tutti i PipelineRun nel namespace `builder` in stato Failed o Cancelled
2. Elimina i TaskRun orfani associati
3. Conferma con `tkn pipelinerun list -n builder` che restino solo run Succeeded utili per audit (opzionale: zero run)

---

### Q14 – Task cnpe-kubectl-deploy

Il Task `cnpe-kubectl-deploy` crea namespace e ConfigMap da file nel workspace.

1. Verifica che dipenda dal task `build` tramite `runAfter` nel Pipeline `cnpe-release`
2. Dopo Q6, conferma che il namespace `cnpe-staging` contenga i dati prodotti dalla pipeline

---

### Q15 – Parametri Pipeline cnpe-release

1. Elenca i tre parametri definiti nel Pipeline `cnpe-release` e i valori usati nel tuo PipelineRun di Q6
2. Verifica che `imageRepo` usi il default `registry.example/cnpe-app` se non sovrascritto

---

### Q16 – Finally alert-on-fail

1. Simula un fallimento del task `build` (es. parametro errato temporaneo) e conferma che il task `finally` `alert-on-fail` venga eseguito dopo la correzione di Q5
2. Verifica nei log del TaskRun `alert-on-fail` la presenza del messaggio `ALERT:`

---

### Q17 – Risorse compute step (timeout / OOM)

1. Documenta in `/course/tekton-lab/notes-resources.txt` quali campi del Task o PipelineRun useresti per aumentare `limits.memory` di uno step e il timeout del PipelineRun
2. Non è richiesto applicare la modifica se il lab completa senza OOM

---

### Q18 – Confronto tkn vs kubectl

1. Esegui `tkn pipeline list -n builder` e `kubectl -n builder get pipeline`
2. Esegui `tkn pipelinerun describe <nome-run> -n builder` per l'ultimo run di `cnpe-release`

---

### Q19 – PVC cnpe-manifests-ws

1. Verifica che il PVC `cnpe-manifests-ws` in `builder` sia Bound
2. Se usi `emptyDir` nel PipelineRun, spiega perché i dati non persistono tra due run distinti

---

### Q20 – Verifica end-to-end

1. RBAC `pipeline-runner` funzionante
2. `cnpe-release` Succeeded con namespace `cnpe-staging` popolato
3. `cnpe-team-onboard` Succeeded per `butter` e `croissant`
4. `cnpe-policy-scan` Failed per `team-sandwich` con log salvato (Q10)
5. Screenshot o nota che il Dashboard mostra i run attesi

---
