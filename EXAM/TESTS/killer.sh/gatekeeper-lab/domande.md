# OPA Gatekeeper Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 – RequiredAnnotations parametrica

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 – RequiredLabels con array

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod-bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/02
kubectl apply -f pod-bad.yaml
kubectl apply -f deployment-good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 – Repository immagini consentiti

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod-allowed.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/03
kubectl apply -f pod-allowed.yaml
kubectl apply -f pod-denied.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 – Numero minimo di repliche

Percorso: `~/course-gatekeeper/04`.

Correggi `minimumreplicas` e completa `constraint.yaml` con:

- nome `prod-minimum-replicas`;
- `enforcementAction: deny`;
- Deployment del gruppo `apps` nel Namespace `prod`;
- parametro `minimum: 2`.

La policy deve gestire anche `spec.replicas` assente, considerandolo uguale a
1. Verifica che `deployment-no-replicas.yaml` venga negato. Correggi infine
`prod-api.yaml` impostando `replicas: 2`: deve essere accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f constraint.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/04
kubectl apply -f constraint.yaml
kubectl apply -f deployment-no-replicas.yaml
kubectl apply -f prod-api.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 – Match ed esclusioni

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f constraint.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/05
kubectl apply -f constraint.yaml
kubectl apply -f dev-deployment.yaml
kubectl apply -f legacy-deployment.yaml
kubectl apply -f dev-pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 – Audit con enforcement dryrun

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/06` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f new-deployment.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/06
kubectl apply -f new-deployment.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 – Enforcement warn

Percorso: `~/course-gatekeeper/07`.

1. Crea `warn-missing-environment` usando il template della Q2 con:
   - `enforcementAction: warn`;
   - label richiesta `environment`;
   - match sui Pod nel Namespace `dev`.
2. Esegui `kubectl apply` sul Pod fornito.
3. Salva warning e output in `warning.txt`.
4. Verifica che il Pod `warning-demo` venga creato e che l'output contenga il
   nome della Constraint `warn-missing-environment`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/07` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/07
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 – Namespace selector

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/08` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f staging-bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/08
kubectl apply -f staging-bad.yaml
kubectl apply -f prod-good.yaml
kubectl apply -f exempt-bad.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 – Vietare Service NodePort

Percorso: `~/course-gatekeeper/09`.

1. Completa `disallowedservicetypes` con il parametro `types`, array di
   stringhe.
2. Crea `no-nodeport-services` per vietare `NodePort` e `LoadBalancer` in
   `prod`.
3. Verifica che `public-api.yaml` venga inizialmente negato.
4. Correggi lo stesso file rimuovendo `nodePort` e impostando
   `type: ClusterIP`.
5. Verifica che il file corretto venga accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/09` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f public-api.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/09
kubectl apply -f public-api.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 – Host Ingress univoci con inventory

Percorso: `~/course-gatekeeper/10`.

1. Completa e applica il `Config` Gatekeeper chiamato obbligatoriamente
   `config` per sincronizzare gli Ingress.
2. Completa `uniqueingresshost` usando `data.inventory`.
3. Impedisci che un nuovo Ingress utilizzi un host gia presente nel cluster.
4. Verifica che `duplicate.yaml` venga negato.

La policy non deve considerare l'oggetto stesso come duplicato durante UPDATE.
Verifica quindi anche che `kubectl annotate ingress -n dev
existing-shared-host exercise=updated --overwrite` abbia successo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f duplicate.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/10
kubectl apply -f duplicate.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 – Resource requests e limits

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/11` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f worker.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/11
kubectl apply -f worker.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 – Security context

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/12` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/12
kubectl apply -f pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 – Service type parametrico

Percorso: `~/course-gatekeeper/13`.

1. Completa `allowedservicetypes`, che deve accettare
   `parameters.allowedTypes`.
2. Consenti nel Namespace `dev` soltanto `ClusterIP` e `ExternalName`.
3. Tratta un Service senza `spec.type` come `ClusterIP`.
4. Applica `service-default.yaml`, `service-external.yaml` e
   `service-nodeport.yaml`.
5. Verifica che i primi due vengano accettati e il terzo negato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f service-default.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/13
kubectl apply -f service-default.yaml
kubectl apply -f service-external.yaml
kubectl apply -f service-nodeport.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 – Label immutabile durante UPDATE

Percorso: `~/course-gatekeeper/14`.

Crea `immutablelabel` con parametro `label`. La violazione deve verificarsi
solo in operazione `UPDATE` quando il valore della label cambia rispetto a
`input.review.oldObject`.

Proteggi la label `app.kubernetes.io/name` sui Deployment in `prod`.
Creazione e modifica di altre label devono restare consentite.

Applica `deployment.yaml`, quindi:

1. applica `change-team-label.yaml`: deve riuscire;
2. applica `change-app-label.yaml`: deve essere negato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/14` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f deployment.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/14
kubectl apply -f deployment.yaml
kubectl apply -f change-team-label.yaml
kubectl apply -f change-app-label.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 – Container, initContainer ed ephemeralContainer

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/15` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod-init-denied.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/15
kubectl apply -f pod-init-denied.yaml
kubectl apply -f pod-all-allowed.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 – ExpansionTemplate

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/16` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f expansion.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/16
kubectl apply -f expansion.yaml
kubectl apply -f deployment-bad.yaml
kubectl apply -f deployment-good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 – Troubleshooting ConstraintTemplate

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/17` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f broken-template.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/17
kubectl apply -f broken-template.yaml
kubectl apply -f constraint.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 – Schema avanzato dei parametri

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/18` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f invalid-parameters.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/18
kubectl apply -f invalid-parameters.yaml
kubectl apply -f valid-parameters.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 – Policy bundle con Kustomize

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/19/policy-bundle` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f install.sh
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/19/policy-bundle
kubectl apply -f workload-good.yaml
kubectl apply -f workload-bad.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 – Incident finale

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

**Tip 1**

Esamina tutti i manifest presenti in `~/course-gatekeeper/20` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f constraints.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-gatekeeper/20
kubectl apply -f constraints.yaml
kubectl apply -f bad-new-workload.yaml
kubectl get events -A --sort-by=.lastTimestamp
```
