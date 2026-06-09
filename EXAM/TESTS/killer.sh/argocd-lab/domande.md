# Le 20 domande dell'esame - Argo CD Lab

Scenario creato da `setup-argocd-lab.sh`. Manifest e file starter sono in
`~/course-argocd/`. Le Application risiedono in `argocd` e distribuiscono i
workload nei Namespace indicati.

**Vincolo:** non modificare o disinstallare i componenti core di Argo CD. Le
correzioni devono essere dichiarative; non creare manualmente i workload che
Argo CD deve riconciliare.

---

### Q1 - Application source

Correggi `01/application.yaml` usando repository
`https://github.com/argoproj/argocd-example-apps.git`, revisione `master` e
path `guestbook`. Applica e verifica che Argo CD riesca a generare i manifest.

### Q2 - Destination

Completa `02/application.yaml` affinché distribuisca `guestbook` sul cluster
locale nel Namespace `argocd-apps`. Verifica server e Namespace nello status.

### Q3 - Sync automatica

Configura in `03/application.yaml` sync automatica con `prune: true` e
`selfHeal: true`. Sincronizza e verifica `Synced/Healthy`.

### Q4 - CreateNamespace

L'Application in `04/` punta al Namespace inesistente `team-a`. Aggiungi la
sync option necessaria a crearlo e verifica che il deploy riesca.

### Q5 - Prune

Sincronizza `05/application.yaml`, abilita il prune e documenta in
`05/evidence.txt` come Argo CD identifica ed elimina risorse non più desiderate.

### Q6 - Self-heal

Usa `06/application.yaml`, modifica manualmente le repliche del Deployment e
verifica il ripristino automatico. Salva history, eventi e diff in
`06/evidence.txt`.

### Q7 - Ignore differences

Completa `07/application.yaml` per ignorare soltanto `/spec/replicas` sui
Deployment. Verifica che una variazione delle repliche non renda l'app OutOfSync.

### Q8 - Sync options

Configura `08/application.yaml` con `ServerSideApply=true`,
`PruneLast=true` e `ApplyOutOfSyncOnly=true`. Verifica le opzioni effettive.

### Q9 - AppProject destinations

Correggi `09/project.yaml`: consenti il repository di esempio e soltanto i
Namespace `team-*` sul cluster locale. Collega e sincronizza l'Application.

### Q10 - AppProject resource policy

Nel progetto `platform`, consenti Deployment, Service e ConfigMap namespaced,
ma nega risorse cluster-scoped. Verifica con una Application valida e una che
prova a creare una risorsa non consentita.

### Q11 - Orphaned resources

Abilita il monitoraggio delle orphaned resources in `11/project.yaml`. Crea un
ConfigMap manuale in `team-a` e verifica il warning senza eliminarlo.

### Q12 - ApplicationSet list generator

Completa `12/applicationset.yaml` per generare `guestbook-dev` e
`guestbook-stage` nei rispettivi Namespace. Verifica due Application healthy.

### Q13 - ApplicationSet git generator

Correggi `13/applicationset.yaml` affinché scopra le directory del repository
di esempio e usi il basename nel nome delle Application. Limita il generator
ai path applicativi validi.

### Q14 - Helm values

Completa `14/application.yaml` per distribuire `helm-guestbook` impostando
`service.type=ClusterIP` e `replicaCount=2`. Verifica i parametri renderizzati.

### Q15 - Kustomize overrides

Usa `15/application.yaml` per applicare il path `kustomize-guestbook`, un
namePrefix `lab-` e la label comune `managed-by=argocd`.

### Q16 - Multi-source

Correggi `16/application.yaml` definendo due source valide e univoche. Verifica
che lo status esponga le revisioni di entrambe senza repeated resource warning.

### Q17 - Sync windows

Completa `17/project.yaml` con una deny window giornaliera e una allow window
manuale per `maintenance-*`. Dimostra l'effetto con `argocd app sync` o status.

### Q18 - RBAC

Completa `18/argocd-rbac-cm.yaml`: il ruolo `developer` può get e sync delle
Application `platform/dev-*`, ma non delete. Associa il gruppo `team-dev`.

### Q19 - Troubleshooting

`19/application.yaml` contiene più errori di source, project e destination.
Riproduci il problema, correggilo e salva condizioni, causa e verifica in
`19/report.md`.

### Q20 - Simulazione a tempo

Completa `20/` con AppProject, ApplicationSet e policy RBAC per ambienti dev e
stage. Dev deve avere auto-sync/self-heal, stage sync manuale. Verifica:

```bash
kubectl -n argocd get appprojects,applications,applicationsets
kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

Salva configurazione, history e prove di isolamento in `20/final-report.md`.
