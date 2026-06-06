# OPA Gatekeeper Lab - 20 domande

Scenario creato da `setup-gatekeeper-lab.sh`. I file si trovano in
`~/course-gatekeeper`.

Ogni domanda contiene file starter, valori obbligatori e test positivi o
negativi. Non è richiesto inventare nomi, parametri o workload aggiuntivi.

Vincoli:

- Non disinstallare Gatekeeper.
- Non modificare i Deployment in `gatekeeper-system`, salvo quando una domanda
  richiede esplicitamente troubleshooting.
- Conservare i nomi di ConstraintTemplate e Constraint indicati.
- Dopo ogni modifica verificare sia admission sia audit.
- Le domande sono progressive. Se una Constraint `deny` di una domanda
  precedente interferisce con un test successivo, portala temporaneamente a
  `dryrun` invece di cancellare il ConstraintTemplate.

Comandi utili:

```bash
kubectl get constrainttemplates
kubectl get constraints
kubectl describe <constraint-kind> <constraint-name>
kubectl get <constraint-kind> <constraint-name> -o yaml
kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager
kubectl -n gatekeeper-system logs deploy/gatekeeper-audit
```

---

### Q1 - RequiredAnnotations parametrica

Percorso: `~/course-gatekeeper/01`.

Completa il `ConstraintTemplate` `requiredannotations`:

1. Lo schema deve accettare un parametro `annotation` di tipo string.
2. La policy deve verificare che l'annotation indicata esista.
3. Il messaggio deve includere il valore di `input.parameters.annotation`.

Crea poi `RequiredAnnotations` `require-owner-annotation`:

- `enforcementAction: deny`
- solo Deployment nel Namespace `apps`
- annotation richiesta: `owner`

Dimostra che un Deployment senza annotation viene negato e uno con
`owner: platform-team` viene accettato usando, nell'ordine:

```bash
kubectl apply -f deployment-bad.yaml
kubectl apply -f deployment-good.yaml
```

Il primo comando deve essere negato con un messaggio contenente
`Missing annotation: owner`; il secondo deve creare `deployment/has-owner`.

---

### Q2 - RequiredLabels con array

Percorso: `~/course-gatekeeper/02`.

Completa `requiredlabels` affinche:

1. Accetti `parameters.labels`, array di stringhe.
2. Calcoli tutte le label mancanti.
3. Produca una singola violazione contenente l'elenco delle label mancanti.

Crea `require-app-team-labels` per Pod e Deployment in `apps`; richiedi
`app` e `team`.

Usa `pod-bad.yaml` e `deployment-good.yaml`. Il Pod deve essere negato con
entrambe le label nel messaggio; il Deployment deve essere accettato.

---

### Q3 - Repository immagini consentiti

Percorso: `~/course-gatekeeper/03`.

Completa `allowedrepos`:

1. Accetta un array `repos`.
2. Controlla tutti i container del Pod.
3. Consente solo immagini che iniziano con uno dei prefissi configurati.
4. Il messaggio deve includere nome container e immagine rifiutata.

Applica la Constraint a `apps` consentendo:

- `nginx`
- `registry.k8s.io/`

Testa i manifest allowed e denied forniti.

`pod-allowed.yaml` deve essere creato. `pod-denied.yaml` deve essere negato e
il messaggio deve contenere container `web` e immagine
`docker.io/library/httpd:2-alpine`.

---

### Q4 - Numero minimo di repliche

Percorso: `~/course-gatekeeper/04`.

Correggi `minimumreplicas` e completa `constraint.yaml` con:

- nome `prod-minimum-replicas`;
- `enforcementAction: deny`;
- Deployment del gruppo `apps` nel Namespace `prod`;
- parametro `minimum: 2`.

La policy deve gestire anche `spec.replicas` assente, considerandolo uguale a
1. Verifica che `deployment-no-replicas.yaml` venga negato. Correggi infine
`prod-api.yaml` impostando `replicas: 2`: deve essere accettato.

---

### Q5 - Match ed esclusioni

Percorso: `~/course-gatekeeper/05`.

Usa il template `requiredannotations` della Q1 e completa `constraint.yaml`
per richiedere l'annotation `cost-center` ai Deployment in `dev`, `staging`,
`prod` e `legacy`, ma:

- escludi il Namespace `legacy` tramite `excludedNamespaces`;
- non applicare la policy a Pod o Service.

Applica nell'ordine `dev-deployment.yaml`, `legacy-deployment.yaml` e
`dev-pod.yaml`: solo il Deployment in `dev` deve essere negato.

---

### Q6 - Audit con enforcement dryrun

Percorso: `~/course-gatekeeper/06`.

Crea una Constraint `audit-owner-label` con `enforcementAction: dryrun` che
richieda la label `owner` ai Deployment nei Namespace `team-a` e `team-b`.

1. Attendi un ciclo di audit.
2. Scrivi in `violations.txt` nome, Namespace e messaggio di ogni violazione.
3. Verifica che la creazione di un nuovo Deployment non venga bloccata.

