# CNPE Exam-like — Batteria domande 2026

Durata consigliata: **120 minuti**.  
Workspace: `~/course/cnpe-examlike`.  
Salva prove e note in `~/course/cnpe-examlike/answers/`.

Questa batteria è volutamente meno guidata del lab Gatekeeper: simula domande pratiche distribuite sui domini CNPE.

---

## Q1 — Cluster orientation e triage iniziale

Contesto: il lab è già deployato, ma alcuni `kubectl apply` iniziali hanno fallito o prodotto risorse non funzionanti.

Task:

1. Verifica stato cluster, namespace e controller installati.
2. Crea `answers/00-triage.txt` con:
   - version Kubernetes
   - namespace principali
   - workload non Ready
   - almeno 3 cause probabili trovate da `events`, `describe` o log iniziali.
3. Non correggere ancora nulla.

---

## Q2 — Platform architecture: ResourceQuota / LimitRange

Namespace: `team-a`.

Il namespace ha quota stretta e un LimitRange incoerente.

Task:

1. Identifica perché alcuni Pod potrebbero non essere schedulabili o ammessi.
2. Correggi quota o default del LimitRange con modifica minima.
3. Salva in `answers/01-quota-limits.txt`:
   - comando usato
   - prima/dopo di `kubectl -n team-a describe quota`
   - spiegazione in massimo 5 righe.

---

## Q3 — Backend service discovery

Namespace: `team-a`.

Il Service `backend` non raggiunge correttamente i Pod.

Task:

1. Correggi solo label/selector necessari.
2. Verifica che il Service abbia endpoint.
3. Salva in `answers/02-backend-endpoints.txt`:
   - `kubectl -n team-a get endpoints backend -o wide`
   - patch applicata.

---

## Q4 — Readiness probe rotta

Namespace: `team-a`, Deployment `backend`.

Task:

1. Trova perché i Pod backend non diventano Ready.
2. Correggi la readiness probe con patch minima.
3. Verifica rollout completo.
4. Salva evidenza in `answers/03-backend-ready.txt`.

---

## Q5 — ConfigMap contract tra frontend e backend

Namespace: `team-a`, Deployment `frontend`.

Il frontend non parte correttamente perché cerca una chiave ConfigMap non esistente.

Task:

1. Non ricreare il Deployment.
2. Correggi ConfigMap o riferimento env con modifica minima.
3. Verifica che i Pod frontend siano Running.
4. Salva `kubectl -n team-a describe pod -l app=frontend` in `answers/04-frontend-config.txt`.

---

## Q6 — Security policy: immagini ammesse

Gatekeeper blocca immagini non conformi nel namespace `team-a`.

Task:

1. Identifica quale Constraint blocca immagini fuori repo.
2. Porta `frontend` a un’immagine ammessa e con tag esplicito.
3. Mantieni il container funzionante su porta 80 oppure adatta coerentemente Service/container.
4. Salva in `answers/05-image-policy.txt`:
   - Constraint coinvolta
   - patch immagine
   - stato finale Pod.

---

## Q7 — Gatekeeper: enforcement sbagliato e namespace sbagliato

Il controllo label `owner` e `cost-center` non sta proteggendo `team-a`.

Task:

1. Correggi `K8sRequiredLabels required-owner-costcenter`.
2. Deve essere `deny`, non `dryrun`.
3. Deve matchare `team-a`.
4. Applica label mancanti ai workload esistenti solo se necessario.
5. Salva `kubectl describe` della Constraint in `answers/06-required-labels.txt`.

---

## Q8 — Negative test admission

Task:

1. Crea un manifest temporaneo di Deployment non conforme in `team-a` senza `cost-center`.
2. L’apply deve essere negato da Gatekeeper.
3. Salva messaggio di errore in `answers/07-admission-denied.txt`.
4. Cancella eventuali risorse di test residue.

---

## Q9 — StatefulSet e PVC Pending

Namespace: `team-a`, StatefulSet `postgres`.

Task:

1. Trova perché il PVC resta Pending.
2. Correggi senza cancellare il namespace.
3. Porta `postgres-0` Running.
4. Salva in `answers/08-postgres-storage.txt`:
   - pvc prima/dopo
   - storageClass disponibile scelta
   - eventuale comando di delete/recreate giustificato.

Nota: se devi modificare `volumeClaimTemplates`, spiega perché Kubernetes non lo aggiorna in-place.

---

## Q10 — RBAC least privilege

Namespace: `team-a`, ServiceAccount `developer`.

Task:

1. Verifica se `system:serviceaccount:team-a:developer` può listare Pod in `team-a`.
2. Correggi il RoleBinding rotto.
3. Non dare privilegi cluster-wide.
4. Salva:
   - `kubectl auth can-i list pods -n team-a --as=system:serviceaccount:team-a:developer`
   - YAML finale RoleBinding
   in `answers/09-rbac.txt`.

