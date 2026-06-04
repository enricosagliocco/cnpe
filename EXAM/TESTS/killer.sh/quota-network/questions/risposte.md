# Risposte — Quota / LimitRange / NetworkPolicy (`policy-lab`)

Soluzioni per `domande.md` (stile esame Killer Shell). Setup: `setup-lab.sh`.

---

### Q1 – Stato iniziale

Output atteso: Pod `api`/`web` Pending o web Running Not Ready; LimitRange/Quota/4 NetworkPolicy presenti.

---

### Q2 – Eventi LimitRange

Messaggio tipico: `maximum cpu usage per Container is 50m` e/o violazione `maxLimitRequestRatio` (limit 200m vs request 100m).

---

### Q3 – LimitRange fix

```yaml
# fix-limitrange.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: policy-lab
spec:
  limits:
    - type: Container
      max:
        cpu: "500m"
        memory: "512Mi"
      maxLimitRequestRatio:
        cpu: "2"
        memory: "2"
    - type: Pod
      max:
        cpu: "500m"
        memory: "512Mi"
```

```bash
kubectl apply -f ~/course/quota-network-lab/fix-limitrange.yaml
kubectl -n policy-lab rollout restart deployment/api deployment/web
```

---

### Q4 – ResourceQuota CPU

```bash
kubectl -n policy-lab patch resourcequota compute-quota --type merge -p \
  '{"spec":{"hard":{"requests.cpu":"300m"}}}'
```

---

### Q5 – ResourceQuota memoria e limits

```bash
kubectl -n policy-lab patch resourcequota compute-quota --type merge -p \
  '{"spec":{"hard":{"requests.memory":"512Mi","limits.cpu":"1"}}}'
kubectl -n policy-lab get pods -w
```

---

### Q6 – Readiness web

Log con `CURL_FAIL` finché rete non è corretta. Service `api` endpoints OK quando Pod api Running.

---

### Q7 – default-deny-all

Policy con `podSelector: {}` e `policyTypes` Ingress+Egress senza regole allow → traffico bloccato salvo altre policy permissive.

---

### Q8 – api-ingress label

```yaml
ingress:
  - from:
      - podSelector:
          matchLabels:
            app: web
    ports:
      - protocol: TCP
        port: 8080
```

---

### Q9 – api-ingress porta

Porta **8080** (non 80), allineata a `containerPort` e `Service` targetPort.

---

### Q10 – web-egress label

```yaml
- to:
    - podSelector:
        matchLabels:
          app: api
  ports:
    - protocol: TCP
      port: 8080
```

---

### Q11 – web-egress DNS

```yaml
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
  ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

---

### Q12 – require-prod-namespace

```bash
kubectl label namespace policy-lab environment=production --overwrite
```

---

### Q13 – Test curl

```bash
kubectl -n policy-lab exec deploy/web -- curl -sf http://api.policy-lab.svc.cluster.local:8080/
# API OK
```

---

### Q14 – web Ready

```bash
kubectl -n policy-lab rollout restart deployment/web
kubectl -n policy-lab wait --for=condition=Ready pod -l app=web --timeout=120s
```

---

### Q15 – port-forward frontend

Corpo risposta contiene `API OK`, non `CURL_FAIL`.

---

### Q16 – Quota used

Esempio: `requests.cpu: 200m/300m`, `requests.memory: 256Mi/512Mi`.

---

### Q17 – describe netpol

Regole devono riflettere Q8–Q11.

---

### Q18 – Ordine fix

LimitRange → ResourceQuota → NetworkPolicy → label Namespace.

---

### Q19 – Regressione

Ripristinare `app: web` su api-ingress dopo test.

---

### Q20 – Finale

api + web Running/Ready; quota/limitrange/netpol corretti; Deploy/Service invariati; file di log in `~/course/quota-network-lab/`.

Manifest completi: [quota-network-policy-test.md](../quota-network-policy-test.md) sezioni 4–6.
