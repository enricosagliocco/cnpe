# Kyverno Lab - 20 exam-style tasks

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
### Q1 – Namespace annotation obbligatoria

Percorso: `~/course-kyverno/01`.


La `ValidatingPolicy` `require-ns-annotation` contiene action ed espressione
CEL mancanti.

1. Completa `01/policy.yaml` con `validationActions: [Deny]`.
2. Valida soltanto `CREATE` di Namespace.
3. Richiedi l'annotation `project-name`.
4. Testa localmente `bad.yaml` e `good.yaml`.
5. Applica la policy e verifica che il Namespace senza annotation venga
   rifiutato e quello conforme creato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 01/policy.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/01
kubectl apply -f 01/policy.yaml
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 – Mutation di label e annotation sui Pod

Percorso: `~/course-kyverno/02`.


La `NamespacedMutatingPolicy` `mutate-pods` in `apps` non contiene la patch.

1. Completa una singola mutation `ApplyConfiguration`.
2. Aggiungi label `team: platform`.
3. Aggiungi annotation `teamId: cf1639cf`.
4. Applica policy e `pod.yaml`.
5. Verifica entrambi i metadata sul Pod ammesso.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/02
kubectl apply -f pod.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 – Label obbligatorie sui Deployment

Percorso: `~/course-kyverno/03`.


`require-deployment-labels` non valida ancora le label applicative.

1. Richiedi `app.kubernetes.io/name` e `owner` su CREATE e UPDATE.
2. Usa una sola espressione CEL che riporti tutte le label mancanti.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.
4. Controlla la policy con la CLI e tramite admission.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/03
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 – Numero minimo di repliche

Percorso: `~/course-kyverno/04`.


La policy `minimum-replicas` permette Deployment production con una replica.

1. Applica la policy soltanto ai Deployment con label `environment=production`.
2. Richiedi `spec.replicas >= 2`, trattando il campo assente come una replica.
3. Verifica il diniego di `bad.yaml` e l'accettazione di `good.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/04
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 – Resource requests e limits

Percorso: `~/course-kyverno/05`.


`require-resources` non controlla tutti i container.

1. Richiedi request CPU/memory e limit CPU/memory.
2. Controlla `containers` e `initContainers`.
3. Produci un messaggio con il nome del container non conforme.
4. Verifica `bad.yaml` negato e `good.yaml` accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/05
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 – Registry immagini consentiti

Percorso: `~/course-kyverno/06`.


`allowed-registries` deve limitare le immagini dei Pod nel Namespace `apps`.

1. Consenti soltanto prefissi `registry.k8s.io/` e `ghcr.io/company/`.
2. Controlla container, initContainer ed ephemeralContainer quando presenti.
3. Verifica che il messaggio includa nome e immagine rifiutata.
4. Testa `bad.yaml` e `good.yaml` localmente e sul cluster.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/06` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/06
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 – Vietare tag latest e immagini senza tag

Percorso: `~/course-kyverno/07`.


La policy `disallow-latest` è incompleta.

1. Nega immagini con tag `:latest`.
2. Nega immagini prive di tag o digest.
3. Consenti immagini con tag esplicito o digest.
4. Verifica i tre manifest forniti e salva l'output CLI in `result.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/07` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/07
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 – Pod runAsNonRoot

Percorso: `~/course-kyverno/08`.


`require-run-as-non-root` deve applicare il Pod Security Standard essenziale.

1. Richiedi `spec.securityContext.runAsNonRoot: true`.
2. Richiedi `seccompProfile.type` uguale a `RuntimeDefault` o `Localhost`.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/08` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/08
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 – Container privilegiati e privilege escalation

Percorso: `~/course-kyverno/09`.


La policy `secure-containers` non ispeziona tutti i container.

1. Nega `privileged: true`.
2. Nega `allowPrivilegeEscalation` diverso da `false`.
3. Controlla container, initContainer ed ephemeralContainer.
4. Verifica i manifest positivo e negativo.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/09` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/09
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 – Volumi hostPath vietati

Percorso: `~/course-kyverno/10`.


`disallow-hostpath` deve bloccare accesso al filesystem del nodo.

1. Nega qualsiasi volume con campo `hostPath`.
2. Applica la policy ai Pod CREATE e UPDATE.
3. Verifica che `bad.yaml` sia negato e `good.yaml` accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/10
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 – Service NodePort e LoadBalancer vietati

Percorso: `~/course-kyverno/11`.


La policy `restrict-service-types` deve proteggere il Namespace `production`.

1. Usa una `NamespacedValidatingPolicy` in `production`.
2. Consenti soltanto Service `ClusterIP` ed `ExternalName`.
3. Tratta `spec.type` assente come `ClusterIP`.
4. Verifica Service default e ClusterIP accettati, NodePort negato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/11` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/11
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 – Ingress TLS obbligatorio

