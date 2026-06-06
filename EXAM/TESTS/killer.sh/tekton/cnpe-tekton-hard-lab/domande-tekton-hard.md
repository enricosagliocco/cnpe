# CNPE Hard Lab — Tekton Exam-like

Scenario: `tekton-hard`  
Namespace Tekton: `builder`  
Namespace applicativi: `apps-dev`, `apps-prod`  
Directory: `/course/tekton-hard`  
Tempo consigliato: 90 minuti.

Questo lab è volutamente più difficile: diverse risorse esistono già ma sono incomplete o sbagliate. Devi fare troubleshooting usando `kubectl`, eventuale `tkn`, log dei TaskRun e manifest in `/course/tekton-hard`.

Il repository Git è su Gitea:

```bash
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_ORG="${GITEA_ORG:-organization}"
REPO_NAME="tekton-hard-app"
```

---

## Q1 — Ispezione iniziale

Verifica lo stato di:

- Tekton Pipelines e Triggers;
- namespace `builder`, `apps-dev`, `apps-prod`;
- Task, Pipeline, EventListener, TriggerBinding, TriggerTemplate;
- repository remoto indicato in `/course/tekton-hard/README.txt`.

Salva tutto in:

```bash
/course/tekton-hard/q1-initial-status.txt
```

---

## Q2 — Prima PipelineRun dev

Esegui la PipelineRun dev:

```bash
kubectl create -f /course/tekton-hard/30-pipelinerun-dev-broken.yaml
```

Identifica:

- nome della PipelineRun;
- primo TaskRun fallito;
- motivo del fallimento;
- log del container principale.

Salva in:

```bash
/course/tekton-hard/q2-first-failure.txt
```

---

## Q3 — Fix clone/test workspace

La pipeline clona il repository in una sottodirectory, ma il test cerca lo script nel posto sbagliato.

Correggi la Task coinvolta, senza cambiare la struttura del repository.

Requisiti:

- `source-test` deve eseguire `scripts/check.sh`;
- il path deve essere corretto rispetto al workspace;
- rilancia una PipelineRun dev;
- il task di test deve passare.

Salva il nuovo YAML della Task in:

```bash
/course/tekton-hard/q3-source-test-task.yaml
```

---

## Q4 — Git revision robusta

Il task `git-fetch` usa un approccio fragile per `revision`.

Deve funzionare sia con:

- branch, per esempio `main` o `release`;
- commit SHA ricevuto da webhook Gitea.

Modifica la Task in modo che:

1. cloni il repo;
2. entri nella directory clonata;
3. faccia checkout di `$(params.revision)`;
4. scriva il commit effettivo in `$(results.commit.path)`.

Salva il nuovo YAML in:

```bash
/course/tekton-hard/q4-git-fetch-task.yaml
```

---

## Q5 — Parallelismo scan

La Pipeline contiene due scan (`forbidden1`, `forbidden2`), ma non sono realmente parallele.

Modifica la Pipeline `app-delivery`:

- `scan-forbidden1` e `scan-forbidden2` devono partire entrambi dopo `render`;
- `deploy` deve partire solo dopo entrambi gli scan;
- non cambiare i nomi dei task.

Salva la Pipeline aggiornata in:

```bash
/course/tekton-hard/q5-pipeline-parallel.yaml
```

---

## Q6 — Render manifest e immagine parametrica

La Task `render-kustomize` accetta il parametro `image`, ma il manifest renderizzato non usa davvero quel valore.

Correggi il render in modo che il manifest finale contenga l’immagine passata dal parametro Pipeline.

Requisiti:

- non modificare direttamente il repo Git per hardcodare l’immagine;
- il manifest renderizzato deve rimanere valido YAML;
- `q6-rendered-dev.yaml` deve contenere l’immagine `nginx:1.27-alpine`.

Salva il manifest renderizzato in:

```bash
/course/tekton-hard/q6-rendered-dev.yaml
```

---

## Q7 — RBAC cross-namespace

La Pipeline deve applicare manifest in `apps-dev` e `apps-prod` usando la ServiceAccount `builder` nel namespace `builder`.

Correggi l’RBAC in `/course/tekton-hard/01-cross-namespace-rbac-broken.yaml`.

Requisiti:

- non usare `cluster-admin`;
- non usare `ClusterRoleBinding` se non necessario;
- RoleBinding in `apps-dev` e `apps-prod` devono riferire la ServiceAccount corretta;
- devono essere permessi Deployment e Service.

Salva verifica con:

```bash
kubectl auth can-i patch deployments -n apps-dev --as system:serviceaccount:builder:builder
kubectl auth can-i patch deployments -n apps-prod --as system:serviceaccount:builder:builder
```

in:

```bash
/course/tekton-hard/q7-rbac-check.txt
```

---

## Q8 — PipelineRun dev end-to-end

Rilancia la PipelineRun dev.

Requisiti:

- PipelineRun `Succeeded=True`;
- Deployment `dev-tekton-hard-app` creato in `apps-dev`;
- Service `dev-tekton-hard-app` creato in `apps-dev`;
- immagine del Deployment uguale a `nginx:1.27-alpine`.

