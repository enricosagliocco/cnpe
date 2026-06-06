# CNPE Mini Lab — Tekton focus

Scenario: `tekton-mini`  
Namespace: `tekton-mini`  
Directory: `/course/tekton-mini`  
Tempo consigliato: 60–75 minuti.

## Q1 — Verifica Tekton

Verifica che i Pod in `tekton-pipelines` siano Running e salva:

```bash
kubectl -n tekton-pipelines get pods > /course/tekton-mini/q1-status.txt
kubectl -n tekton-mini get task,pipeline,eventlistener,triggerbinding,triggertemplate >> /course/tekton-mini/q1-status.txt
```

## Q2 — PipelineRun manuale

Applica:

```bash
kubectl apply -f /course/tekton-mini/30-pipelinerun-broken.yaml
```

Trova PipelineRun e TaskRun. Salva describe:

```bash
kubectl -n tekton-mini describe pipelinerun <name> > /course/tekton-mini/q2-pipelinerun.txt
```

## Q3 — Fix workspace path

La Task `unit-test` fallisce perché cerca `app.py` nella root del workspace.

Correggi la Task: il clone finisce in:

```text
$(workspaces.source.path)/source
```

Rilancia PipelineRun e verifica che `tests` passi.

## Q4 — Fix RBAC deploy

La ServiceAccount `pipeline` non può applicare Deployment.

Correggi la Role `pipeline-basic` aggiungendo:

```yaml
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Rilancia PipelineRun.

## Q5 — Verifica deploy

Verifica che esista:

```bash
kubectl -n tekton-mini get deploy tekton-mini-app
```

Salva:

```bash
kubectl -n tekton-mini get pipelinerun,taskrun,deploy,pod > /course/tekton-mini/q5-final-pipeline.txt
```

## Q6 — Parametro image

Crea una nuova PipelineRun con:

```bash
image=httpd:2-alpine
```

Verifica che il Deployment venga aggiornato e salva:

```bash
kubectl -n tekton-mini get deploy tekton-mini-app -o jsonpath='{.spec.template.spec.containers[0].image}' > /course/tekton-mini/q6-image.txt
```

## Q7 — TriggerBinding Gitea

Nel file `40-triggers-broken.yaml`, correggi:

```text
$(body.ref)
```

in:

```text
$(body.after)
```

Applica la risorsa.

## Q8 — EventListener

Verifica Pod e Service dell’EventListener:

```bash
kubectl -n tekton-mini get eventlistener,pod,svc
```

Scrivi l’URL webhook in:

```bash
/course/tekton-mini/q8-webhook-url.txt
```

## Q9 — Simula webhook

Usa l’URL `http://<MINIKUBE_IP>:30080` e il repo in `/course/tekton-mini/README.txt`.

Esempio:

```bash
curl -X POST http://<MINIKUBE_IP>:30080 \
  -H 'Content-Type: application/json' \
  -d '{"after":"main","ref":"refs/heads/main","repository":{"clone_url":"REPO_URL"}}'
```

Verifica che nasca una nuova PipelineRun.

## Q10 — Branch vs SHA

Modifica `git-clone-lite` per supportare anche commit SHA:

```bash
git clone "$(params.url)" "$(workspaces.output.path)/source"
cd "$(workspaces.output.path)/source"
git checkout "$(params.revision)"
```

Salva il nuovo YAML:

```bash
kubectl -n tekton-mini get task git-clone-lite -o yaml > /course/tekton-mini/q10-git-clone-task.yaml
```

## Q11 — Label sulle PipelineRun generate

Modifica il `TriggerTemplate` per aggiungere alle PipelineRun generate:

```yaml
labels:
  source: gitea
  exam: cnpe
```

Simula un webhook e verifica:

```bash
kubectl -n tekton-mini get pipelinerun --show-labels
```

## Q12 — Logs

Salva i log delle TaskRun dell’ultima PipelineRun in:

```bash
/course/tekton-mini/q12-taskrun-logs.txt
```

## Q13 — Cleanup

Mantieni solo le ultime 2 PipelineRun. Salva stato finale:

```bash
kubectl -n tekton-mini get pipelinerun,taskrun > /course/tekton-mini/q13-cleanup.txt
```

## Q14 — Report finale

Crea `/course/tekton-mini/final-report.txt` con:

- ultima PipelineRun `Succeeded`;
- Deployment creato;
- immagine corrente;
- URL EventListener;
- differenza tra Task, Pipeline, PipelineRun, TriggerBinding, TriggerTemplate, EventListener.