Il setup contiene `team-a-api` senza label e `team-b-worker` con
`owner=batch-team`: l'audit deve riportare soltanto `team-a/team-a-api`.
Usa `new-deployment.yaml` per il test admission; deve essere creato nonostante
la label mancante.

---

### Q7 - Enforcement warn

Percorso: `~/course-gatekeeper/07`.

Crea `warn-missing-environment` usando il template della Q2:

- `enforcementAction: warn`
- richiede la label `environment`
- si applica ai Pod in `dev`

Esegui `kubectl apply` sul Pod fornito e salva warning e output in
`warning.txt`. Il Pod `warning-demo` deve essere creato e l'output deve
contenere il nome della Constraint `warn-missing-environment`.

---

### Q8 - Namespace selector

Percorso: `~/course-gatekeeper/08`.

Crea una Constraint che richieda l'annotation `owner` ai Deployment nei
Namespace con label:

```yaml
policy.gatekeeper/enabled: "true"
```

Non usare una lista statica `namespaces`. Verifica che:

- `staging` e `prod` siano inclusi;
- `exempt` non sia incluso.

Usa `staging-bad.yaml`, `prod-good.yaml` ed `exempt-bad.yaml`. Il primo deve
essere negato; gli altri due devono essere accettati.

---

### Q9 - Vietare Service NodePort

Percorso: `~/course-gatekeeper/09`.

Completa `disallowedservicetypes` con parametro `types`, array di stringhe.
Crea `no-nodeport-services` per vietare `NodePort` e `LoadBalancer` in `prod`.

Verifica prima che `public-api.yaml` venga negato. Correggi lo stesso file
rimuovendo `nodePort` e impostando `type: ClusterIP`; deve poi essere accettato.

---

### Q10 - Host Ingress univoci con inventory

Percorso: `~/course-gatekeeper/10`.

1. Completa e applica il `Config` Gatekeeper chiamato obbligatoriamente
   `config` per sincronizzare gli Ingress.
2. Completa `uniqueingresshost` usando `data.inventory`.
3. Impedisci che un nuovo Ingress utilizzi un host gia presente nel cluster.
4. Verifica che `duplicate.yaml` venga negato.

La policy non deve considerare l'oggetto stesso come duplicato durante UPDATE.
Verifica quindi anche che `kubectl annotate ingress -n dev
existing-shared-host exercise=updated --overwrite` abbia successo.

---

### Q11 - Resource requests e limits

Percorso: `~/course-gatekeeper/11`.

Completa `requiredresources` affinche ogni container e initContainer abbia:

- request CPU;
- request memory;
- limit CPU;
- limit memory.

Applica la policy ai Pod in `apps`. Correggi `worker.yaml` senza rimuovere
l'initContainer. Usa per entrambi i container:

- requests CPU `10m` e memory `16Mi`;
- limits CPU `100m` e memory `64Mi`.

Il primo apply deve essere negato; dopo la correzione il Pod deve essere
creato.

---

### Q12 - Security context

Percorso: `~/course-gatekeeper/12`.

Crea `securepods` con parametri booleani per vietare:

- `hostNetwork`;
- container privilegiati;
- `allowPrivilegeEscalation: true`.

Applica la Constraint a `prod`. Il messaggio deve indicare esattamente quale
campo viola la policy. Imposta tutti i tre parametri della Constraint a
`false`. `pod.yaml` deve inizialmente produrre tre violazioni; correggilo con
`hostNetwork: false`, `privileged: false` e
`allowPrivilegeEscalation: false`.

---

### Q13 - Service type parametrico

Percorso: `~/course-gatekeeper/13`.

Completa `allowedservicetypes`, che deve accettare `parameters.allowedTypes`.
Consenti in `dev` soltanto `ClusterIP` e `ExternalName`.

La policy deve trattare un Service senza `spec.type` come `ClusterIP`.
Usa i file `service-default.yaml`, `service-external.yaml` e
`service-nodeport.yaml`: i primi due devono essere accettati, il terzo negato.

---

### Q14 - Label immutabile durante UPDATE

Percorso: `~/course-gatekeeper/14`.

Crea `immutablelabel` con parametro `label`. La violazione deve verificarsi
solo in operazione `UPDATE` quando il valore della label cambia rispetto a
`input.review.oldObject`.

Proteggi la label `app.kubernetes.io/name` sui Deployment in `prod`.
Creazione e modifica di altre label devono restare consentite.

Applica `deployment.yaml`, quindi:

1. applica `change-team-label.yaml`: deve riuscire;
2. applica `change-app-label.yaml`: deve essere negato.

---

### Q15 - Container, initContainer ed ephemeralContainer

Percorso: `~/course-gatekeeper/15`.

Estendi il template `allowedrepos` della Q3:

- controlla `containers`;
- controlla `initContainers`;
- controlla `ephemeralContainers` quando presenti;
- gestisce in modo sicuro i campi assenti.

La Constraint deve consentire solo `registry.k8s.io/` in `prod`.