Percorso: `~/course-kyverno/12`.


`require-ingress-tls` permette Ingress senza TLS.

1. Richiedi almeno una entry `spec.tls`.
2. Richiedi che ogni host delle rules compaia anche in una entry TLS.
3. Verifica `bad.yaml` negato e `good.yaml` accettato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/12` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/12
kubectl apply -f bad.yaml
kubectl apply -f good.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 – Label team immutabile durante UPDATE

Percorso: `~/course-kyverno/13`.


La policy `immutable-team` deve consentire CREATE ma proteggere gli UPDATE.

1. Associa la validazione soltanto all'operazione UPDATE.
2. Confronta `object` e `oldObject`.
3. Nega la modifica della label `team`, ma consenti aggiornamenti ad altre
   label.
4. Applica `deployment.yaml`, quindi testa le due patch fornite.
5. Verifica che `change-team.yaml` venga negata e `change-version.yaml`
   accettata.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/13` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f deployment.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/13
kubectl apply -f deployment.yaml
kubectl apply -f change-team.yaml
kubectl apply -f change-version.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 – Namespace selector ed esclusione

Percorso: `~/course-kyverno/14`.


`production-security` deve agire soltanto nei Namespace selezionati.

1. Usa `namespaceSelector` per label `policy.kyverno.io/enabled=true`.
2. Escludi i Namespace con label `policy.kyverno.io/exempt=true`.
3. Richiedi label Pod `security-reviewed=true`.
4. Verifica i casi in `team-a`, `team-b` ed `exempt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/14` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/14
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 – Policy namespaced per autonomia team

Percorso: `~/course-kyverno/15`.


La `NamespacedValidatingPolicy` in `team-a` non deve influire su `team-b`.

1. Completa `team-a-owner` per richiedere annotation `owner` ai ConfigMap.
2. Verifica ConfigMap senza owner negato in `team-a`.
3. Verifica lo stesso manifest accettato in `team-b`.
4. Verifica ConfigMap conforme accettato in `team-a`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/15` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/15
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 – Audit prima di Deny

Percorso: `~/course-kyverno/16`.


`require-cost-center` parte in modalità `Audit` e nel cluster esiste già un
Deployment non conforme.

1. Completa la CEL per richiedere label `cost-center`.
2. Applica la policy in Audit e verifica il PolicyReport senza bloccare nuovi
   workload.
3. Correggi il Deployment esistente.
4. Cambia action a `Deny` e verifica che un nuovo Deployment non conforme
   venga rifiutato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/16` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/16
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 – Messaggio dinamico con messageExpression

Percorso: `~/course-kyverno/17`.


La policy `required-owner-message` usa soltanto un messaggio generico.

1. Richiedi annotation `owner` sui Deployment.
2. Usa `messageExpression` per includere il nome del Deployment.
3. Mantieni un `message` statico di fallback.
4. Verifica che il diniego di `bad.yaml` contenga il nome `api-no-owner`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/17` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f bad.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/17
kubectl apply -f bad.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 – Mutation condizionale senza sovrascrittura

Percorso: `~/course-kyverno/18`.


`default-environment` deve aggiungere una label solo quando manca.

1. Crea una `NamespacedMutatingPolicy` in `apps`.
2. Aggiungi `environment: development` soltanto se la label non esiste.
3. Verifica che `pod-missing.yaml` venga mutato.
4. Verifica che `pod-existing.yaml` mantenga `environment: production`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/18` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f pod-missing.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/18
kubectl apply -f pod-missing.yaml
kubectl apply -f pod-existing.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 – Default security context su tutti i container

Percorso: `~/course-kyverno/19`.


La MutatingPolicy `default-container-security` ha una patch incompleta.

1. Usa CEL `map()` per tutti i container.
2. Imposta `allowPrivilegeEscalation: false`.
3. Aggiungi `capabilities.drop: ["ALL"]`.
4. Mantieni nome e immagine originali.
5. Verifica entrambi i container del Pod risultante.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/19` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/19
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 – Incident finale end-to-end

Percorso: `~/course-kyverno/20`.


La directory `20/` contiene un bundle con quattro errori: action Audit al posto
di Deny, selector errato, CEL non sicura sui metadata assenti e mutation che
sovrascrive label esistenti.

1. Correggi `validating-policy.yaml` e `mutating-policy.yaml`.
2. Applica il bundle con `kubectl apply -k`.
3. Verifica Pod non conforme negato.
4. Verifica Pod conforme ammesso e mutato senza sovrascrivere `owner`.
5. Salva test CLI, eventi admission e risorsa finale in `20/report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-kyverno/20` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f validating-policy.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-kyverno/20
kubectl apply -f validating-policy.yaml
kubectl apply -f mutating-policy.yaml
kubectl get events -A --sort-by=.lastTimestamp
```
