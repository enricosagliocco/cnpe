# CNPE GitOps, CI/CD and Progressive Delivery Lab

Scenario creato da `setup-gitops-progressive-delivery-lab.sh`. Gli starter
sono in `~/course-gitops-progressive-delivery/`.

## Vincoli d'esame

- Non modificare i controller nei Namespace `argocd`, `flux-system`,
  `tekton-pipelines` e `argo-rollouts`.
- La pipeline CI non deve eseguire `kubectl apply` sui workload applicativi.
- Il desired state deve provenire da Git e deve essere riconciliato da Argo CD
  o Flux.
- Non saltare pause, verifiche o fasi preview dei Rollout.

---

### Q1 – Argo CD application delivery

L'Application `guestbook` usa repository corretto, ma branch e path
inesistenti.

Correggi `01/application.yaml`:

1. `targetRevision: master`;
2. `path: guestbook`;
3. Namespace destinazione `gitops-apps`;
4. sync automatica con `prune: true` e `selfHeal: true`;
5. creazione automatica del Namespace tramite sync option.

Verifica:

- Application `Synced` e `Healthy`;
- Deployment e Service creati in `gitops-apps`;
- modifica manualmente il numero di repliche del Deployment;
- dimostra che self-heal ripristina il valore dichiarato in Git;
- salva stato, history ed evento di riconciliazione in `01/status.txt`.

---

### Q2 – Flux per infrastruttura e drift

GitRepository e Kustomization `platform-infra` puntano a branch e path
inesistenti.

Correggi:

`02/source.yaml`:

- branch `main`;
- interval `1m`;
- URL invariato.

`02/kustomization.yaml`:

- path `./clusters/staging`;
- target Namespace `gitops-infra`;
- interval `5m`;
- `prune: true`;
- dipendenza dal GitRepository già definito;
- health check e wait abilitati.

Verifica:

- Source e Kustomization `Ready=True`;
- inventory popolato;
- risorse create nel Namespace corretto;
- elimina manualmente una risorsa gestita e forza una reconcile;
- verifica che Flux la ricrei;
- salva revision, conditions, inventory ed eventi in `02/reconcile.txt`.

---

### Q3 – Pipeline CI integrata con GitOps

La Pipeline `application-ci` contiene clone, test e preparazione della
promozione, ma manca il wiring tra i Task.

Completa `03/pipeline.yaml`:

1. `test` deve eseguire dopo `clone` e usare il workspace `source`;
2. `prepare-promotion` deve eseguire dopo `test` e usare lo stesso workspace;
3. mantieni il result Pipeline `promotion-file`;
4. nessun Task deve applicare risorse al cluster;
5. il file prodotto deve impostare l'immagine ricevuta dal parametro
   `image`.

Applica Pipeline e PipelineRun, quindi verifica:

- tre TaskRun riusciti nell'ordine corretto;
- test eseguito sul repository clonato;
- result Pipeline `promotion/image-patch.yaml`;
- artefatto YAML valido;
- assenza di `kubectl apply`, credenziali cluster o deploy imperativi.

Salva TaskRun, result e contenuto dell'artefatto in
`03/pipeline-result.txt`. Spiega come il file verrebbe committato tramite pull
request nel repository GitOps prima della riconciliazione.

---

### Q4 – Canary delivery

Completa `04/canary-rollout.yaml`:

1. stable Service `canary-stable`;
2. canary Service `canary-preview`;
3. step:
   - peso 25%;
   - pausa 20 secondi;
   - peso 50%;
   - pausa manuale;
   - peso 100%.

Applica il Rollout e attendi lo stato Healthy. Avvia una nuova revisione
portando `VERSION` a `v2`.

Verifica:

- ReplicaSet stable e canary distinti;
- selettori dei Service aggiornati dal controller;
- avanzamento 25% e 50%;
- pausa manuale osservabile;
- promozione esplicita;
- Rollout finale Healthy.

Avvia poi una revisione con immagine inesistente, osserva il fallimento e
annulla l'update mantenendo disponibile la revisione stabile.

Salva eventi, revisioni, pause, promozione e rollback in `04/events.txt`.

---

### Q5 – Blue/Green delivery

Completa `05/bluegreen-rollout.yaml`:

1. active Service `bluegreen-active`;
2. preview Service `bluegreen-preview`;
3. `autoPromotionEnabled: false`;
4. `scaleDownDelaySeconds: 30`.

Applica il Rollout e avvia una nuova revisione con `VERSION=v2`.

Prima della promozione verifica:

- active Service ancora sulla versione v1;
- preview Service sulla versione v2;
- entrambe le revisioni disponibili;
- Rollout in pausa.

Promuovi la preview e verifica lo switch atomico dell'active Service. Avvia
poi `VERSION=v3`, esegui un test negativo sulla preview e usa abort senza
spostare il traffico active.

Salva selettori dei Service, revisioni, promozione e abort in
`05/promotion.txt`.

---

### Verifica finale

```bash
kubectl -n argocd get applications
kubectl -n flux-system get gitrepositories,kustomizations
kubectl -n ci-pipeline get pipeline,pipelinerun,taskrun
kubectl -n progressive-delivery get rollouts,replicasets,services
```

La prova è completa quando Argo CD e Flux riconciliano da Git, Tekton produce
un artefatto di promozione senza deploy imperativo e i Rollout canary e
blue/green completano promozione e rollback mantenendo il servizio
disponibile.
