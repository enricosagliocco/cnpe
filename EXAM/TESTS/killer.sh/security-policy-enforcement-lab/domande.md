# Security and Policy Enforcement Lab - 20 exam-style tasks

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
### Q1 - Diagnosi della comunicazione sicura

Percorso: `~/course-security-policy-enforcement/01`.

Lo scenario contiene `frontend`, `payments`, due client di test e una
NetworkPolicy inizialmente chiusa.

1. Controlla stato e log dei Deployment `frontend` e `payments`.
2. Ispeziona Service, EndpointSlice, porte dei container e NetworkPolicy.
3. Individua le due cause che impediscono la comunicazione iniziale.
4. Non modificare direttamente i Deployment durante la diagnosi.
5. Registra in `verification.txt` URL errato e regola di rete mancante.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Endpoint mTLS

Percorso: `~/course-security-policy-enforcement/01`.

1. Correggi `app-config.yaml`.
2. Imposta `BACKEND_URL` a
   `https://payments.security-apps.svc:8443`.
3. Applica il ConfigMap.
4. Elimina soltanto il Pod `frontend` per farlo ricreare con la nuova
   variabile, senza modificare il Deployment.
5. Verifica nei log che il client utilizzi HTTPS e la porta `8443`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f app-config.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/01
kubectl apply -f app-config.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - NetworkPolicy per payments

Percorso: `~/course-security-policy-enforcement/01`.

Completa `networkpolicy.yaml`:

1. Mantieni il `podSelector` sul workload `app=payments`.
2. Consenti ingress soltanto dai Pod con label `app=frontend`.
3. Consenti esclusivamente protocollo TCP e porta `8443`.
4. Applica la NetworkPolicy.
5. Verifica che non siano state aperte altre porte o sorgenti.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f networkpolicy.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/01
kubectl apply -f networkpolicy.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Autenticazione e isolamento

Percorso: `~/course-security-policy-enforcement/01`.

Dimostra tutti i casi seguenti:

1. Il Deployment `frontend`, dotato di certificato client, riceve
   `payments ok`.
2. `rogue-client` non raggiunge la porta `8443` per effetto della
   NetworkPolicy.
3. `unauthenticated-client`, ammesso dalla label di rete ma privo di
   certificato, viene rifiutato dal server mTLS.
4. Non mostrare il contenuto dei Secret durante i test.
5. Salva comandi, exit code e risultati in `verification.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Diagnosi dei privilegi auditor

Percorso: `~/course-security-policy-enforcement/02`.

Il ServiceAccount `platform-auditor` parte con privilegi eccessivi, ma senza
`cluster-admin` o regole wildcard.

1. Esegui `kubectl auth can-i --list` impersonando il ServiceAccount.
2. Identifica i permessi di scrittura non necessari.
3. Identifica l'accesso improprio a Secret e risorse RBAC.
4. Salva lo stato iniziale in `auth-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 - RBAC read-only

Percorso: `~/course-security-policy-enforcement/02`.

Correggi `rbac.yaml` mantenendo ServiceAccount, ClusterRole e binding:

1. Consenti soltanto `get`, `list` e `watch`.
2. Consenti lettura di Pod, log, Service e workload del gruppo `apps`.
3. Consenti lettura di `ValidatingPolicy`, PolicyReport e
   ClusterPolicyReport.
4. Consenti lettura di Pipeline, PipelineRun e TaskRun Tekton.
5. Non consentire accesso a Secret, risorse RBAC o Node.
6. Applica il file corretto e verifica le regole effettive.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f rbac.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/02
kubectl apply -f rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Verifiche negative RBAC

Percorso: `~/course-security-policy-enforcement/02`.

Usando `kubectl auth can-i` con impersonation, verifica che
`platform-auditor` non possa:

1. leggere Secret;
2. creare, aggiornare o eliminare workload;
3. leggere o modificare Role e RoleBinding;
4. leggere Node;
5. creare o modificare policy e risorse Tekton.

Ogni comando deve restituire `no`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Evidenza least privilege

Percorso: `~/course-security-policy-enforcement/02`.

1. Esegui almeno quattro test positivi di lettura.
2. Esegui almeno quattro test negativi.
3. Includi almeno un test per workload, log, policy report e Tekton.
4. Salva comando, risultato atteso e risultato osservato in
   `auth-check.txt`.
5. Verifica che non siano presenti verbi o risorse wildcard.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Policy audit sui metadata

Percorso: `~/course-security-policy-enforcement/03`.

Completa `audit-policy.yaml`:

1. Mantieni `validationActions: [Audit]`.
2. Usa `namespaceSelector` per i Namespace con label
   `security.cnpe.io/policy=enabled`.
3. Richiedi le label `owner` e `data-classification`.
4. Gestisci in modo sicuro metadata o label assenti nella CEL.
5. Applica la `ValidatingPolicy`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f audit-policy.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/03
kubectl apply -f audit-policy.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 - PolicyReport iniziale

Percorso: `~/course-security-policy-enforcement/03`.

Il Deployment `legacy-api` esiste già ed è non conforme.

1. Attendi la riconciliazione del reports controller.
2. Verifica che la policy resti in modalità Audit.
3. Conferma che nuovi workload non conformi non vengano bloccati.
4. Individua la violazione di `security-apps/legacy-api`.
5. Salva in `audit-before.txt` policy, rule, risorsa, messaggio e timestamp.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - Remediation dei metadata

