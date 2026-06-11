# Le 20 domande dell'esame — OPA Gatekeeper Lab (simulatore lab)

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

Ogni domanda contiene almeno uno starter incompleto e workload di test
positivi o negativi. Devi applicare ConstraintTemplate e Constraint, attendere
la CRD generata, eseguire realmente i workload e verificare admission e audit.
La sola compilazione del Rego o la modifica del file non completa
l'esercizio.

Comandi utili:

```bash
kubectl get constrainttemplates
kubectl get constraints
kubectl describe <constraint-kind> <constraint-name>
kubectl get <constraint-kind> <constraint-name> -o yaml
kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager
kubectl -n gatekeeper-system logs deploy/gatekeeper-audit
```

Accesso GUI:

Gatekeeper non include una dashboard web dedicata. Usa Lens/OpenLens con il
kubeconfig corrente. In **Custom Resources** cerca `ConstraintTemplate` e i
kind dei Constraint; usa **Events** e **Pod Logs** per controller e audit.

```bash
kubectl config current-context
kubectl config view --minify --raw
```

Non sono richieste credenziali ulteriori rispetto al kubeconfig. Mantieni il
terminale per applicare i file starter e per i test di admission positivi e
negativi richiesti dalle tracce.

---

### Q1 – RequiredAnnotations parametrica
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q2 – RequiredLabels con array
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/02`.

Completa `requiredlabels` affinche:

1. Accetti `parameters.labels`, array di stringhe.
2. Calcoli tutte le label mancanti.
3. Produca una singola violazione contenente l'elenco delle label mancanti.

Crea `require-app-team-labels` per Pod e Deployment in `apps`; richiedi
`app` e `team`.

Usa `pod-bad.yaml` e `deployment-good.yaml`. Il Pod deve essere negato con
entrambe le label nel messaggio; il Deployment deve essere accettato.
Verifica inoltre che la Constraint compaia in `kubectl get constraints`.

---

### Q3 – Repository immagini consentiti
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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
Verifica infine che il Pod consentito non compaia nelle violazioni audit.

---

### Q4 – Numero minimo di repliche
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q5 – Match ed esclusioni
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/05`.

1. Usa il template `requiredannotations` della Q1 e completa
   `constraint.yaml` per richiedere l'annotation `cost-center` ai Deployment
   in `dev`, `staging`, `prod` e `legacy`.
2. Configura il match in modo che:
   - il Namespace `legacy` sia escluso tramite `excludedNamespaces`;
   - la policy non si applichi a Pod o Service.
3. Applica nell'ordine `dev-deployment.yaml`, `legacy-deployment.yaml` e
   `dev-pod.yaml`.
4. Verifica che solo il Deployment in `dev` venga negato.

---

### Q6 – Audit con enforcement dryrun
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q7 – Enforcement warn
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/07`.

1. Crea `warn-missing-environment` usando il template della Q2 con:
   - `enforcementAction: warn`;
   - label richiesta `environment`;
   - match sui Pod nel Namespace `dev`.
2. Esegui `kubectl apply` sul Pod fornito.
3. Salva warning e output in `warning.txt`.
4. Verifica che il Pod `warning-demo` venga creato e che l'output contenga il
   nome della Constraint `warn-missing-environment`.

---

### Q8 – Namespace selector
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/08`.

1. Crea una Constraint che richieda l'annotation `owner` ai Deployment nei
   Namespace con label:

```yaml
policy.gatekeeper/enabled: "true"
```

2. Non usare una lista statica `namespaces`.
3. Verifica che:
   - `staging` e `prod` siano inclusi;
   - `exempt` non sia incluso.
4. Usa `staging-bad.yaml`, `prod-good.yaml` ed `exempt-bad.yaml`.
5. Verifica che il primo venga negato e gli altri due accettati.

---

### Q9 – Vietare Service NodePort
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/09`.

1. Completa `disallowedservicetypes` con il parametro `types`, array di
   stringhe.
2. Crea `no-nodeport-services` per vietare `NodePort` e `LoadBalancer` in
   `prod`.
3. Verifica che `public-api.yaml` venga inizialmente negato.
4. Correggi lo stesso file rimuovendo `nodePort` e impostando
   `type: ClusterIP`.
5. Verifica che il file corretto venga accettato.

---

### Q10 – Host Ingress univoci con inventory
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q11 – Resource requests e limits
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/11`.

1. Completa `requiredresources` affinché ogni container e initContainer abbia:
   - request CPU;
   - request memory;
   - limit CPU;
   - limit memory.
2. Applica la policy ai Pod nel Namespace `apps`.
3. Verifica che il primo apply di `worker.yaml` venga negato.
4. Correggi `worker.yaml` senza rimuovere l'initContainer usando per entrambi
   i container:
   - requests CPU `10m` e memory `16Mi`;
   - limits CPU `100m` e memory `64Mi`.
