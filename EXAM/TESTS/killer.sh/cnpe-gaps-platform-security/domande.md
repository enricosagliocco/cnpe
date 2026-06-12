# Le 20 domande dell'esame — Platform APIs and Security Lab (simulatore lab)

## Metodo operativo obbligatorio

Ogni domanda e un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale nel cluster;
2. raccogliere il sintomo tramite stato, condizioni, eventi, log o output del controller;
3. identificare e registrare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla con un test runtime positivo e, quando previsto, negativo.

La sola modifica del file, il solo dry-run client-side o una risposta teorica
non completano il ticket. Conserva comando, errore iniziale, correzione e
verifica finale nell'evidence file indicato dalla domanda.

Scenario deployato da `setup-platform-security-lab.sh`. Manifest e file
starter in `~/course-platform-security/`. Ogni esercizio specifica nomi,
parametri e risultato atteso.

**Vincolo:** non disinstallare Crossplane o Gatekeeper. Puoi modificare CRD,
XRD, Composition, XR, RBAC, policy, quote e workload, ma non i componenti core
nei Namespace `crossplane-system` e `gatekeeper-system`.

Ogni directory contiene un manifest incompleto, un test positivo/negativo o
una risorsa running non conforme. Per completare una domanda devi riprodurre
lo stato iniziale, implementare la correzione, applicarla al cluster e
verificare sia il caso consentito sia quello negato. La sola validazione YAML
non è sufficiente. Le sequenze Q1–Q4, Q5–Q9 e Q15–Q17 sono progressive:
mantieni nel cluster le correzioni delle domande precedenti della stessa
sequenza.

Accesso GUI:
- Usa Lens/OpenLens con il kubeconfig corrente.
- In **Custom Resources** trovi XRD, Composition, XR, ConstraintTemplate e
  Constraint; usa inoltre **Events** e **Pod Logs** per il troubleshooting.

```bash
kubectl config current-context
kubectl config view --minify --raw
```

Credenziali:
- Non servono credenziali aggiuntive rispetto al kubeconfig Kubernetes.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 - CRD structural schema
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/01`.


La CRD starter accetta attualmente qualsiasi `spec`, quindi anche
`01/invalid.yaml`.

1. Completa `01/crd.yaml` per `DatabaseClaim`: `engine` enum postgres/mysql, `storageGi` integer minimo 1, entrambi required, nessuna proprietà aggiuntiva.
2. Applica la CRD.
3. Verifica che `01/valid.yaml` venga accettato e `01/invalid.yaml` rifiutato
   dal server API.

---

### Q2 - CRD versioning
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/02`.


`02/crd.yaml` espone soltanto `v1alpha1`.

1. In `02/crd.yaml` aggiungi `v1beta1` served/storage e mantieni `v1alpha1` served/non-storage.
2. In `v1beta1` aggiungi `spec.highAvailability` boolean default false.
3. Applica la CRD, crea una risorsa `v1beta1` e rileggila in entrambe le
   versioni.
4. Verifica `status.storedVersions`.

---

### Q3 - Status subresource
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/03`.


La CRD in `03/` non abilita aggiornamenti indipendenti dello status.

1. Abilita `subresources.status` in `03/crd.yaml`; crea `cache-a` e aggiorna solo lo status a `phase: Ready` senza modificare spec.
2. Applica CRD e risorsa.
3. Verifica che l'update dello status non modifichi `spec`.
4. Salva comandi e output in `03/result.txt`.

---

### Q4 - Printer columns
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/04`.


`kubectl get databaseclaims` non mostra i dati operativi richiesti.

1. Aggiungi colonne `Engine`, `Storage` e `Phase` in `04/crd.yaml` usando i JSONPath corretti.
2. Applica CRD e una risorsa con status.
3. Verifica che `kubectl get databaseclaims` mostri i tre valori.

---

