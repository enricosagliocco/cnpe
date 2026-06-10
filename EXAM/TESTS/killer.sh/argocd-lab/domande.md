# Le 20 domande dell'esame - Argo CD Lab (simulatore lab)

Scenario creato da `setup-argocd-lab.sh`. Manifest e file starter sono in
`~/course-argocd/`. Le Application risiedono in `argocd` e distribuiscono i
workload nei Namespace indicati.

**Vincolo:** non modificare o disinstallare i componenti core di Argo CD. Le
correzioni devono essere dichiarative; non creare manualmente i workload che
Argo CD deve riconciliare.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 - Application source

Percorso: `~/course-argocd/01`.

1. Correggi `01/application.yaml` usando repository
   `https://github.com/argoproj/argocd-example-apps.git`, revisione `master` e
   path `guestbook`.

2. Applica e verifica che Argo CD riesca a generare i manifest.

### Q2 - Destination

Percorso: `~/course-argocd/02`.

1. Completa `02/application.yaml` affinché distribuisca `guestbook` sul
   cluster locale nel Namespace `argocd-apps`.

2. Verifica server e Namespace nello status.

### Q3 - Sync automatica

Percorso: `~/course-argocd/03`.

1. Configura in `03/application.yaml` sync automatica con `prune: true` e
   `selfHeal: true`.

2. Sincronizza e verifica `Synced/Healthy`.

### Q4 - CreateNamespace

Percorso: `~/course-argocd/04`.

1. L'Application in `04/` punta al Namespace inesistente `team-a`.

2. Aggiungi la sync option necessaria a crearlo e verifica che il deploy
   riesca.

### Q5 - Prune

Percorso: `~/course-argocd/05`.

1. Sincronizza `05/application.yaml`, abilita il prune e documenta in
   `05/evidence.txt` come Argo CD identifica ed elimina risorse non più
   desiderate.

### Q6 - Self-heal

Percorso: `~/course-argocd/06`.

1. Usa `06/application.yaml`, modifica manualmente le repliche del Deployment
   e verifica il ripristino automatico.

2. Salva history, eventi e diff in `06/evidence.txt`.

### Q7 - Ignore differences

Percorso: `~/course-argocd/07`.

1. Completa `07/application.yaml` per ignorare soltanto `/spec/replicas` sui
   Deployment.

2. Verifica che una variazione delle repliche non renda l'app OutOfSync.

### Q8 - Sync options

Percorso: `~/course-argocd/08`.

1. Configura `08/application.yaml` con `ServerSideApply=true`,
   `PruneLast=true` e `ApplyOutOfSyncOnly=true`.

2. Verifica le opzioni effettive.

### Q9 - AppProject destinations

Percorso: `~/course-argocd/09`.

1. Correggi `09/project.yaml`: consenti il repository di esempio e soltanto i
   Namespace `team-*` sul cluster locale.

2. Collega e sincronizza l'Application.

### Q10 - AppProject resource policy

Percorso: `~/course-argocd/10`.

1. Nel progetto `platform`, consenti Deployment, Service e ConfigMap
   namespaced, ma nega risorse cluster-scoped.

2. Verifica con una Application valida e una che prova a creare una risorsa
   non consentita.

### Q11 - Orphaned resources

Percorso: `~/course-argocd/11`.

1. Abilita il monitoraggio delle orphaned resources in `11/project.yaml`.

2. Crea un ConfigMap manuale in `team-a` e verifica il warning senza
   eliminarlo.

### Q12 - ApplicationSet list generator

Percorso: `~/course-argocd/12`.

1. Completa `12/applicationset.yaml` per generare `guestbook-dev` e
   `guestbook-stage` nei rispettivi Namespace.

2. Verifica due Application healthy.

### Q13 - ApplicationSet git generator

Percorso: `~/course-argocd/13`.

1. Correggi `13/applicationset.yaml` affinché scopra le directory del
   repository di esempio e usi il basename nel nome delle Application.

2. Limita il generator ai path applicativi validi.

### Q14 - Helm values

Percorso: `~/course-argocd/14`.

1. Completa `14/application.yaml` per distribuire `helm-guestbook` impostando
   `service.type=ClusterIP` e `replicaCount=2`.

2. Verifica i parametri renderizzati.

### Q15 - Kustomize overrides

Percorso: `~/course-argocd/15`.

1. Usa `15/application.yaml` per applicare il path `kustomize-guestbook`, un
   namePrefix `lab-` e la label comune `managed-by=argocd`.

### Q16 - Multi-source

Percorso: `~/course-argocd/16`.

1. Correggi `16/application.yaml` definendo due source valide e univoche.

2. Verifica che lo status esponga le revisioni di entrambe senza repeated
   resource warning.

### Q17 - Sync windows

Percorso: `~/course-argocd/17`.

1. Completa `17/project.yaml` con una deny window giornaliera e una allow
   window manuale per `maintenance-*`.

2. Dimostra l'effetto con `argocd app sync` o status.

### Q18 - RBAC

Percorso: `~/course-argocd/18`.

1. Completa `18/argocd-rbac-cm.yaml`: il ruolo `developer` può get e sync
   delle Application `platform/dev-*`, ma non delete.

2. Associa il gruppo `team-dev`.

### Q19 - Troubleshooting

Percorso: `~/course-argocd/19`.

1. `19/application.yaml` contiene più errori di source, project e destination.

2. Riproduci il problema, correggilo e salva condizioni, causa e verifica in
   `19/report.md`.

### Q20 - Simulazione a tempo

Percorso: `~/course-argocd/20`.

1. Completa `20/` con AppProject, ApplicationSet e policy RBAC per ambienti
   dev e stage.

2. Dev deve avere auto-sync/self-heal, stage sync manuale.

3. Verifica:

```bash
kubectl -n argocd get appprojects,applications,applicationsets
kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

4. Salva configurazione, history e prove di isolamento in
   `20/final-report.md`.
