# Le 20 domande dell'esame — GitOps and Progressive Delivery Lab

Scenario creato da `setup-gitops-progressive-delivery-lab.sh`. Gli starter
sono in `~/course-gitops-progressive-delivery/`.

**Vincolo:** non modificare i controller Argo CD, Flux, Tekton o Argo
Rollouts. La pipeline non deve applicare workload direttamente: il desired
state deve provenire da Git.

---

### Q1 – Diagnosi Argo CD Application

Analizza condizioni ed eventi di `guestbook` e individua branch e path errati
in `01/application.yaml`.

### Q2 – Source e destination Argo CD

Imposta branch `master`, path `guestbook` e Namespace `gitops-apps`.

### Q3 – Sync policy

Configura sync automatica con `prune`, `selfHeal` e
`CreateNamespace=true`. Applica e verifica `Synced/Healthy`.

### Q4 – Drift e self-heal

Modifica manualmente le repliche, osserva il ripristino e salva history,
condizioni ed eventi in `01/status.txt`.

---

### Q5 – Diagnosi Flux Source

Analizza il GitRepository `platform-infra` e documenta perché non scarica
alcun artifact.

### Q6 – Correzione GitRepository

Imposta branch `main` e interval `1m` in `02/source.yaml`, quindi forza una
reconcile.

### Q7 – Correzione Kustomization

Imposta path `./clusters/staging`, target Namespace `gitops-infra`, interval
`5m`, `prune: true`, wait e health check.

### Q8 – Flux drift remediation

Verifica `Ready=True`, elimina una risorsa gestita, forza reconcile e salva
revision, inventory ed eventi in `02/reconcile.txt`.

---

### Q9 – Dipendenze Pipeline

In `03/pipeline.yaml`, fai eseguire `test` dopo `clone` e
`prepare-promotion` dopo `test`.

### Q10 – Workspace condiviso

Collega il workspace `source` ai tre Task e verifica che il repository
clonato sia disponibile al test.

### Q11 – Artefatto di promozione

Verifica che `prepare-promotion` produca `promotion/image-patch.yaml` con
l'immagine parametrica e che il Pipeline result esponga il path.

### Q12 – Esecuzione GitOps CI

Esegui il PipelineRun, salva ordine, result e artefatto in
`03/pipeline-result.txt` e dimostra l'assenza di deploy imperativi.

---

### Q13 – Service canary

Completa `04/canary-rollout.yaml` con Service stable `canary-stable` e canary
`canary-preview`.

### Q14 – Canary steps

Configura peso 25%, pausa 20 secondi, peso 50%, pausa manuale e peso 100%.

### Q15 – Promozione canary

Avvia `VERSION=v2`, osserva ReplicaSet e selettori Service a ogni step e
promuovi esplicitamente.

### Q16 – Rollback canary

Avvia una revisione con immagine inesistente, osserva il fallimento, esegui
abort/undo e salva eventi e revisioni in `04/events.txt`.

---

### Q17 – Configurazione Blue/Green

Completa `05/bluegreen-rollout.yaml` con active `bluegreen-active`, preview
`bluegreen-preview`, promozione manuale e delay 30 secondi.

### Q18 – Preview verification

Avvia `VERSION=v2` e verifica che active resti su v1 mentre preview espone v2.

### Q19 – Promotion e abort

Promuovi v2, poi avvia v3, simula un test preview negativo e usa abort senza
spostare il traffico active.

### Q20 – Verifica finale delivery

```bash
kubectl -n argocd get applications
kubectl -n flux-system get gitrepositories,kustomizations
kubectl -n ci-pipeline get pipeline,pipelinerun,taskrun
kubectl -n progressive-delivery get rollouts,replicasets,services
```

Completa `05/promotion.txt` e conferma riconciliazione GitOps, CI senza deploy
imperativo e disponibilità durante canary e blue/green.
