# Le 20 domande dell'esame — Exam02 Retake (simulatore lab)

Scenario deployato da `setup-cnpe-lab.sh`. Manifest in `~/course/exam02/`.  
Lo script è diviso in 3 parti (part1, part2, part3) eseguite dall'entrypoint.

**Vincolo:** non disinstallare i tool installati (Argo CD, Flux, Tekton, Argo Workflows, Flagger, Gatekeeper, Kyverno, Crossplane). Puoi modificare configurazioni e risorse applicative ma non i core dei tool.

Verifica le soluzioni in `risposte.md`.

---

### Q1 – Argo CD Drift Recovery

Argo CD è installato con UI su `http://<node>:31030`. Un'applicazione nel namespace `gitops-apps` è in stato OutOfSync.

Accesso GUI (port-forward):

```bash
kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 31030:443
```

Credenziali:
- User: `admin`
- Password iniziale:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

1. Identifica l'applicazione OutOfSync nel namespace `gitops-apps`
2. Abilita la policy di auto-sync con `prune: true` e `selfHeal: true`
3. Esegui sync manuale e verifica che l'applicazione torni Healthy e Synced

---

### Q2 – Flux Resume e Reconcile

FluxCD è installato e la CLI `flux` è disponibile. Una Kustomization è sospesa.

1. Identifica la Kustomization sospesa nel namespace `flux-system`
2. Riprendi la Kustomization usando `flux resume kustomization`
3. Verifica che la riconciliazione avvenga e che lo stato desiderato venga riapplicato dopo drift manuale

---

### Q3 – Argo CD Multi-Branch Promotion

1. Prepara v2 sul branch `main` e v3 sul branch `testing` nel repository `/course/3/web-client`
2. Crea una seconda applicazione Argo CD `web-client-testing` con:
   - Branch Git sorgente: `testing`
   - Namespace K8s destinazione: `gitops-apps`
3. Assicurati che entrambe le applicazioni siano Healthy

---

### Q4 – Tekton Pipeline Graph Correction

Tekton Pipelines è installato con Dashboard su `http://<node>:31120`. Tutte le Pipeline devono essere eseguite nel namespace `builder2`.

Accesso GUI (port-forward):

```bash
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 31120:9097
```

1. Correggi la Pipeline `app-ci` in `/course/4/pipeline.yaml` aggiungendo una dipendenza task mancante
2. Esegui la Pipeline per due parametri diversi (es. `app: app1` e `app: app2`)
3. Elimina i PipelineRun falliti mantenendo solo quelli riusciti

---

### Q5 – Argo Workflows Retry e Cleanup

Argo Workflows è installato con UI su `http://<node>:31110`.

Accesso GUI (port-forward):

```bash
kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 31110:2746
```

1. Correggi il WorkflowTemplate `retake-greeter` in `/course/5/workflowtemplate.yaml`
2. Sottometti un nuovo Workflow nel namespace `argo` che abbia successo
3. Mantieni solo l'ultimo Workflow riuscito, elimina i falliti

---

### Q6 – Progressive Delivery Webhook Analysis

1. Aggiungi un webhook `pre-rollout` alla risorsa Canary `app2` in `/course/6/canary.yaml`
2. Il webhook deve verificare HTTP response 200 dal Service canary
3. Triggera un rollout cambiando `APP_VERSION` e salva gli eventi della Canary in `/course/6/canary-events.txt`

---

### Q7 – Git Push e Reconciliation Chain

1. Fai commit e push di modifiche manifest ai repository Gitea `retake-argocd`, `retake-flux`, `retake-pipelines`
2. Verifica che i controller (Argo CD, Flux) riconcilino le modifiche dal commit al cluster
3. Cattura il commit di rollback e il percorso di recupero in `/course/7/reconciliation-log.txt`

---

### Q8 – Gatekeeper ConstraintTemplate Fix

OPA Gatekeeper è installato nel namespace `gatekeeper-system`.

1. Sostituisci i placeholder `TODO` nel ConstraintTemplate `k8srequiredlabelsretake` in `/course/8/constrainttemplate.yaml` con messaggi di violazione significativi
2. Crea la Constraint che impone label richieste e minimo repliche
3. Limita la Constraint al namespace target solo

---

### Q9 – Kyverno Mutate Policy Correctness

Kyverno è installato nel namespace `kyverno`.

1. Crea la ClusterPolicy `security-check-retake` in `/course/9/security-check.yaml` che muta i Pod aggiungendo `audit: pending` solo se la label non esiste
2. Crea due Pod di prova per dimostrare che la policy non sovrascrive `audit: passed`
3. Esporta l'evidenza del test della policy in `/course/9/kyverno-test.txt`

