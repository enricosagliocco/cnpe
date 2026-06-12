# Argo CD Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili. Tutte le soluzioni
sono raccolte nella sezione finale del documento.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.

Il setup prepara questi repository pubblici in Gitea:

- `__EXAMPLE_REPO_URL__`, branch `master`, con `guestbook`,
  `helm-guestbook`, `kustomize-guestbook` e gli altri esempi Argo CD;
- `__EXTRA_REPO_URL__`, branch `main`, path `extras`, per gli esercizi
  multi-source.

Gli URL sono generati dai valori `GITEA_URL` e `GITEA_ORG` usati durante il
setup. Non usare i repository GitHub upstream negli esercizi.


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
   `__EXAMPLE_REPO_URL__`, revisione `master` e path `guestbook`.

2. Applica e verifica che Argo CD riesca a generare i manifest.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 01/application.yaml
```

---

### Q2 - Destination

Percorso: `~/course-argocd/02`.

1. Completa `02/application.yaml` affinché distribuisca `guestbook` sul
   cluster locale nel Namespace `argocd-apps`.

2. Verifica server e Namespace nello status.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/application.yaml
```

---

### Q3 - Sync automatica

Percorso: `~/course-argocd/03`.

1. Configura in `03/application.yaml` sync automatica con `prune: true` e
   `selfHeal: true`.

2. Sincronizza e verifica `Synced/Healthy`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/application.yaml
```

---

### Q4 - CreateNamespace

Percorso: `~/course-argocd/04`.

1. L'Application in `04/` punta al Namespace inesistente `team-a`.

2. Aggiungi la sync option necessaria a crearlo e verifica che il deploy
   riesca.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Prune

Percorso: `~/course-argocd/05`.

1. Sincronizza `05/application.yaml`, abilita il prune e documenta in
   `05/evidence.txt` come Argo CD identifica ed elimina risorse non più
   desiderate.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 05/application.yaml
```

---

### Q6 - Self-heal

Percorso: `~/course-argocd/06`.

1. Usa `06/application.yaml`, modifica manualmente le repliche del Deployment
   e verifica il ripristino automatico.

2. Salva history, eventi e diff in `06/evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/06` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 06/application.yaml
```

---

### Q7 - Ignore differences

Percorso: `~/course-argocd/07`.

1. Completa `07/application.yaml` per ignorare soltanto `/spec/replicas` sui
   Deployment.

2. Verifica che una variazione delle repliche non renda l'app OutOfSync.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/07` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 07/application.yaml
```

---

### Q8 - Sync options

Percorso: `~/course-argocd/08`.

1. Configura `08/application.yaml` con `ServerSideApply=true`,
   `PruneLast=true` e `ApplyOutOfSyncOnly=true`.

2. Verifica le opzioni effettive.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/08` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 08/application.yaml
```

---

### Q9 - AppProject destinations

Percorso: `~/course-argocd/09`.

1. Correggi `09/project.yaml`: consenti `__EXAMPLE_REPO_URL__` e soltanto i
   Namespace `team-*` sul cluster locale.

2. Collega e sincronizza l'Application.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/09` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 09/project.yaml
```

---

### Q10 - AppProject resource policy

Percorso: `~/course-argocd/10`.

1. Nel progetto `platform`, consenti Deployment, Service e ConfigMap
   namespaced, ma nega risorse cluster-scoped.

2. Verifica con una Application valida e una che prova a creare una risorsa
   non consentita.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/10` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - Orphaned resources

Percorso: `~/course-argocd/11`.

1. Abilita il monitoraggio delle orphaned resources in `11/project.yaml`.

2. Crea un ConfigMap manuale in `team-a` e verifica il warning senza
   eliminarlo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/11` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 11/project.yaml
```

---

### Q12 - ApplicationSet list generator

Percorso: `~/course-argocd/12`.

1. Completa `12/applicationset.yaml` per generare `guestbook-dev` e
   `guestbook-stage` nei rispettivi Namespace.

2. Verifica due Application healthy.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/12` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 12/applicationset.yaml
```

---

### Q13 - ApplicationSet git generator

Percorso: `~/course-argocd/13`.

1. Correggi `13/applicationset.yaml` affinché scopra le directory di
   `__EXAMPLE_REPO_URL__` e usi il basename nel nome delle Application.

2. Limita il generator ai path applicativi validi.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 13/applicationset.yaml
```

---

### Q14 - Helm values

Percorso: `~/course-argocd/14`.

1. Completa `14/application.yaml` per distribuire `helm-guestbook` impostando
   `service.type=ClusterIP` e `replicaCount=2`.

2. Verifica i parametri renderizzati.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/14` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 14/application.yaml
```

---

### Q15 - Kustomize overrides

Percorso: `~/course-argocd/15`.

1. Usa `15/application.yaml` per applicare il path `kustomize-guestbook`, un
   namePrefix `lab-` e la label comune `managed-by=argocd`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/15` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 15/application.yaml
```

---

### Q16 - Multi-source

Percorso: `~/course-argocd/16`.

1. Correggi `16/application.yaml` definendo due source valide e univoche:
   usa `__EXAMPLE_REPO_URL__` (`master`, path `guestbook`) e
   `__EXTRA_REPO_URL__` (`main`, path `extras`).

2. Verifica che lo status esponga le revisioni di entrambe senza repeated
   resource warning.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/16` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 16/application.yaml
```

---

### Q17 - Sync windows

Percorso: `~/course-argocd/17`.

1. Completa `17/project.yaml` con una deny window giornaliera e una allow
   window manuale per `maintenance-*`.

2. Dimostra l'effetto con `argocd app sync` o status.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/17` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 17/project.yaml
```

---

### Q18 - RBAC

Percorso: `~/course-argocd/18`.

1. Completa `18/argocd-rbac-cm.yaml`: il ruolo `developer` può get e sync
   delle Application `platform/dev-*`, ma non delete.

2. Associa il gruppo `team-dev`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/18` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 18/argocd-rbac-cm.yaml
```

---

### Q19 - Troubleshooting

Percorso: `~/course-argocd/19`.

1. `19/application.yaml` contiene più errori di source, project e destination.

2. Riproduci il problema, correggilo e salva condizioni, causa e verifica in
   `19/report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/19` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 19/application.yaml
```

---

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argocd/20` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Application source

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/01
kubectl apply -f 01/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Destination

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/02
kubectl apply -f 02/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - Sync automatica

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/03
kubectl apply -f 03/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - CreateNamespace

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - Prune

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/05
kubectl apply -f 05/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - Self-heal

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/06
kubectl apply -f 06/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - Ignore differences

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/07
kubectl apply -f 07/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Sync options

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/08
kubectl apply -f 08/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - AppProject destinations

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/09
kubectl apply -f 09/project.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - AppProject resource policy

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/10
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - Orphaned resources

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/11
kubectl apply -f 11/project.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - ApplicationSet list generator

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/12
kubectl apply -f 12/applicationset.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - ApplicationSet git generator

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/13
kubectl apply -f 13/applicationset.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Helm values

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/14
kubectl apply -f 14/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - Kustomize overrides

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/15
kubectl apply -f 15/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - Multi-source

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/16
kubectl apply -f 16/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - Sync windows

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/17
kubectl apply -f 17/project.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - RBAC

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/18
kubectl apply -f 18/argocd-rbac-cm.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - Troubleshooting

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/19
kubectl apply -f 19/application.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - Simulazione a tempo

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argocd/20
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