### Q5 - Namespaced platform API
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/05`.


L'XRD `AppEnvironment` contiene scope e schema incompleti.

1. Completa `05/xrd.yaml` Crossplane v2, scope Namespaced, kind `AppEnvironment`, campi required `team` e `environment`, quest'ultimo enum dev/staging/prod.
2. Applica l'XRD e attendi che la CRD generata sia `Established`.
3. Verifica che una risorsa con environment non ammesso venga rifiutata.

---

### Q6 - Composition patching
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/06`.


La Composition crea un ConfigMap senza Namespace e senza dati dell'XR.

1. Completa `06/composition.yaml` affinché crei Namespace logico tramite ConfigMap `environment-config`, copiando team/environment nei data e il Namespace dell'XR nei metadata.
2. Applica XRD, Composition e XR.
3. Verifica ConfigMap, Namespace, `data.team`, `data.environment` e resource
   references dell'XR.

---

### Q7 - Composition transforms
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/07`.


`07/composition.yaml` non traduce l'ambiente nel numero di repliche.

1. In `07/composition.yaml` trasforma `spec.environment`: dev -> `1`, staging -> `2`, prod -> `3`, scrivendo il valore in `data.replicas`.
2. Applica una XR per ciascun ambiente.
3. Verifica i tre valori nei ConfigMap composti.

---

### Q8 - Composition readiness
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/08`.


L'XR diventa Ready senza attendere il segnale applicativo del ConfigMap.

1. Aggiungi readiness check `MatchString` su `data.ready` valore `"true"` alla risorsa ConfigMap di `08/composition.yaml`.
2. Verifica che l'XR resti non Ready finché il campo non è presente.
3. Aggiungi `data.ready: "true"` e verifica la transizione a `Ready=True`.

---

### Q9 - Self-service claim validation
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/09`.


`09/xr.yaml` contiene nome, Namespace e spec come placeholder.

1. Correggi `09/xr.yaml`: nome `payments-prod`, Namespace `team-payments`, team `payments`, environment `prod`.
2. Applica l'XR.
3. Verifica `Ready=True`, ConfigMap composto e resource references in
   `09/result.txt`.

---

### Q10 - Multi-tenancy quota
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/10`.


Il ResourceQuota `tenant-budget` ha `hard` vuoto.

1. Completa `10/quota.yaml` nel Namespace `tenant-a`: requests.cpu `2`, requests.memory `4Gi`, limits.cpu `4`, limits.memory `8Gi`, pods `20`, persistentvolumeclaims `5`.
2. Applica il file.
3. Verifica i valori con `kubectl describe resourcequota` e prova una
   richiesta che superi almeno uno dei limiti.

---

### Q11 - LimitRange defaults
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/11`.


Il Pod `defaults-demo` non specifica risorse e il LimitRange è vuoto.

1. Completa `11/limitrange.yaml`: default request `100m/128Mi`, default limit `500m/512Mi`, max `2/2Gi`.
2. Applica LimitRange e Pod.
3. Verifica nello spec ammesso che il Pod abbia ricevuto request e limit.
4. Verifica che un Pod oltre il massimo venga rifiutato.

---

### Q12 - NetworkPolicy default deny
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/12`.


Frontend, backend e Service backend sono già running; senza policy la
comunicazione non è limitata.

1. Applica default deny ingress/egress in `tenant-a`, poi consenti al Pod `frontend` di raggiungere `backend` solo TCP 8080 e DNS kube-system UDP/TCP 53.
2. Completa `12/policies.yaml`.
3. Verifica dal frontend che DNS e `backend:8080` funzionino e che una porta
   non consentita fallisca.

---

### Q13 - RBAC tenant admin
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/13`.


ServiceAccount, Role e RoleBinding esistono nel file, ma le regole e il
subject sono vuoti.

1. Completa `13/rbac.yaml`: ServiceAccount `tenant-admin`, Role su deployments/services/configmaps con get/list/watch/create/update/patch/delete, senza Secret o RBAC.
2. Applica il file.
3. Esegui test `kubectl auth can-i` positivi e negativi.
4. Salva tutti i risultati in `13/checks.txt`.
5. Verifica esplicitamente accesso ai ConfigMap e diniego su Secret e RBAC.

---

### Q14 - Pod Security restricted
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/14`.