---

### Q10 – Pod Security Admission Hardening

1. Configura il namespace `secure-legacy` per applicare Pod Security Standard `restricted` invece di `baseline`
2. Correggi il Pod `insecure-pod` in `/course/10/insecure-pod.yaml` per passare lo standard restricted
3. Riavvia il Pod e verifica che sia Running

---

### Q11 – RBAC Least Privilege

1. Costruisci SA/Role/RoleBinding per accesso read-only ai Deployment nel namespace `secure-rbac` usando `/course/11/rbac.yaml`
2. Valida che le operazioni create/update/delete siano negate
3. Produci evidenza `kubectl auth can-i` in `/course/11/rbac-evidence.txt`

---

### Q12 – NetworkPolicy Egress Control

1. Partendo dalla policy deny-all egress in `/course/12/netpol.yaml`, consenti solo traffico DNS e servizi interni richiesti
2. Usa `namespaceSelector` per kube-system su porte UDP/TCP 53
3. Valida con pod probes nel namespace `secure-net`

---

### Q13 – Secret Remediation e Rotation

1. Trova anti-pattern plaintext nei manifest in `/course/13/secret-bad.yaml`
2. Sostituisci con gestione Secret sicura usando Secret nativo di Kubernetes
3. Ruota le credenziali e verifica continuità dell'applicazione

---

### Q14 – Image Policy e Trust

1. Blocca l'uso del tag `:latest` usando policy appropriata
2. Applica condizione di registry trusted/signing
3. Rimedia i workload non conformi nel cluster

---

### Q15 – CRD Version Evolution

1. Aggiungi schema v1alpha2 alla CRD `AppClaim` in `/course/15/crd-appclaims.yaml` preservando compatibilità backward
2. Mantieni v1alpha1 served mentre migra storage version
3. Applica e valida custom resources vecchie e nuove

---

### Q16 – Crossplane Self-Service Redis API

Crossplane è installato nel namespace `crossplane-system`.

1. Completa XRD `XRedis` e Composition in `/course/16/` per RedisClaim
2. Aggiungi risorsa Service wiring allo StatefulSet nella Composition
3. Verifica che la claim produca le risorse composte

---

### Q17 – NamespaceClaim API Workflow

1. Implementa il flusso claim-to-namespace usando il template in `/course/17/template-namespaceclaim.yaml`
2. Allega quota profile dalla spec della claim
3. Valida label ownership e annotations

---

### Q18 – Helm Chart come Platform Product

1. Patcha direttamente i template del chart in `/course/18/chart-retake/` (niente values shortcuts dove vietato)
2. Bumpa la versione del chart a `0.2.0` e release
3. Assicura compliance policy nei manifest renderizzati

---

### Q19 – Quota Profile Automation

1. Definisci profili quota small/medium in `/course/19/quota-small.yaml`
2. Applica profilo per tenant namespace `selfservice-a`
3. Dimostra enforcement PVC e compute

---

### Q20 – API Contract Validation e Upgrade Plan

1. Produci checklist compatibilità per platform APIs in `/course/20/contract-checklist.md`
2. Esegui test upgrade dry-run
3. Documenta percorso rollback e step di verifica

---

### Q21 – Verifica finale end-to-end

1. Argo CD app in `gitops-apps` Healthy e Synced con auto-sync abilitato
2. Flux Kustomization ripresa e riconciliata con successo
3. Argo CD multi-branch con main e testing funzionanti
4. Tekton Pipeline `app-ci` corretta con PipelineRun riusciti
5. Argo Workflows `retake-greeter` eseguito con successo
6. Flagger Canary `app2` con webhook pre-rollout configurato
7. Git push reconciliation chain documentata in log
8. Gatekeeper ConstraintTemplate e Constraint applicati correttamente
9. Kyverno mutate policy testata con evidenza esportata
10. Pod Security Admission `restricted` applicato con Pod corretto
11. RBAC least privilege configurato con evidenza can-i
12. NetworkPolicy egress con DNS e traffico interno consentito
13. Secret migrati da plaintext a Secret sicuro
14. Image policy che blocca latest e enforce trusted registry
15. CRD `AppClaim` con v1alpha2 e compatibilità backward
16. Crossplane XRD e Composition per RedisClaim con Service
17. NamespaceClaim workflow implementato con quota profile
18. Helm chart retake con versione bumpata e compliance policy
19. Quota profile small applicato a `selfservice-a`
20. API contract checklist e upgrade plan documentati

---
