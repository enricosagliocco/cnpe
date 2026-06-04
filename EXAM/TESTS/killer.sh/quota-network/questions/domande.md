# Le 20 domande dell'esame — ResourceQuota, LimitRange, NetworkPolicy

Scenario deployato da `setup-lab.sh`. Manifest in `~/course/quota-network-lab/`.  
Namespace: **`policy-lab`**.

**Vincolo:** **NON** modificare gli YAML di **Deployment** `api` e `web` né i **Service**.  
Puoi modificare: ResourceQuota, LimitRange, NetworkPolicy e **label del Namespace**.

Verifica in `risposte.md`. Guida estesa: [quota-network-policy-test.md](../quota-network-policy-test.md).

---

### Q1 – Stato iniziale del lab

Dopo `setup-lab.sh`, l'applicazione `web` (curl) deve chiamare l'API nginx su porta 8080.

1. Esegui `kubectl -n policy-lab get pods,resourcequota,limitrange,networkpolicy`
2. Annota quali Pod sono `Pending`, `Running` o `Not Ready`
3. Salva l'output in `/course/quota-network-lab/initial-state.txt`

---

### Q2 – Eventi admission LimitRange

I Deployment richiedono `100m` CPU e `128Mi` memoria per container; i limit sono `200m` / `256Mi`.

1. Descrivi un Pod del Deployment `api` e cerca eventi `Forbidden` legati a LimitRange
2. Identifica i campi `max` e `maxLimitRequestRatio` errati in `default-limits`
3. Registra il messaggio esatto in `initial-state.txt`

---

### Q3 – Correzione LimitRange

1. Modifica `/course/quota-network-lab/broken-quota-network.yaml` (o crea `fix-limitrange.yaml`) alzando:
   - `max.cpu` almeno a `500m`
   - `max.memory` almeno a `512Mi`
   - `maxLimitRequestRatio.cpu` almeno a `2`
2. Applica la LimitRange corretta
3. Riavvia i Deployment `api` e `web` con rollout restart

---

### Q4 – ResourceQuota compute-quota (CPU request)

Con LimitRange corretta, un Pod può restare `Pending` per CPU insufficiente a livello namespace.

1. Leggi `kubectl -n policy-lab describe resourcequota compute-quota`
2. Correggi `requests.cpu`: deve consentire almeno **200m** totali (due Pod da 100m)
3. Applica la ResourceQuota aggiornata

---

### Q5 – ResourceQuota (memoria e limits.cpu)

1. Correggi `requests.memory` per consentire almeno **256Mi** totali (due Pod da 128Mi)
2. Correggi `limits.cpu` per consentire almeno **400m** totali (due limit da 200m)
3. Verifica che entrambi i Pod `api` e `web` siano `Running`

---

### Q6 – Readiness probe web fallita

La readiness del Deployment `web` esegue curl verso `api.policy-lab.svc.cluster.local:8080`.

1. Mostra i log del Pod `web` (`kubectl logs`) e conferma errore `CURL_FAIL` o timeout
2. Conferma che il Service `api` abbia endpoints pronti quando il Pod api è Running
3. Non modificare il Deployment — passa alle policy di rete (Q7+)

---

### Q7 – NetworkPolicy default-deny-all

1. Descrivi la NetworkPolicy `default-deny-all`
2. Spiega perché, con questa policy, serve una policy aggiuntiva permettere traffico esplicito
3. Non eliminare `default-deny-all` (zero-trust)

---

### Q8 – Correzione api-ingress (label)

La policy `api-ingress` ammette solo Pod con label errata.

1. Correggi `api-ingress` in modo che il traffico ingress sull'API (porta **8080**) provenga da Pod con label **`app: web`**
2. Applica la NetworkPolicy
3. Non usare `role: frontend`

---

### Q9 – Correzione api-ingress (porta)

1. Verifica che il container `api` ascolti sulla porta **8080** (Service `api` targetPort)
2. Correggi la regola ingress se la policy espone porta **80** invece di 8080
3. Applica la modifica

---

### Q10 – Correzione web-egress (label API)

1. Correggi `web-egress` affinché l'egress TCP 8080 punti ai Pod con label **`app: api`**
2. Rimuovi riferimenti a `app: api-backend`
3. Applica la policy

---

### Q11 – Correzione web-egress (DNS)

Senza egress verso DNS, `nslookup api.policy-lab.svc.cluster.local` dal Pod web fallisce.

1. Aggiungi regola egress verso namespace **`kube-system`** su porte **UDP/TCP 53**
2. Usa `namespaceSelector` con label `kubernetes.io/metadata.name: kube-system`
3. Applica `web-egress`

---

### Q12 – NetworkPolicy require-prod-namespace

La policy `require-prod-namespace` richiede label sul Namespace.

1. Identifica la label richiesta (`environment: production`)
2. Applica la label al namespace `policy-lab`:

```bash
kubectl label namespace policy-lab environment=production --overwrite
```

3. In alternativa (se consentito dal tuo istruttore), correggi la policy — documenta la scelta in `/course/quota-network-lab/fix-notes.txt`

---

### Q13 – Test connettività dal Pod web

```bash
kubectl -n policy-lab exec deploy/web -- nslookup api.policy-lab.svc.cluster.local
kubectl -n policy-lab exec deploy/web -- curl -sf http://api.policy-lab.svc.cluster.local:8080/
```

1. Esegui i comandi sopra
2. L'output curl deve contenere **`API OK`**
3. Riavvia il Deployment `web` se la readiness non si aggiorna

---

### Q14 – Pod web Ready

1. Attendi `kubectl -n policy-lab wait --for=condition=Ready pod -l app=web --timeout=120s`
2. Verifica `READY 1/1` sul Pod web
3. Registra tempo e eventuali retry in fix-notes.txt

---

### Q15 – Test HTTP frontend (port-forward)

Accesso al frontend (port-forward):

```bash
kubectl -n policy-lab port-forward svc/web 18080:80 &
sleep 2
curl -s http://127.0.0.1:18080/
kill %1
```

1. Esegui il test sopra
2. Il corpo della risposta deve contenere **`API OK`** e non `CURL_FAIL`
3. Salva l'output in `/course/quota-network-lab/curl-frontend.txt`

---

### Q16 – Utilizzo quota dopo fix

1. `kubectl -n policy-lab describe resourcequota compute-quota` deve mostrare utilizzo coerente (es. `requests.cpu: 200m/300m`)
2. Annota valori `used` vs `hard` in fix-notes.txt

---

### Q17 – describe networkpolicy

1. `kubectl -n policy-lab describe networkpolicy api-ingress web-egress`
2. Verifica che le regole corrispondano a Q8–Q11

---

### Q18 – Ordine di troubleshooting

1. Documenta in fix-notes.txt l'ordine applicato: LimitRange → ResourceQuota → NetworkPolicy → label Namespace
2. Spiega perché correggere solo NetworkPolicy prima della quota non basta

---

### Q19 – Blocco controllo (regressione)

1. Modifica temporaneamente `api-ingress` con label sbagliata e verifica che curl dal web fallisca
2. Ripristina la policy corretta
3. Conferma ripristino con Q13

---

### Q20 – Verifica finale

1. `kubectl -n policy-lab get pods` — api e web Running/Ready
2. ResourceQuota e LimitRange corretti
3. NetworkPolicy `default-deny-all`, `api-ingress`, `web-egress` corrette; namespace etichettato se richiesto
4. File `initial-state.txt`, `curl-frontend.txt`, `fix-notes.txt` presenti
5. Deployment e Service **non** modificati rispetto allo YAML originale del lab

---
