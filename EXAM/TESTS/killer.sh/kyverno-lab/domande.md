# Le 20 domande dell'esame — Kyverno Lab (simulatore lab)

Scenario deployato da `setup-kyverno-lab.sh`. Manifest e file starter in
`~/course-kyverno/`.

**Vincolo:** non disinstallare Kyverno e non modificare i Deployment core nel
Namespace `kyverno`. Usa le API CEL `policies.kyverno.io/v1`.

Ogni domanda contiene una policy incompleta o errata e manifest di test. Devi:

1. riprodurre il comportamento iniziale;
2. completare o correggere `policy.yaml`;
3. testare localmente con `kyverno apply`;
4. applicare la policy al cluster;
5. verificare realmente il caso negato e quello consentito.

Le domande sono indipendenti. Dopo aver completato le verifiche di una
domanda, elimina la relativa policy prima di passare alla successiva, salvo
quando la traccia richiede esplicitamente di riutilizzarla. In questo modo una
policy `Deny` precedente non altera i test dei manifest successivi.

Comandi utili:

```bash
kyverno apply ./policy.yaml --resource ./bad.yaml
kubectl apply -f policy.yaml
kubectl get validatingpolicies,mutatingpolicies
kubectl get policyreport,clusterpolicyreport -A
kubectl -n kyverno logs deploy/kyverno-admission-controller
```

---

### Q1 – Namespace annotation obbligatoria

La `ValidatingPolicy` `require-ns-annotation` contiene action ed espressione
CEL mancanti.

1. Completa `01/policy.yaml` con `validationActions: [Deny]`.
2. Valida soltanto `CREATE` di Namespace.
3. Richiedi l'annotation `project-name`.
4. Testa localmente `bad.yaml` e `good.yaml`.
5. Applica la policy e verifica che il Namespace senza annotation venga
   rifiutato e quello conforme creato.

---

### Q2 – Mutation di label e annotation sui Pod

La `NamespacedMutatingPolicy` `mutate-pods` in `apps` non contiene la patch.

1. Completa una singola mutation `ApplyConfiguration`.
2. Aggiungi label `team: platform`.
3. Aggiungi annotation `teamId: cf1639cf`.
4. Applica policy e `pod.yaml`.
5. Verifica entrambi i metadata sul Pod ammesso.

---

### Q3 – Label obbligatorie sui Deployment

`require-deployment-labels` non valida ancora le label applicative.

1. Richiedi `app.kubernetes.io/name` e `owner` su CREATE e UPDATE.
2. Usa una sola espressione CEL che riporti tutte le label mancanti.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.
4. Controlla la policy con la CLI e tramite admission.

---

### Q4 – Numero minimo di repliche

La policy `minimum-replicas` permette Deployment production con una replica.

1. Applica la policy soltanto ai Deployment con label `environment=production`.
2. Richiedi `spec.replicas >= 2`, trattando il campo assente come una replica.
3. Verifica il diniego di `bad.yaml` e l'accettazione di `good.yaml`.

---

### Q5 – Resource requests e limits

`require-resources` non controlla tutti i container.

1. Richiedi request CPU/memory e limit CPU/memory.
2. Controlla `containers` e `initContainers`.
3. Produci un messaggio con il nome del container non conforme.
4. Verifica `bad.yaml` negato e `good.yaml` accettato.

---

### Q6 – Registry immagini consentiti

`allowed-registries` deve limitare le immagini dei Pod nel Namespace `apps`.

1. Consenti soltanto prefissi `registry.k8s.io/` e `ghcr.io/company/`.
2. Controlla container, initContainer ed ephemeralContainer quando presenti.
3. Verifica che il messaggio includa nome e immagine rifiutata.
4. Testa `bad.yaml` e `good.yaml` localmente e sul cluster.

---

### Q7 – Vietare tag latest e immagini senza tag

La policy `disallow-latest` è incompleta.

1. Nega immagini con tag `:latest`.
2. Nega immagini prive di tag o digest.
3. Consenti immagini con tag esplicito o digest.
4. Verifica i tre manifest forniti e salva l'output CLI in `result.txt`.

---

### Q8 – Pod runAsNonRoot

`require-run-as-non-root` deve applicare il Pod Security Standard essenziale.

1. Richiedi `spec.securityContext.runAsNonRoot: true`.
2. Richiedi `seccompProfile.type` uguale a `RuntimeDefault` o `Localhost`.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.

---

### Q9 – Container privilegiati e privilege escalation

La policy `secure-containers` non ispeziona tutti i container.

1. Nega `privileged: true`.
2. Nega `allowPrivilegeEscalation` diverso da `false`.
3. Controlla container, initContainer ed ephemeralContainer.
4. Verifica i manifest positivo e negativo.