---

## Q11 — GitOps local rendering con Kustomize

Directory: `~/course/cnpe-examlike/gitops`.

Task:

1. Esegui build della kustomization cluster dev.
2. Correggi path e resource errati.
3. Applica il risultato al cluster.
4. Correggi il Service `catalog` affinché abbia endpoint.
5. Salva output di:
   - `kubectl kustomize ~/course/cnpe-examlike/gitops/clusters/dev`
   - `kubectl -n gitops-lab get deploy,svc,endpoints`
   in `answers/10-gitops-kustomize.txt`.

---

## Q12 — Continuous Delivery: Argo Rollouts Blue/Green

Namespace: `rollouts-lab`, Rollout `payments`.

Task:

1. Verifica stato del Rollout.
2. Spiega perché i Service active/preview non selezionano correttamente i Pod.
3. Correggi selettori o labels senza trasformare strategia.
4. Esegui update immagine a una patch version compatibile.
5. Promuovi il rollout manualmente solo dopo aver verificato preview.
6. Salva in `answers/11-rollout-bluegreen.txt`:
   - stato prima/dopo
   - service endpoints
   - comando di promote usato.

---

## Q13 — Platform API / self-service CRD

Directory: `~/course/cnpe-examlike/platform-api`.

Task:

1. Verifica schema del CRD `PlatformApp`.
2. Correggi `bad-platformapp.yaml` senza cambiare il CRD.
3. La risorsa `PlatformApp checkout` deve essere accettata.
4. Salva in `answers/12-platform-api.txt`:
   - errore iniziale
   - manifest corretto
   - `kubectl -n platform-system get papp checkout -o yaml`.

---

## Q14 — Developer self-service manifest generation

Usando la risorsa `PlatformApp checkout`, genera manualmente un Deployment e un Service equivalenti in `platform-system`.

Requisiti:

1. Nome workload: `checkout`.
2. Repliche uguali a `spec.replicas`.
3. Immagine uguale a `spec.image`.
4. Porta container e Service uguale a `spec.port`.
5. Label obbligatorie: `app=checkout`, `owner=<spec.owner>`, `managed-by=self-service`.
6. Salva i manifest in `answers/13-checkout-generated.yaml`.
7. Applica e verifica endpoints.

---

## Q15 — Observability: logs e incident note

Namespace: `observability-lab`.

Task:

1. Trova il workload che produce errori applicativi.
2. Salva le ultime 20 righe log in `answers/14-noisy-api-logs.txt`.
3. Scala temporaneamente a 0 repliche per mitigare l’incidente.
4. Scrivi `answers/14-incident-note.txt` con:
   - sintomo
   - impatto
   - mitigazione
   - follow-up.

---

## Q16 — Observability: resource usage

Task:

1. Verifica se `metrics-server` è operativo.
2. Raccogli `kubectl top nodes` e `kubectl top pods -A`.
3. Salva in `answers/15-resource-usage.txt`.
4. Se metrics non sono disponibili, scrivi troubleshooting realistico basato su `kubectl -n kube-system logs` o `describe`.

---

## Q17 — Policy audit zero-drift

Task:

1. Leggi lo status delle Constraint Gatekeeper.
2. Verifica `totalViolations` o campi equivalenti.
3. Correggi eventuali violazioni residue nei workload target.
4. Salva report in `answers/16-policy-audit.txt`.

---

## Q18 — Production hardening rapido

Namespace: `team-a`.

Task:

1. Assicurati che `frontend`, `backend`, `postgres` abbiano:
   - requests e limits
   - label `owner` e `cost-center`
   - immagini con tag esplicito
2. Non superare la ResourceQuota.
3. Salva patch e stato finale in `answers/17-hardening.txt`.

---

## Q19 — End-to-end service test

Task:

1. Crea un Pod temporaneo `curl` o `busybox` in `team-a`.
2. Verifica DNS e reachability verso:
   - `backend.team-a.svc.cluster.local`
   - `frontend.team-a.svc.cluster.local`
   - `postgres.team-a.svc.cluster.local:5432` almeno come connessione TCP se disponibile.
3. Salva output in `answers/18-e2e-network.txt`.
4. Rimuovi il Pod temporaneo.

---

## Q20 — Final exam report

Crea `answers/final-report.txt` con:

1. Stato finale di tutti i namespace lab.
2. Lista delle correzioni applicate, ordinate per dominio CNPE:
   - Platform Architecture and Infrastructure
   - GitOps and Continuous Delivery
   - Platform APIs and Self-Service
   - Observability and Operations
   - Security and Policy Enforcement
3. Comandi finali:
   - `kubectl get pods -A`
   - `kubectl get deploy,sts,svc,pvc -A`
   - `kubectl get constrainttemplate,constraint`
   - `kubectl get rollout -n rollouts-lab`
4. Eventuali problemi rimasti e perché.

---