5. Verifica che dopo la correzione il Pod venga creato.

---

### Q12 – Security context
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/12`.

1. Crea `securepods` con parametri booleani per vietare:
   - `hostNetwork`;
   - container privilegiati;
   - `allowPrivilegeEscalation: true`.
2. Applica la Constraint al Namespace `prod`.
3. Imposta tutti e tre i parametri della Constraint a `false`.
4. Assicurati che il messaggio indichi esattamente quale campo viola la
   policy.
5. Verifica che `pod.yaml` produca inizialmente tre violazioni.
6. Correggilo con `hostNetwork: false`, `privileged: false` e
   `allowPrivilegeEscalation: false`.

---

### Q13 – Service type parametrico
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/13`.

1. Completa `allowedservicetypes`, che deve accettare
   `parameters.allowedTypes`.
2. Consenti nel Namespace `dev` soltanto `ClusterIP` e `ExternalName`.
3. Tratta un Service senza `spec.type` come `ClusterIP`.
4. Applica `service-default.yaml`, `service-external.yaml` e
   `service-nodeport.yaml`.
5. Verifica che i primi due vengano accettati e il terzo negato.

---

### Q14 – Label immutabile durante UPDATE
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q15 – Container, initContainer ed ephemeralContainer
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/15`.

1. Estendi il template `allowedrepos` della Q3 affinché:
   - controlli `containers`;
   - controlli `initContainers`;
   - controlli `ephemeralContainers` quando presenti;
   - gestisca in modo sicuro i campi assenti.
2. Configura la Constraint per consentire solo `registry.k8s.io/` in `prod`.
3. Applica `pod-init-denied.yaml` e verifica che venga negato per
   l'initContainer `init`.
4. Applica `pod-all-allowed.yaml` e verifica che venga accettato.
5. Verifica che il Rego iteri in sicurezza su `ephemeralContainers` senza
   assumere che il campo esista.

---

### Q16 – ExpansionTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/16`.

1. Completa `expansion.yaml` per espandere Deployment in Pod usando
   `spec.template` con:
   - `applyTo`: gruppo `apps`, versione `v1`, kind `Deployment`;
   - `templateSource: spec.template`;
   - `generatedGVK`: gruppo vuoto, versione `v1`, kind `Pod`.
2. Crea una policy Pod che richieda:

```yaml
securityContext:
  runAsNonRoot: true
```

3. Imposta il messaggio di violazione a
   `Pod must set spec.securityContext.runAsNonRoot to true`.
4. Verifica che `deployment-bad.yaml` venga negato anche se la Constraint
   seleziona esclusivamente `Pod`.
5. Verifica che `deployment-good.yaml` venga accettato.

---

### Q17 – Troubleshooting ConstraintTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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

### Q18 – Schema avanzato dei parametri
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/18`.

1. Completa lo schema di `workloadstandards`:
   - `requiredLabels`: array di stringhe, almeno un elemento;
   - `allowedEnvironments`: array di stringhe con valori ammessi `dev`,
     `staging`, `prod`;
   - `minimumReplicas`: integer, minimo 1;
   - tutti e tre i campi obbligatori;
   - nessuna proprietà aggiuntiva.
2. Dimostra che Kubernetes rifiuta `invalid-parameters.yaml` prima che arrivi
   al motore Rego.
3. Verifica che l'errore faccia riferimento almeno a:
   - `requiredLabels`, che non è un array;
   - `production`, valore non ammesso;
   - `minimumReplicas`, inferiore a 1;
   - proprietà `unexpected`, non consentita.
4. Verifica che `valid-parameters.yaml` venga accettato.

---

### Q19 – Policy bundle con Kustomize
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-gatekeeper/19/policy-bundle`.

1. Correggi il bundle Kustomize affinché installi:
   - template e Constraint RequiredAnnotations;
   - template e Constraint RequiredLabels;
   - Namespace `bundle-test`;
   - due workload di test.
2. Configura le Constraint con i nomi `bundle-required-owner` e
   `bundle-required-labels`.
3. Applicale ai Deployment in `bundle-test`, richiedendo rispettivamente:
   - annotation `owner`;
   - label `app` e `team`.
4. Completa `install.sh` affinché:
   - applichi prima i ConstraintTemplate;
   - attenda la creazione delle CRD generate;
   - applichi con Kustomize Namespace e Constraint;
   - applichi separatamente `workload-good.yaml` e `workload-bad.yaml`;
   - salvi l'output in `result.txt`.
5. Verifica che l'esecuzione sia ripetibile, che il workload conforme venga
   accettato e quello non conforme negato.

---

### Q20 – Incident finale
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

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