Usa `pod-init-denied.yaml` e `pod-all-allowed.yaml`. Il primo deve essere
negato per l'initContainer `init`; il secondo deve essere accettato. Il Rego
deve inoltre iterare in sicurezza su `ephemeralContainers` quando il campo è
presente, senza assumere che esista.

---

### Q16 - ExpansionTemplate

Percorso: `~/course-gatekeeper/16`.

Completa `expansion.yaml` per espandere Deployment in Pod usando
`spec.template`.

Crea poi una policy Pod che richieda:

```yaml
securityContext:
  runAsNonRoot: true
```

La creazione di `deployment-bad.yaml` deve essere negata anche se la Constraint
seleziona esclusivamente `Pod`.

Completa `expansion.yaml` con:

- `applyTo`: gruppo `apps`, versione `v1`, kind `Deployment`;
- `templateSource: spec.template`;
- `generatedGVK`: gruppo vuoto, versione `v1`, kind `Pod`.

Il messaggio di violazione deve essere `Pod must set
spec.securityContext.runAsNonRoot to true`. Verifica anche che
`deployment-good.yaml` venga accettato.

---

### Q17 - Troubleshooting ConstraintTemplate

Percorso: `~/course-gatekeeper/17`.

`broken-template.yaml` contiene errori di schema e Rego.

1. Applica il file e raccogli gli errori.
2. Correggi il template senza cambiarne nome o kind generato.
3. Verifica `status.byPod` e che la CRD della Constraint esista.
4. Scrivi diagnosi e correzioni in `report.md`.

Lo schema corretto deve definire `label` come stringa e il messaggio Rego deve
essere `missing team label: <nome-label>`. Crea infine la Constraint
`require-team-label` da `constraint.yaml`, con parametro `label: team`, per
dimostrare che il kind generato funziona.

---

### Q18 - Schema avanzato dei parametri

Percorso: `~/course-gatekeeper/18`.

Completa lo schema di `workloadstandards`:

- `requiredLabels`: array di stringhe, almeno un elemento;
- `allowedEnvironments`: array di stringhe con valori ammessi `dev`,
  `staging`, `prod`;
- `minimumReplicas`: integer, minimo 1;
- tutti i tre campi sono obbligatori;
- nessuna proprieta aggiuntiva.

Dimostra che Kubernetes rifiuta la Constraint `invalid-parameters.yaml` prima
che arrivi al motore Rego. L'errore deve riferirsi almeno a:

- `requiredLabels`, che non è un array;
- `production`, valore non ammesso;
- `minimumReplicas`, inferiore a 1;
- proprietà `unexpected`, non consentita.

`valid-parameters.yaml` deve invece essere accettato.

---

### Q19 - Policy bundle con Kustomize

Percorso: `~/course-gatekeeper/19/policy-bundle`.

Correggi il bundle Kustomize affinche installi:

- template e Constraint RequiredAnnotations;
- template e Constraint RequiredLabels;
- Namespace `bundle-test`;
- due workload di test.

Le Constraint devono chiamarsi `bundle-required-owner` e
`bundle-required-labels`, applicarsi ai Deployment in `bundle-test` e
richiedere rispettivamente annotation `owner` e label `app`, `team`.

Completa anche `install.sh`: deve applicare prima i ConstraintTemplate,
attendere la creazione delle CRD generate e poi applicare con Kustomize
Namespace e Constraint. Deve infine applicare separatamente
`workload-good.yaml` e `workload-bad.yaml`, salvando l'output in
`result.txt`. L'esecuzione deve essere ripetibile: il workload conforme deve
essere accettato e quello non conforme negato.

---

### Q20 - Incident finale

Percorso: `~/course-gatekeeper/20`.

Il Namespace `prod` contiene workload creati prima dell'enforcement.
I Deployment coinvolti, `checkout` e `payments`, hanno la label
`incident: gatekeeper-final`; tutte le Constraint di questa domanda devono
usare la stessa `labelSelector`.

1. Completa `constraints.yaml` attivando in `dryrun`:
   - `incident-owner`, annotation Deployment `owner`;
   - `incident-repositories`, Pod generati, prefisso `registry.k8s.io/`;
   - `incident-resources`, Pod generati;
   - `incident-security`, Pod generati, tutti i parametri `false`.
2. Raccogli in `audit-before.txt` le violazioni presenti nello status di
   queste quattro Constraint, indicando Constraint, Namespace, risorsa e
   messaggio.
3. Correggi `checkout` e `payments`:
   - annotation Deployment `owner: platform-team`;
   - annotation Deployment `cost-center: cc-incident`;
   - `replicas: 2`;
   - immagine di entrambi i container `registry.k8s.io/pause:3.10`,
     rimuovendo il comando custom di `payments`;
   - requests `10m/16Mi` e limits `100m/64Mi`;
   - Pod security context `runAsNonRoot: true`;
   - `hostNetwork: false`, `privileged: false`,
     `allowPrivilegeEscalation: false`.
4. Porta le Constraint a `deny`.
5. Applica `bad-new-workload.yaml`: deve essere negato.
6. Salva in `report.md`: causa, modifiche, verifica e rollback.