Percorso: `~/course-security-policy-enforcement/03`.

Correggi il Deployment esistente senza modificarne immagine o configurazione:

1. Aggiungi label `owner=platform-team`.
2. Aggiungi label `data-classification=internal`.
3. Verifica che entrambe siano presenti sul Deployment.
4. Non modificare il Pod template se non richiesto dalla patch.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Compliance report finale

Percorso: `~/course-security-policy-enforcement/03`.

1. Attendi un nuovo ciclo di report.
2. Verifica che `legacy-api` non compaia più tra le violazioni.
3. Controlla che la policy sia ancora in modalità Audit.
4. Salva stato della policy e assenza della violazione in
   `audit-after.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Governance Pod con namespace selector

Percorso: `~/course-security-policy-enforcement/04`.

Completa `governance-policy.yaml`:

1. Cambia l'azione da `Audit` a `Deny`.
2. Aggiungi un `namespaceSelector` per
   `security.cnpe.io/policy=enabled`.
3. Mantieni il match sui Pod in CREATE e UPDATE.
4. Verifica che il Namespace `security-exempt` resti escluso.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f governance-policy.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/04
kubectl apply -f governance-policy.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - Security context

Percorso: `~/course-security-policy-enforcement/04`.

Completa la CEL affinché:

1. richieda `spec.securityContext.runAsNonRoot: true`;
2. neghi `privileged: true`;
3. richieda `allowPrivilegeEscalation: false`;
4. richieda la capability `ALL` in `capabilities.drop`;
5. controlli tutti i container senza fallire su campi opzionali assenti.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Immagini referenziate tramite digest

Percorso: `~/course-security-policy-enforcement/04`.

1. Richiedi `@sha256:` nell'immagine di ogni container.
2. Nega tag mutabili come `latest`.
3. Integra il controllo nella stessa policy di governance.
4. Mantieni un messaggio di diniego che descriva i requisiti.
5. Verifica lato client la sintassi della policy completata.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 - Test admission

Percorso: `~/course-security-policy-enforcement/04`.

Applica la policy e poi, nell'ordine:

1. applica `pod-bad.yaml`: deve essere negato;
2. applica `pod-good.yaml`: deve essere accettato;
3. applica `pod-excluded.yaml`: deve essere accettato perché il Namespace
   non è selezionato;
4. salva output admission, messaggi e risorse create in `admission.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod-bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/04
kubectl apply -f pod-bad.yaml
kubectl apply -f pod-good.yaml
kubectl apply -f pod-excluded.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - Validazione SBOM

Percorso: `~/course-security-policy-enforcement/05`.

Completa lo step `verify` del task inline `compliance-gate` in
`pipeline.yaml`:

1. verifica che `generated-sbom.json` contenga `SPDXID`;
2. verifica che l'identificatore non sia vuoto;
3. nega qualsiasi package con `licenseConcluded: NOASSERTION`;
4. termina con exit code diverso da zero in caso di errore;
5. non scrivere ancora `passed` prima di aver completato tutti i controlli.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pipeline.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/05
kubectl apply -f pipeline.yaml
kubectl apply -f generated-sbom.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 - Vulnerability report

Percorso: `~/course-security-policy-enforcement/05`.

Nello stesso step:

1. verifica l'esistenza di `scan-report.json`;
2. leggi `summary.critical`;
3. nega il report quando il valore è maggiore di zero;
4. scrivi `passed` nel result `decision` soltanto dopo SBOM e vulnerability
   check riusciti;
5. applica la Pipeline completata.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f scan-report.json
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/05
kubectl apply -f scan-report.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Gate di deploy

Percorso: `~/course-security-policy-enforcement/05`.

1. Completa `when` affinché `deploy` venga eseguito soltanto quando il result
   `decision` di `compliance-gate` è `passed`.
2. Esegui `pipelinerun.yaml` con gli input iniziali: il compliance gate deve
   fallire e `deploy` non deve essere eseguito.
3. Correggi `sbom.json` con una licenza esplicita e porta
   `summary.critical` a `0` in `scan-report.json`.
4. Ricrea il ConfigMap `security-inputs` dai file corretti.
5. Crea un nuovo PipelineRun e verifica l'esecuzione di `deploy`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pipelinerun.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/05
kubectl apply -f pipelinerun.yaml
kubectl apply -f sbom.json
kubectl apply -f scan-report.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 - Verifica finale security

Percorso: `~/course-security-policy-enforcement/05`.

Esegui:

```bash
kubectl -n security-apps get networkpolicy,deploy,pods
kubectl auth can-i --as=system:serviceaccount:security-platform:platform-auditor --list
kubectl get validatingpolicies
kubectl get policyreports,clusterpolicyreports -A
kubectl -n security-pipeline get pipeline,pipelinerun,taskrun
```

Completa `pipeline-result.txt` con:

1. nomi dei due PipelineRun e relativi TaskRun;
2. errore SBOM o vulnerability del primo tentativo;
3. prova che il primo deploy sia stato bloccato;
4. result `decision=passed` del secondo tentativo;
5. log `deployment approved` del deploy eseguito.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-security-policy-enforcement/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-security-policy-enforcement/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