Salva:

```bash
/course/tekton-hard/q8-dev-e2e.txt
```

---

## Q9 — PipelineRun prod release

Esegui la PipelineRun prod:

```bash
kubectl create -f /course/tekton-hard/31-pipelinerun-prod-broken.yaml
```

Requisiti:

- usa branch `release`;
- environment `prod`;
- immagine finale `httpd:2-alpine`;
- Deployment `prod-tekton-hard-app` in `apps-prod`;
- repliche prod = 2.

Salva:

```bash
/course/tekton-hard/q9-prod-e2e.txt
```

---

## Q10 — Trigger main branch

Il trigger Gitea è troppo restrittivo e non genera PipelineRun sui push `main`.

Correggi `EventListener`/CEL in modo che accetti almeno:

- `refs/heads/main`;
- `refs/heads/release`.

Non deve accettare branch arbitrari.

Salva il nuovo EventListener:

```bash
/course/tekton-hard/q10-eventlistener.yaml
```

---

## Q11 — TriggerBinding Gitea

Correggi `TriggerBinding`:

- `git-url` deve arrivare dal clone URL;
- `git-revision` deve usare il commit SHA del push;
- conserva anche `git-branch` come ref branch.

Per Gitea push payload usa:

```text
body.repository.clone_url
body.after
body.ref
```

Salva:

```bash
/course/tekton-hard/q11-triggerbinding.yaml
```

---

## Q12 — TriggerTemplate branch-aware

La `TriggerTemplate` manda tutto in prod. Correggila.

Requisiti minimi:

- PipelineRun generate da trigger devono avere label:
  - `source=gitea`
  - `exam=cnpe`
- push su `main` deve distribuire in `dev`;
- push su `release` deve distribuire in `prod`.

Puoi risolvere con due trigger separati nell’EventListener oppure con due template. Documenta la scelta in:

```bash
/course/tekton-hard/q12-trigger-design.txt
```

---

## Q13 — Simula webhook main

Simula un push Gitea su main verso l’EventListener NodePort.

Payload minimo:

```json
{
  "after": "main",
  "ref": "refs/heads/main",
  "repository": {
    "clone_url": "REPO_URL"
  }
}
```

Nota: per test locale puoi usare `"after": "main"` se hai già reso `git-fetch` compatibile con branch e SHA.

Verifica:

- viene creata una PipelineRun con label `source=gitea,exam=cnpe`;
- deploy va su `apps-dev`;
- non modifica `apps-prod`.

Salva:

```bash
/course/tekton-hard/q13-trigger-main.txt
```

---

## Q14 — Simula webhook release

Simula un push Gitea su release.

Verifica:

- viene creata una PipelineRun con label `source=gitea,exam=cnpe`;
- deploy va su `apps-prod`;
- usa environment `prod`;
- Deployment prod resta a 2 repliche.

Salva:

```bash
/course/tekton-hard/q14-trigger-release.txt
```

---

## Q15 — Logs richiesti stile esame

Prendi l’ultima PipelineRun triggerata e salva i log completi in:

```bash
/course/tekton-hard/q15-last-run.log
```

Devono comparire almeno i log dei task:

- `fetch`;
- `test`;
- `render`;
- `scan-forbidden1`;
- `scan-forbidden2`;
- `deploy`.

---

## Q16 — Cleanup storico

Mantieni solo le ultime 3 PipelineRun in namespace `builder`.

Non cancellare:

- Task;
- Pipeline;
- EventListener;
- TriggerBinding;
- TriggerTemplate.

Salva lo stato dopo cleanup:

```bash
/course/tekton-hard/q16-cleanup.txt
```

---

## Q17 — Report finale

Crea:

```bash
/course/tekton-hard/final-report.txt
```

Deve contenere:

1. ultima PipelineRun manuale dev riuscita;
2. ultima PipelineRun manuale prod riuscita;
3. ultima PipelineRun da trigger main riuscita;
4. ultima PipelineRun da trigger release riuscita;
5. immagine attuale in `apps-dev`;
6. immagine attuale in `apps-prod`;
7. URL EventListener;
8. differenza pratica tra:
   - Task;
   - Pipeline;
   - PipelineRun;
   - TriggerBinding;
   - TriggerTemplate;
   - EventListener;
   - Workspace;
   - Result.

---

# Comandi utili

```bash
kubectl -n builder get task,pipeline,pipelinerun,taskrun
kubectl -n builder describe pipelinerun <name>
kubectl -n builder get pods
kubectl -n builder logs <pod> --all-containers

kubectl -n builder get eventlistener,triggerbinding,triggertemplate
kubectl -n builder describe eventlistener gitea-listener

kubectl -n apps-dev get deploy,svc,pod
kubectl -n apps-prod get deploy,svc,pod

kubectl auth can-i patch deployments -n apps-dev --as system:serviceaccount:builder:builder
kubectl auth can-i patch deployments -n apps-prod --as system:serviceaccount:builder:builder
```

Se `tkn` è disponibile:

```bash
tkn -n builder pipelinerun list
tkn -n builder pipelinerun logs <name> -f
tkn -n builder pipelinerun describe <name>
```
