# 🛠️ Troubleshooting Lab: ResourceQuota, LimitRange e NetworkPolicy (Kubernetes 1.33)

Questa guida riproduce un laboratorio di troubleshooting realistico in cui:

- I **Pod** restano in `Pending` o vengono **rifiutati dall'admission** per vincoli di quota/limiti
- Il traffico tra **frontend** e **backend** non passa per **NetworkPolicy** errate
- La risoluzione DNS dal frontend può fallire per **egress** troppo restrittivo
- ⚠️ **Vincolo fondamentale**: **NON** è consentito modificare gli YAML di **Deployment** e **Service** — solo **ResourceQuota**, **LimitRange**, **NetworkPolicy** e **label del Namespace**

**Scenario:**

- **Kubernetes**: 1.33.0 (Minikube)
- **Namespace**: `policy-lab`
- **Applicazione**: `web` (client HTTP) → `api` (backend nginx)
- **Tempo stimato**: 30–45 minuti

---

## 1. Prerequisiti

### Variabili d'ambiente

```bash
export LAB_DIR="$HOME/course/quota-network-lab"
mkdir -p "$LAB_DIR"
```

### Tool necessari

- `kubectl`, `minikube`, `jq`, `curl`

### 1.1 Minikube — Kubernetes 1.33

```bash
MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-cnpe}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-10000}
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-docker}

minikube start -p "$MINIKUBE_PROFILE" \
  --driver="$MINIKUBE_DRIVER" \
  --cpus="$MINIKUBE_CPUS" \
  --memory="${MINIKUBE_MEMORY}mb" \
  --disk-size=40g \
  --kubernetes-version=v1.33.0 \
  --extra-config=kubelet.fail-swap-on=false \
  --extra-config=kubeadm.ignore-preflight-errors=SystemVerification,Swap,NumCPU,Mem,ContainerRuntime \
  --force

export KUBECONFIG=$(minikube kubeconfig --no-env -p "$MINIKUBE_PROFILE" 2>/dev/null || echo ~/.kube/config)

minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server
```

Verifica:

```bash
kubectl version --short
minikube -p "$MINIKUBE_PROFILE" status
```

> Su Minikube, il CNI di default supporta **NetworkPolicy**. Se usi un profilo custom, verifica che il plugin (Calico, Cilium, ecc.) le applichi.

---

## 2. Setup dello Scenario "Broken"

Applichiamo i manifest che riproducono il cluster rotto. **Deployment e Service NON vanno modificati** durante l'esercizio.

🔗 **Riferimento concettuale**:

- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

### 2.1 Namespace (senza label utili alle policy)

```bash
kubectl create namespace policy-lab
```

### 2.2 Manifest "rotti" da applicare

