# Risposte — Tekton Lab (`builder`)

Soluzioni per `domande.md` (Q1–Q20, stile esame Killer Shell). Scenario: `setup-lab.sh`.

---

### Q1 – Verifica installazione

**Q1.** Controller Available; namespace `builder` presente; Task/Pipeline con label `cnpe-lab=true`.

### Q2 – Dashboard

**Q2.** Port-forward o NodePort 30220; UI raggiungibile senza login in lab.

### Q3 – RBAC

**Q3.** Patch RoleBinding subject namespace → `builder`. Verifica `can-i create namespaces` = yes.

### Q4 – Parametro build

**Q4.** `$(params.gitRevision)` nello step `cnpe-build-image`.

### Q5 – DAG e finally

**Q5.** `runAfter: [fetch]`; `when` su `$(tasks.build.status)`.

### Q6 – PipelineRun release

**Q6.** SA `pipeline-runner`, PVC workspace `cnpe-manifests-ws`, target NS `cnpe-staging`, run Succeeded.

### Q7 – butter

**Q7.** PipelineRun onboard team-butter Succeeded; NS `team-butter` esiste.

### Q8 – croissant

**Q8.** NS `team-croissant` creato.

### Q9 – scan-b

**Q9.** `scan-b` usa `$(params.forbidden2)`.

### Q10 – scan sandwich

**Q10.** Run Failed; log in `scan-sandwich.log`.

### Q11–Q20

Vedi dettaglio comandi sotto (sezioni legacy allineate ai task).

---

## Dettaglio comandi (riferimento)

**Q1 concetti.** **Task**: step/container. **Pipeline**: DAG. **PipelineRun**: istanza esecuzione.

**Q2.**

```bash
kubectl -n tekton-pipelines get deploy
kubectl -n tekton-pipelines wait deploy/tekton-pipelines-webhook --for=condition=Available --timeout=120s
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller
```

**Q3.** `tekton-pipelines` ospita i componenti di sistema; i workload del candidato (Task/Pipeline/Run) stanno in un namespace applicativo (`builder`) con RBAC dedicato — pattern Q12 exam01.

**Q4.**

```bash
minikube ip -p cnpe
# http://<IP>:30220  (NodePort impostato dallo script)

kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30220:9097
```

**Q5.**

```bash
tkn pipelinerun list -n builder
tkn pipelinerun logs <run-name> -n builder -f
# oppure
tkn taskrun logs <run-name>-build-pod -n builder -f
kubectl -n builder logs -l tekton.dev/taskRun=<run-name>-build --all-containers
```

---

## Area 2: Parametri, workspace e DAG

**Q6.** Sostituire `$(params.git-revision)` con **`$(params.gitRevision)`** (nome parametro dichiarato nel Task):

```bash
kubectl -n builder edit task cnpe-build-image
# oppure patch dello script nello step build
```

**Q7.** `runAfter: [checkout]` è errato — non esiste task `checkout`. Corretto:

```yaml
runAfter:
  - fetch
```

**Q8.** `shared-manifests` è il workspace del Pipeline passato ai Task come `manifest-ws`. `cnpe-fetch-config` scrive `ready.txt` e `build.meta` in `$(workspaces.manifest-ws.path)` per i task successivi.

**Q9.** `tekton-bot` non esiste. Usare **`pipeline-runner`** dopo aver corretto il RoleBinding (Q11).

**Q10.**

```yaml
workspaces:
  - name: shared-manifests
    persistentVolumeClaim:
      claimName: cnpe-manifests-ws
```

---

## Area 3: RBAC, onboarding e scan

**Q11.** Il subject del RoleBinding punta a `namespace: default` invece di **`builder`**:

```bash
kubectl -n builder patch rolebinding pipeline-runner-binding --type=json \
  -p='[{"op":"replace","path":"/subjects/0/namespace","value":"builder"}]'
```

**Q12.**

```bash
tkn pipeline start cnpe-team-onboard -n builder \
  --param team-name=butter \
  --serviceaccount pipeline-runner

tkn pipeline start cnpe-team-onboard -n builder \
  --param team-name=croissant \
  --serviceaccount pipeline-runner
```

Oppure manifest PipelineRun con `serviceAccountName: pipeline-runner`.

**Q13.** Il task **`scan-b`** passa `forbidden: $(params.forbidden1)` due volte; il secondo deve usare **`$(params.forbidden2)`**.

**Q14.**

```bash
tkn pipeline start cnpe-policy-scan -n builder \
  --param team-name=sandwich \
  --param forbidden1=miner \
  --param forbidden2=crypto \
  --serviceaccount pipeline-runner
```

(Nota: il namespace reale è `team-sandwich` — il parametro `team-name` vale `sandwich`.)

**Q15.** Deve far **fallire** lo scan quando il pattern `miner` (o `crypto`) compare nei manifest Pod — il Pod `crypto-miner` contiene quella stringa.

---

## Area 4: Finally, debug e pulizia

**Q16.** `when` usa `$(tasks.build-image.status)` ma il task si chiama **`build`**:

```yaml
when:
  - input: "$(tasks.build.status)"
    operator: in
    values: ["Failed"]
```

**Q17.**

```bash
kubectl -n builder get taskrun
kubectl -n builder describe taskrun <pipelinerun-name>-build
kubectl -n builder logs <pod-name> -c step-build
```

**Q18.** Controllare `spec.steps[].computeResources` nel Task e `spec.timeout` / `spec.taskRunSpecs` nel PipelineRun; aumentare `limits.memory` o `timeout` se OOM/timeout.

**Q19.**

```bash
tkn pipelinerun delete --all -n builder
# oppure
kubectl -n builder delete pipelinerun --all
kubectl -n builder delete taskrun --all
```

**Q20.** Checklist:

1. `kubectl auth can-i create namespaces --as=system:serviceaccount:builder:pipeline-runner` → yes  
2. `tkn pipeline start cnpe-release ... --serviceaccount pipeline-runner` + workspace PVC → Succeeded; `kubectl get cm -n cnpe-staging cnpe-built`  
3. Onboard butter/croissant → namespace `team-butter`, `team-croissant`  
4. Scan sandwich con `forbidden1=miner` → PipelineRun **Failed**  
5. Dashboard: run verdi per release/onboard, rosso per scan  

---

## Manifest fix rapido (`cnpe-release` PipelineRun)

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: cnpe-release-
  namespace: builder
spec:
  pipelineRef:
    name: cnpe-release
  serviceAccountName: pipeline-runner
  params:
    - name: gitRevision
      value: "v1.2.3"
    - name: targetNamespace
      value: "cnpe-staging"
  workspaces:
    - name: shared-manifests
      persistentVolumeClaim:
        claimName: cnpe-manifests-ws
```

```bash
kubectl create -f ~/course/tekton-lab/pipelinerun-release-fixed.yaml
tkn pipelinerun logs -f -n builder
```

Guida: [tekton-lab.md](../tekton-lab.md).
