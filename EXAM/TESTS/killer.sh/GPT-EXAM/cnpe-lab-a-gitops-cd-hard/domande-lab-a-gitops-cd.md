# CNPE Lab A — GitOps & Continuous Delivery Hard

Focus: lacuna ufficiale **GitOps and Continuous Delivery**  
Tempo consigliato: 120 minuti  
Domande: 20  
Directory: `/course/lab-a-gitops-cd`

Repository Gitea:

```bash
cat /course/lab-a-gitops-cd/README.txt
```

---

## Q1 — Argo CD root app

Verifica lo stato dell'Application `root-apps`.

Salva:

```bash
/course/lab-a-gitops-cd/q1-root-app.txt
```

---

## Q2 — Argo CD path errato

L'Application `web-client` è OutOfSync/Missing per path errato.

Correggi senza ricreare tutto.

Path corretto:

```text
apps/web/manifests
```

Salva:

```bash
/course/lab-a-gitops-cd/q2-web-client-fixed.txt
```

---

## Q3 — Argo CD API app

Verifica che `api` sia Healthy/Synced e che le risorse siano in `app-dev`.

Salva:

```bash
/course/lab-a-gitops-cd/q3-api.txt
```

---

## Q4 — Branch testing

Crea una nuova Application Argo CD `web-client-testing`:

- repo uguale a `web-client`;
- targetRevision `testing`;
- path `apps/web/manifests`;
- namespace destinazione `app-prod`.

Salva manifest applicato:

```bash
/course/lab-a-gitops-cd/q4-web-testing.yaml
```

---

## Q5 — ApplicationSet generator

L'ApplicationSet `apps-generator` non scopre le app.

Correggi il generator per scoprire:

```text
apps/*/manifests
```

Verifica app generate in `app-prod`.

Salva:

```bash
/course/lab-a-gitops-cd/q5-applicationset.txt
```

---

## Q6 — App of Apps

Aggiungi una nuova app figlia per il rollout, usando path:

```text
apps/rollout
```

Deve deployare in `rollouts-lab`.

Salva:

```bash
/course/lab-a-gitops-cd/q6-rollout-child-app.yaml
```

---

## Q7 — Flux GitRepository

`web-source` punta al branch sbagliato.

Correggi il branch a:

```text
main
```

Salva:

```bash
/course/lab-a-gitops-cd/q7-flux-source.txt
```

---

## Q8 — Flux Kustomization path

`web-flux` ha path errato.

Correggi a:

```text
./apps/web/manifests
```

Verifica che app venga riconciliata in `app-prod`.

Salva:

```bash
/course/lab-a-gitops-cd/q8-flux-kustomization.txt
```

---

## Q9 — Flux remediation

Imposta su `web-flux`:

```yaml
retryInterval: 20s
timeout: 2m
prune: true
```

Salva YAML:

```bash
/course/lab-a-gitops-cd/q9-flux-remediation.yaml
```

---

## Q10 — Git change e riconciliazione

Nel repo locale creato in `/course/lab-a-gitops-cd/repo-work` cambia il testo web da:

```text
CNPE Web v1
```

a:

```text
CNPE Web v2
```

Commit e push su main.

Verifica che Argo CD o Flux riconcilino.

Salva:

```bash
/course/lab-a-gitops-cd/q10-git-change.txt
```

---

## Q11 — Tekton PipelineRun fallita

Esegui la PipelineRun Tekton già presente o creane una nuova.

Trova il primo errore.

Salva describe e log:

```bash
/course/lab-a-gitops-cd/q11-tekton-failure.txt
```

---

## Q12 — Tekton workspace path

Correggi la Task `manifest-test`: deve eseguire kustomize dentro la directory clonata.

Salva Task:

```bash
/course/lab-a-gitops-cd/q12-manifest-test-task.yaml
```

---

## Q13 — Tekton git checkout robusto

Correggi `git-checkout` per funzionare anche con commit SHA:

- clone senza `--branch`;
- `git checkout $(params.revision)`;
- result `commit` valorizzato.

Salva Task:

```bash
/course/lab-a-gitops-cd/q13-git-checkout-task.yaml
```

---

## Q14 — Tekton succeeded

Rilancia PipelineRun su branch main e deve finire `Succeeded`.

Salva:

```bash
/course/lab-a-gitops-cd/q14-tekton-succeeded.txt
```

---

## Q15 — Argo Rollout baseline

Verifica Rollout `payments` in `rollouts-lab`.

Salva:

```bash
/course/lab-a-gitops-cd/q15-rollout-baseline.txt
```

---

## Q16 — AnalysisTemplate smoke

L'AnalysisTemplate `rollout-smoke` ha successCondition `ok`, ma il job stampa altro.

Correggi.

Salva:

```bash
/course/lab-a-gitops-cd/q16-analysis-template.yaml
```

---

## Q17 — Canary update

Aggiorna immagine Rollout `payments` a:

```text
nginx:1.28-alpine
```

Verifica pausa canary.

Salva:

```bash
/course/lab-a-gitops-cd/q17-canary-update.txt
```

---

## Q18 — Promote rollout

Promuovi manualmente fino a completamento.

Salva eventi/stato:

```bash
/course/lab-a-gitops-cd/q18-promote.txt
```

---

## Q19 — Rollback/undo

Esegui rollback alla revisione precedente o documenta metodo e stato.

Salva:

```bash
/course/lab-a-gitops-cd/q19-rollback.txt
```

---

## Q20 — Report finale GitOps/CD

Crea:

```bash
/course/lab-a-gitops-cd/final-report.txt
```

Deve contenere:

1. Argo CD root app OK;
2. web-client OK;
3. ApplicationSet OK;
4. Flux web OK;
5. Tekton PipelineRun OK;
6. Rollout canary/promote OK;
7. link repo Gitea;
8. differenza pratica tra Application, ApplicationSet, GitRepository, Kustomization, PipelineRun, Rollout.