```bash
cat > "$LAB_DIR/broken-quota-network.yaml" <<'YAML'
---
# ============================================================
# RESOURCE QUOTA (SBAGLIATA: CPU totale insufficiente)
# I Deployment richiedono 100m CPU ciascuno → servono almeno 200m
# ============================================================
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: policy-lab
spec:
  hard:
    pods: "10"
    requests.cpu: "150m"
    requests.memory: "512Mi"
    limits.cpu: "500m"
    limits.memory: "1Gi"

---
# ============================================================
# LIMIT RANGE (SBAGLIATA: max per container troppo basso)
# I container del Deployment richiedono 100m CPU e 128Mi RAM
# ============================================================
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: policy-lab
spec:
  limits:
    - type: Container
      max:
        cpu: "50m"
        memory: "64Mi"
      min:
        cpu: "10m"
        memory: "16Mi"

---
# ============================================================
# NETWORK POLICY — deny implicito + ingress API errato
# ============================================================
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: policy-lab
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    # SBAGLIATO: il frontend ha label app=web, non role=frontend
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 8080

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    # SBAGLIATO: manca egress verso kube-dns; label api errata
    - to:
        - podSelector:
            matchLabels:
              app: api-backend
      ports:
        - protocol: TCP
          port: 8080

---
# ============================================================
# SERVICE API (NON MODIFICABILE)
# ============================================================
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: policy-lab
spec:
  selector:
    app: api
  ports:
    - port: 8080
      targetPort: 8080

---
# ============================================================
# DEPLOYMENT API (NON MODIFICABILE)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: policy-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          command: ["/bin/sh", "-c"]
          args:
            - |
              cat > /etc/nginx/conf.d/default.conf <<'EOF'
              server {
                listen 8080;
                location / {
                  default_type text/plain;
                  return 200 "API OK\n";
                }
              }
              EOF
              nginx -g 'daemon off;'

---
# ============================================================
# SERVICE WEB (NON MODIFICABILE)
# ============================================================
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: policy-lab
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080

---
# ============================================================
# DEPLOYMENT WEB (NON MODIFICABILE)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: policy-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: curlimages/curl:8.11.1
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          command: ["/bin/sh", "-c"]
          args:
            - |
              apk add --no-cache socat > /dev/null 2>&1 || true
              while true; do
                RESP=$(curl -sf --max-time 3 http://api.policy-lab.svc.cluster.local:8080/ 2>&1 || echo "CURL_FAIL")
                BODY="Web CNPE — API response: ${RESP}"
                printf 'HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n%s' "$BODY" | socat -T 1 TCP-LISTEN:8080,reuseaddr,fork
              done
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - curl -sf --max-time 2 http://api.policy-lab.svc.cluster.local:8080/ | grep -q "API OK"
            initialDelaySeconds: 15
            periodSeconds: 10
YAML

kubectl apply -f "$LAB_DIR/broken-quota-network.yaml"
```

---

## 3. Fase 1 — Analisi: capire cosa non va

🔗 **Riferimento**:

- [Configure Quotas](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

### 3.1 Stato dei Pod e eventi

```bash
kubectl -n policy-lab get pods,resourcequota,limitrange,networkpolicy
kubectl -n policy-lab get events --sort-by='.lastTimestamp' | tail -20
```

**Output atteso (situazione rotta):**

```
NAME                        READY   STATUS    RESTARTS   AGE
pod/api-xxxx                0/1     Pending   0          1m
pod/web-yyyy                0/1     Running   0          1m   # o CrashLoop/Not Ready

NAME                         REQUEST                                        LIMIT
resourcequota/compute-quota   requests.cpu: 0/150m, requests.memory: 0/512Mi ...

NAME                         CREATED AT
limitrange/default-limits    ...
```

### 3.2 Perché i Pod sono Pending / rifiutati?

```bash
kubectl -n policy-lab describe pod -l app=api
kubectl -n policy-lab describe pod -l app=web
```

Cerca messaggi del tipo:

```
FailedScheduling ... insufficient cpu
```

oppure in **Events** del ReplicaSet/Deployment:

```
Error creating: pods "api-..." is forbidden: maximum cpu usage per Container is 50m, but limit is 200m
```

🎯 **Diagnosi 1**: la **LimitRange** impone `max.cpu: 50m` e `max.memory: 64Mi`, ma i Deployment (non modificabili) richiedono **100m / 128Mi** → admission rifiuta i Pod.

🎯 **Diagnosi 2**: anche con LimitRange corretta, la **ResourceQuota** consente solo **150m** di `requests.cpu` totali; due Pod da 100m ciascuno ne richiedono **200m** → almeno un Pod resta **Pending**.

### 3.3 Perché il frontend non diventa Ready?

```bash
kubectl -n policy-lab logs deployment/web --tail=30
kubectl -n policy-lab describe pod -l app=web
```

La readiness probe esegue `curl` verso `api.policy-lab.svc.cluster.local:8080`. Fallisce se:

1. Il Pod `api` non è in esecuzione (quota/limit range)
2. Le **NetworkPolicy** bloccano traffico o DNS

🎯 **Diagnosi 3**: `api-ingress` ammette solo Pod con `role: frontend`, ma il client ha `app: web`.

🎯 **Diagnosi 4**: `web-egress` non consente traffico verso **kube-dns** (UDP/TCP 53) né verso Pod con label `app: api` (c'è `app: api-backend`).

### 3.4 Isolare il problema di rete (dopo quota/limiti OK)

Quando entrambi i Pod sono `Running`, testa dal Pod web:

```bash
kubectl -n policy-lab exec deploy/web -- nslookup api.policy-lab.svc.cluster.local
kubectl -n policy-lab exec deploy/web -- curl -v --max-time 3 http://api.policy-lab.svc.cluster.local:8080/
```

- **DNS timeout** → egress verso `kube-system` / CoreDNS non permesso
- **Connection timed out** verso l'API → ingress/egress policy errate

🔗 **Riferimento DNS in cluster**: [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

## 4. Fase 2 — Fix #1: correggere la LimitRange

🔗 **Riferimento**:

- [Constraints per Container](https://kubernetes.io/docs/concepts/policy/limit-range/#constraint-per-container)
- [Enforce LimitRange](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/)

Allinea i massimi ai request/limit dei Deployment (non modificabili):

```bash
cat > "$LAB_DIR/fix-limitrange.yaml" <<'YAML'
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
      min:
        cpu: "10m"
        memory: "16Mi"
YAML

kubectl apply -f "$LAB_DIR/fix-limitrange.yaml"
```

Verifica che i ReplicaSet possano creare Pod (eventuali Pod falliti vanno ricreati):

```bash
kubectl -n policy-lab rollout restart deployment/api deployment/web
kubectl -n policy-lab get pods -w
```

---

## 5. Fase 3 — Fix #2: correggere la ResourceQuota

🔗 **Riferimento**:

- [Quota e richieste CPU](https://kubernetes.io/docs/concepts/policy/resource-quotas/#resource-quota-for-cpu-and-memory)
- [Viewing and Setting Quotas](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/#viewing-and-setting-quotas)

Aumenta la CPU richiesta disponibile per due container da 100m:

```bash
cat > "$LAB_DIR/fix-resourcequota.yaml" <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: policy-lab
spec:
  hard:
    pods: "10"
    requests.cpu: "300m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
YAML

kubectl apply -f "$LAB_DIR/fix-resourcequota.yaml"
```

Verifica utilizzo quota:

```bash
kubectl -n policy-lab describe resourcequota compute-quota
kubectl -n policy-lab get pods
```

**Output atteso:** entrambi i Pod `api` e `web` in stato `Running` (il web può ancora non essere `Ready` per le NetworkPolicy).

---

## 6. Fase 4 — Fix #3: correggere le NetworkPolicy

🔗 **Riferimento**:

- [NetworkPolicy ingress rules](https://kubernetes.io/docs/concepts/services-networking/network-policies/#ingress)
- [NetworkPolicy egress rules](https://kubernetes.io/docs/concepts/services-networking/network-policies/#egress)
- [Default deny all ingress and all egress](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress)

Mantieni `default-deny-all` (buona pratica zero-trust) e aggiungi regole **minime** corrette.

### 6.1 Ingress verso l'API dal frontend

```bash
cat > "$LAB_DIR/fix-networkpolicy-api.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: web
      ports:
        - protocol: TCP
          port: 8080
YAML

kubectl apply -f "$LAB_DIR/fix-networkpolicy-api.yaml"
```

### 6.2 Egress dal frontend verso API e DNS

```bash
cat > "$LAB_DIR/fix-networkpolicy-web.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: policy-lab
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    # DNS (CoreDNS in kube-system su Minikube)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # Traffico verso l'API
    - to:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 8080
YAML

kubectl apply -f "$LAB_DIR/fix-networkpolicy-web.yaml"
```

> **Nota esame**: se il cluster usa un namespace DNS diverso o IP del servizio `kube-dns` senza label, in lab puoi usare `ipBlock` verso il ClusterIP di CoreDNS (`kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'`). In produzione preferisci `namespaceSelector` + porte 53 come sopra.

Riavvia il rollout del web per far ripetere la readiness probe:

```bash
kubectl -n policy-lab rollout restart deployment/web
kubectl -n policy-lab wait --for=condition=Ready pod -l app=web --timeout=120s
```

---

## 7. Verifica Finale End-to-End

🔗 **Riferimento**: [Test connectivity — debug service](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/#test-endpoints)

### 7.1 Stato completo

```bash
kubectl -n policy-lab get all,resourcequota,limitrange,networkpolicy
```

Tutto deve essere `Running` / `Ready`; la quota deve mostrare utilizzo coerente (es. `requests.cpu: 200m/300m`).

### 7.2 Test dal Pod web verso l'API

```bash
kubectl -n policy-lab exec deploy/web -- curl -sf http://api.policy-lab.svc.cluster.local:8080/
```

**Output atteso:**

```
API OK
```

### 7.3 Test HTTP verso il frontend (NodePort / port-forward)

```bash
kubectl -n policy-lab port-forward svc/web 8080:80 &
PF_PID=$!
sleep 3
curl -s http://localhost:8080/ | grep -E "API OK|CURL_FAIL"
kill $PF_PID 2>/dev/null
```

**Output atteso:** riga contenente `API OK` (nessun `CURL_FAIL`).

### 7.4 Verifica che le policy siano effettivamente applicate

```bash
# Blocco controllo: senza policy api-ingress corretta, curl dal web fallirebbe
kubectl -n policy-lab describe networkpolicy api-ingress web-egress
```

---

## 8. Riepilogo delle Azioni Eseguite

| # | Problema | Diagnosi | Fix (senza toccare Deploy/Service) |
|---|----------|----------|-------------------------------------|
| 1 | Pod non creati / Forbidden | LimitRange `max` troppo basso rispetto a requests dei container | Aumentati `max.cpu` e `max.memory` nella LimitRange |
| 2 | Pod `Pending` per CPU | ResourceQuota `requests.cpu: 150m` insufficiente per 2×100m | Portata quota a `300m` (o superiore) |
| 3 | Readiness `web` fallita, curl timeout | Ingress API solo da `role: frontend` | Ingress da Pod con `app: web` sulla porta 8080 |
| 4 | DNS / curl verso API falliscono | Egress web senza DNS e con label `api-backend` errata | Egress verso `kube-system:53` e Pod `app: api:8080` |

---

## 9. Cleanup

```bash
kubectl delete namespace policy-lab
rm -rf "$LAB_DIR"
```

---

## 📚 Riepilogo Documentazione Ufficiale Utilizzata

| Argomento | Link |
|-----------|------|
| Resource Quotas (concetti) | https://kubernetes.io/docs/concepts/policy/resource-quotas/ |
| Quota CPU e memoria | https://kubernetes.io/docs/concepts/policy/resource-quotas/#resource-quota-for-cpu-and-memory |
| Gestire quota in namespace | https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/ |
| Limit Range (concetti) | https://kubernetes.io/docs/concepts/policy/limit-range/ |
| Vincoli per Container | https://kubernetes.io/docs/concepts/policy/limit-range/#constraint-per-container |
| Default CPU in namespace | https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/ |
| Network Policies (concetti) | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |
| Ingress / Egress rules | https://kubernetes.io/docs/concepts/services-networking/network-policies/#ingress |
| Default deny all | https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress |
| Dichiarare NetworkPolicy | https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/ |
| DNS Pod e Service | https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ |
| Debug Service | https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/ |

---

## 🔗 Confronto con il lab Storage

| Lab | Focus principale | Risorse modificabili |
|-----|------------------|----------------------|
| [storage-test.md](../storage/storage-test.md) | PVC, StorageClass, ConfigMap | ConfigMap, StorageClass |
| **questo file** | Quota, LimitRange, NetworkPolicy | ResourceQuota, LimitRange, NetworkPolicy |

---

## Batteria esame (20 domande — scenario difficile)

| File | Descrizione |
|------|-------------|
| [questions/setup-lab.sh](questions/setup-lab.sh) | Deploy automatico Minikube + scenario `policy-lab` (LimitRange ratio, quota CPU/mem/limit, 4 NetworkPolicy) |
| [questions/domande.md](questions/domande.md) | 20 domande stile esame Killer Shell (senza risposte) |
| [questions/risposte.md](questions/risposte.md) | 20 risposte con comandi di fix |

```bash
chmod +x questions/setup-lab.sh && ./questions/setup-lab.sh
# Cleanup: ./questions/setup-lab.sh --cleanup
```

**Laboratorio pronto all'uso!** 🎯
