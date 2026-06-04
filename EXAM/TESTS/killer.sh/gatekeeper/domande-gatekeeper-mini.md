# CNPE Mini Lab — Gatekeeper focus

Scenario: `gatekeeper-mini`  
Namespace workload: `gk-mini`  
Directory lab: `/course/gatekeeper-mini`  
Tempo consigliato: 45–60 minuti.

Regole stile esame:

- non reinstallare Gatekeeper;
- non cancellare e ricreare i Deployment applicativi se puoi risolvere con patch mirate;
- puoi modificare ConstraintTemplate, Constraint e AssignMetadata;
- puoi patchare i workload solo per renderli conformi alle policy;
- salva gli output richiesti nei file indicati.

---

## Q1 — Verifica Gatekeeper

1. Verifica che i Pod del webhook Gatekeeper siano `Running`.
2. Elenca tutti i `ConstraintTemplate`.
3. Elenca tutte le Constraint create dal lab.
4. Salva un riepilogo in:

```bash
/course/gatekeeper-mini/q1-status.txt
```

---

## Q2 — Required labels: match namespace errato

Il Deployment `payments-api` non ha label `owner`, ma la Constraint non lo intercetta.

1. Trova quale Constraint richiede le label `app` e `owner`.
2. Correggi `match.namespaces` da namespace errato a `gk-mini`.
3. Verifica che la Constraint sia in `deny`.
4. Salva il manifest corretto in:

```bash
/course/gatekeeper-mini/q2-required-labels.yaml
```

---

## Q3 — Required labels: Rego solo Pod

Anche dopo Q2, il template `k8srequiredlabels` controlla solo i Pod.

1. Correggi il `ConstraintTemplate` per validare anche i `Deployment`.
2. Per i Deployment controlla le label in `metadata.labels`.
3. Mantieni il controllo sui Pod.
4. Applica il template e attendi `Ready`.

Suggerimento logico: un Deployment deve avere almeno `metadata.labels.app` e `metadata.labels.owner`.

---

## Q4 — Patch minima su payments-api

Ora `payments-api` deve essere reso conforme.

1. Aggiungi label `owner=payments` al Deployment `payments-api`.
2. Aggiungi la stessa label al Pod template se necessario.
3. Non modificare Service, selector o container.
4. Verifica rollout e salva:

```bash
kubectl -n gk-mini get deploy payments-api --show-labels > /course/gatekeeper-mini/q4-payments-labels.txt
```

---

## Q5 — Required resources: dryrun vs deny

La Constraint `required-container-resources` è in `dryrun`.

1. Cambiala in `deny`.
2. Verifica con `kubectl describe` la differenza tra `dryrun` e `deny`.
3. Salva una nota breve in:

```bash
/course/gatekeeper-mini/q5-enforcement.txt
```

---

## Q6 — Required resources: path Deployment errato

Il Rego del template `k8srequiredresources` usa un path sbagliato per i Deployment.

1. Correggi il controllo dei container dei Deployment usando:

```text
spec.template.spec.containers
```

2. Mantieni il controllo diretto sui Pod usando:

```text
spec.containers
```

3. Applica e attendi `Ready`.

---

## Q7 — Patch resources su payments-api

Il container `api` di `payments-api` ha solo `requests`, ma non `limits`.

1. Aggiungi almeno:
   - `limits.cpu: 200m`
   - `limits.memory: 128Mi`
2. Non cambiare immagine.
3. Verifica che il Deployment resti `Available`.

---

## Q8 — Disallow latest: Deployment non coperto

Il template `k8sdisallowedimages` controlla solo i Pod, ma deve controllare anche i Deployment.

1. Estendi il Rego ai container dei Deployment.
2. Deve intercettare:
   - immagini con tag esplicito `:latest`;
   - immagini senza tag esplicito, per esempio `nginx`, perché Kubernetes le tratta come latest implicito.
3. Applica e attendi `Ready`.

Nota: considera che immagini tipo `registry:5000/app:v1` contengono `:` nel registry. Evita controlli troppo ingenui.

---

## Q9 — Patch immagine payments-api

`payments-api` usa `nginx` senza tag.

1. Cambia l'immagine del container `api` in:

```bash
nginx:1.27-alpine
```

2. Verifica rollout.
3. Crea un Pod di test con `busybox:latest`: deve essere negato.
4. Salva l'errore admission in:

```bash
/course/gatekeeper-mini/q9-denied-latest.txt
```

---

## Q10 — Min replicas troppo alto

La Constraint `min-replicas` richiede almeno 2 repliche, ma il lab vuole permettere Deployment con 1 replica.

1. Modifica il parametro della Constraint a `min: 1`.
2. Verifica che `payments-api` e `catalog-api` siano conformi.
3. Salva:

```bash
kubectl get k8sminreplicas min-replicas -o yaml > /course/gatekeeper-mini/q10-minreplicas.yaml
```

---

## Q11 — AssignMetadata namespace errato

La mutation `default-owner` non viene applicata.

1. Correggi `spec.match.namespaces` a `gk-mini`.
2. Crea un Deployment temporaneo `mutate-check` senza label `owner`.
3. Verifica se Gatekeeper aggiunge `owner=platform`.
4. Elimina il Deployment temporaneo.
5. Salva output in:

```bash
/course/gatekeeper-mini/q11-mutation.txt
```

---

## Q12 — Audit violations

1. Esegui un controllo sulle Constraint:
   - `status.totalViolations`
   - eventuali violation details.
2. Salva l’output in:

```bash
/course/gatekeeper-mini/q12-audit.txt
```

---

## Q13 — Test negativo Pod senza label

1. Crea un Pod temporaneo nel namespace `gk-mini` senza label `owner`.
2. L’admission deve negarlo.
3. Salva il messaggio in:

```bash
/course/gatekeeper-mini/q13-denied-label.txt
```

---

## Q14 — Log Gatekeeper

1. Mostra le ultime 50 righe dei log del webhook Gatekeeper.
2. Cerca riferimenti a denied, violation o admission.
3. Salva in:

```bash
/course/gatekeeper-mini/q14-gatekeeper-logs.txt
```

---

## Q15 — Verifica finale

Alla fine devono essere veri questi punti:

1. `payments-api` e `catalog-api` sono `Available`.
2. Tutte le Constraint sono in `deny`.
3. `busybox:latest` viene negata.
4. un Pod senza `owner` viene negato.
5. un Deployment nuovo senza `owner` viene mutato o negato secondo ordine/effetto delle policy documentato.
6. tutti i `ConstraintTemplate` sono `Ready`.

Salva il report finale in:

```bash
/course/gatekeeper-mini/final-report.txt
```

---

# Comandi utili

```bash
kubectl get constrainttemplate
kubectl describe constrainttemplate k8srequiredlabels

kubectl get k8srequiredlabels,k8srequiredresources,k8sdisallowedimages,k8sminreplicas
kubectl describe k8srequiredlabels required-platform-labels

kubectl get assignmetadata
kubectl describe assignmetadata default-owner

kubectl -n gk-mini get deploy,pod,svc
kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager -c manager --tail=50
```