Il Deployment `restricted-app` è già running con container privilegiato.

1. Etichetta `tenant-a` con restricted/latest e correggi `14/deployment.yaml`: runAsNonRoot, runAsUser 1000, RuntimeDefault, no privilege escalation, drop ALL.
2. Applica l'enforcement e riproduci il rifiuto della configurazione corrente.
3. Applica il manifest corretto.
4. Verifica rollout riuscito e Pod conforme ai security context richiesti.

---

### Q15 - Gatekeeper required owner
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/15`.


Template e Constraint contengono schema, Rego e match mancanti.

1. Completa template e Constraint in `15`: parametro annotation string, messaggio `Missing annotation: owner`, Deployment in `tenant-a`, deny.
2. Applica prima il template e attendi la CRD, poi applica la Constraint.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.

---

### Q16 - Gatekeeper allowed repositories
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/16`.


Il template non controlla ancora container e initContainer.

1. Completa `16/template.yaml` e consenti soltanto `registry.k8s.io/` ai Pod in `tenant-a`, includendo initContainer.
2. Applica template e Constraint.
3. Verifica che `bad.yaml` venga negato indicando nome e immagine e che
   `good.yaml` venga accettato.

---

### Q17 - Audit and remediation
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/17`.


Il Deployment `unallocated-cost` è già running senza label `cost-center`; la
Constraint starter usa `dryrun`.

1. Applica `17/constraint.yaml` in dryrun per richiedere label `cost-center` ai Deployment di `tenant-a`.
2. Esporta violazioni in `17/audit.txt`, correggi i Deployment e porta la Constraint a deny.
3. Verifica audit senza blocco iniziale, assenza di violazioni dopo la
   remediation e rifiuto di un nuovo Deployment non conforme.

---

### Q18 - Supply-chain check
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/18`.


Il file `18/sbom.json` contiene una licenza `NOASSERTION`, ma il Task Tekton
non implementa alcun controllo.

1. Completa `18/pipeline-policy.yaml`: lo step deve fallire se `18/sbom.json` non contiene `SPDXID` o contiene package con license `NOASSERTION`.
2. Crea un TaskRun montando il file in `/workspace/sbom.json`.
3. Verifica fallimento con exit code 1 sul file fornito.
4. Correggi una copia dell'SBOM e verifica un TaskRun riuscito.

---

### Q19 - Cost and right-sizing
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/19`.


Il Deployment `right-sized` non definisce request o limit; `usage.csv`
contiene i campioni da usare.

1. Da `19/usage.csv`, imposta in `19/deployment.yaml` request CPU al percentile 95 arrotondato ai 10m superiori e memory al massimo più 20%.
2. Limiti pari a 2x le request.
3. Documenta il calcolo in `19/calculation.txt`.
4. Applica il Deployment e verifica nello spec del Pod i valori calcolati.

---

### Q20 - Simulazione a tempo
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-security/20`.


Il report finale deve verificare risorse realmente create o corrette nelle
domande precedenti.

1. Completa `20/report.md` in 25 minuti dimostrando: CRD valida, XR Ready, quota e LimitRange attivi, NetworkPolicy funzionante, RBAC least privilege, PSS restricted, Gatekeeper deny e controllo SBOM fallito correttamente.
2. Per ogni punto inserisci comando, output essenziale e rollback.

---

## Tracce di soluzione

Le soluzioni sono operative: usa gli starter, gli eventi e i comandi di verifica
indicati in ogni ticket. Conserva in `evidence.txt` sintomo iniziale, correzione e
risultato runtime finale; non sostituire i manifest completi senza diagnosi.