---

### Q10 – Volumi hostPath vietati

`disallow-hostpath` deve bloccare accesso al filesystem del nodo.

1. Nega qualsiasi volume con campo `hostPath`.
2. Applica la policy ai Pod CREATE e UPDATE.
3. Verifica che `bad.yaml` sia negato e `good.yaml` accettato.

---

### Q11 – Service NodePort e LoadBalancer vietati

La policy `restrict-service-types` deve proteggere il Namespace `production`.

1. Usa una `NamespacedValidatingPolicy` in `production`.
2. Consenti soltanto Service `ClusterIP` ed `ExternalName`.
3. Tratta `spec.type` assente come `ClusterIP`.
4. Verifica Service default e ClusterIP accettati, NodePort negato.

---

### Q12 – Ingress TLS obbligatorio

`require-ingress-tls` permette Ingress senza TLS.

1. Richiedi almeno una entry `spec.tls`.
2. Richiedi che ogni host delle rules compaia anche in una entry TLS.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.

---

### Q13 – Label team immutabile durante UPDATE

La policy `immutable-team` deve consentire CREATE ma proteggere gli UPDATE.

1. Associa la validazione soltanto all'operazione UPDATE.
2. Confronta `object` e `oldObject`.
3. Nega la modifica della label `team`, ma consenti aggiornamenti ad altre
   label.
4. Applica `deployment.yaml`, quindi testa le due patch fornite.
5. Verifica che `change-team.yaml` venga negata e `change-version.yaml`
   accettata.

---

### Q14 – Namespace selector ed esclusione

`production-security` deve agire soltanto nei Namespace selezionati.

1. Usa `namespaceSelector` per label `policy.kyverno.io/enabled=true`.
2. Escludi i Namespace con label `policy.kyverno.io/exempt=true`.
3. Richiedi label Pod `security-reviewed=true`.
4. Verifica i casi in `team-a`, `team-b` ed `exempt`.

---

### Q15 – Policy namespaced per autonomia team

La `NamespacedValidatingPolicy` in `team-a` non deve influire su `team-b`.

1. Completa `team-a-owner` per richiedere annotation `owner` ai ConfigMap.
2. Verifica ConfigMap senza owner negato in `team-a`.
3. Verifica lo stesso manifest accettato in `team-b`.
4. Verifica ConfigMap conforme accettato in `team-a`.

---

### Q16 – Audit prima di Deny

`require-cost-center` parte in modalità `Audit` e nel cluster esiste già un
Deployment non conforme.

1. Completa la CEL per richiedere label `cost-center`.
2. Applica la policy in Audit e verifica il PolicyReport senza bloccare nuovi
   workload.
3. Correggi il Deployment esistente.
4. Cambia action a `Deny` e verifica che un nuovo Deployment non conforme
   venga rifiutato.

---

### Q17 – Messaggio dinamico con messageExpression

La policy `required-owner-message` usa soltanto un messaggio generico.

1. Richiedi annotation `owner` sui Deployment.
2. Usa `messageExpression` per includere il nome del Deployment.
3. Mantieni un `message` statico di fallback.
4. Verifica che il diniego di `bad.yaml` contenga il nome `api-no-owner`.

---

### Q18 – Mutation condizionale senza sovrascrittura

`default-environment` deve aggiungere una label solo quando manca.

1. Crea una `NamespacedMutatingPolicy` in `apps`.
2. Aggiungi `environment: development` soltanto se la label non esiste.
3. Verifica che `pod-missing.yaml` venga mutato.
4. Verifica che `pod-existing.yaml` mantenga `environment: production`.

---

### Q19 – Default security context su tutti i container

La MutatingPolicy `default-container-security` ha una patch incompleta.

1. Usa CEL `map()` per tutti i container.
2. Imposta `allowPrivilegeEscalation: false`.
3. Aggiungi `capabilities.drop: ["ALL"]`.
4. Mantieni nome e immagine originali.
5. Verifica entrambi i container del Pod risultante.

---

### Q20 – Incident finale end-to-end

La directory `20/` contiene un bundle con quattro errori: action Audit al posto
di Deny, selector errato, CEL non sicura sui metadata assenti e mutation che
sovrascrive label esistenti.

1. Correggi `validating-policy.yaml` e `mutating-policy.yaml`.
2. Applica il bundle con `kubectl apply -k`.
3. Verifica Pod non conforme negato.
4. Verifica Pod conforme ammesso e mutato senza sovrascrivere `owner`.
5. Salva test CLI, eventi admission e risorsa finale in `20/report.md`.
