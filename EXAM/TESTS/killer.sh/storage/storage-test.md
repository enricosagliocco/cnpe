# 🛠️ Troubleshooting Lab: Pod Broken, ConfigMap e PVC Pending (Kubernetes 1.33)

Questa guida riproduce un laboratorio di troubleshooting realistico in cui:

- Un **Deployment** (applicazione web) e uno **StatefulSet** (database PostgreSQL) non partono
- Il **PVC del database** rimane in stato `Pending`
- Le **ConfigMap** dell'app e del DB contengono errori da correggere
- ⚠️ **Vincolo fondamentale**: **NON** è consentito modificare gli YAML di Deployment e StatefulSet — solo ConfigMap, PVC/StorageClass e risorse correlate

**Scenario:**
- **Kubernetes**: 1.33.0 (Minikube)
- **Namespace**: `broken-app`
- **Applicazione**: `webapp` (nginx + php con connessione al DB)
- **Database**: PostgreSQL 16 (StatefulSet)
- **Tempo stimato**: 30-45 minuti

---

## 1. Prerequisiti

### Variabili d'ambiente

```bash
export LAB_DIR="$HOME/course/troubleshooting-lab"
mkdir -p "$LAB_DIR"
```

### Tool necessari
- `kubectl`, `minikube`, `helm`, `jq`

### 1.1 Minikube - Kubernetes 1.33

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

---

## 2. Setup dello Scenario "Broken"

Applichiamo i manifest che riproducono il cluster rotto. **Questi sono i manifest che NON dovrai modificare** durante l'esercizio.

🔗 **Riferimento concettuale**: [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/) | [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

### 2.1 Namespace

```bash
kubectl create namespace broken-app
```

### 2.2 Manifest "rotti" da applicare

```bash
cat > "$LAB_DIR/broken-scenario.yaml" <<'YAML'
---
# ============================================================
# CONFIGMAP DATABASE (SBAGLIATA: nome volume incoerente)
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: broken-app
data:
  POSTGRES_DB: appdb
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: supersecret
  # Il mount path è sbagliato: PostgreSQL si aspetta /var/lib/postgresql/data
  # ma qui è configurato un path non standard
  PGDATA: "/var/lib/postgresql/wrong-path/data"

---
# ============================================================
# CONFIGMAP APPLICAZIONE (SBAGLIATA: host DB errato)
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: broken-app
data:
  # Host del DB sbagliato: il servizio si chiama "db" non "postgres-svc"
  DATABASE_HOST: "postgres-svc"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "appdb"
  DATABASE_USER: "appuser"
  DATABASE_PASSWORD: "supersecret"

---
# ============================================================
# SERVICE DATABASE
# ============================================================
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: broken-app
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432

---
# ============================================================
# STATEFULSET DATABASE (NON MODIFICABILE)
# ============================================================
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: broken-app
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          envFrom:
            - configMapRef:
                name: postgres-config
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
              subPath: pgdata
  # PVC con storageClassName "fast-ssd" che NON ESISTE sul cluster
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: "fast-ssd"
        resources:
          requests:
            storage: 1Gi

---
# ============================================================
# SERVICE APPLICAZIONE
# ============================================================
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: broken-app
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
    - port: 80
      targetPort: 80

---
# ============================================================
# DEPLOYMENT APPLICAZIONE (NON MODIFICABILE)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: broken-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: php:8.2-apache
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: webapp-config
          # Script di startup che verifica la connessione al DB
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "<?php" > /var/www/html/index.php
              echo "\$host = getenv('DATABASE_HOST');" >> /var/www/html/index.php
              echo "\$port = getenv('DATABASE_PORT');" >> /var/www/html/index.php
              echo "\$db   = getenv('DATABASE_NAME');" >> /var/www/html/index.php
              echo "\$user = getenv('DATABASE_USER');" >> /var/www/html/index.php
              echo "\$pass = getenv('DATABASE_PASSWORD');" >> /var/www/html/index.php
              echo "echo '<h1>WebApp CNPE</h1>';" >> /var/www/html/index.php
              echo "\$conn = @pg_connect(\"host=\$host port=\$port dbname=\$db user=\$user password=\$pass\");" >> /var/www/html/index.php
              echo "if (\$conn) { echo '<p style=\"color:green\">✅ DB OK: connected to ' . \$host . '</p>'; }" >> /var/www/html/index.php
              echo "else { echo '<p style=\"color:red\">❌ DB KO: cannot reach ' . \$host . '</p>'; }" >> /var/www/html/index.php
              echo "phpinfo();" >> /var/www/html/index.php
              echo "Installing postgres extension..."
              apt-get update -qq && apt-get install -y -qq libpq-dev > /dev/null
              docker-php-ext-install pdo_pgsql pgsql > /dev/null 2>&1
              echo "Starting Apache..."
              apache2-foreground
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 30
            periodSeconds: 10
YAML

kubectl apply -f "$LAB_DIR/broken-scenario.yaml"
```

---

## 3. Fase 1 — Analisi: capire cosa non va

🔗 **Riferimento**: [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) | [Debug CrashLoopBackOff](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/#debugging-crashloopbackoff)

### 3.1 Stato dei Pod

```bash
kubectl -n broken-app get pods,pvc
```

**Output atteso (situazione rotta):**
```
NAME                          READY   STATUS              RESTARTS   AGE
pod/db-0                      0/1     ContainerCreating   0          2m
pod/webapp-xxxx-yyyy          0/1     Running             3          2m

NAME                                         STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/postgres-data-db-0     Pending                                      fast-ssd       2m
```

### 3.2 Perché il PVC è in Pending?

```bash
kubectl -n broken-app describe pvc postgres-data-db-0
```

**Output chiave:**
```
Events:
  Type     Reason              Message
  ----     ------              -------
  Warning  ProvisioningFailed  storageclass.storage.k8s.io "fast-ssd" not found
```

🎯 **Diagnosi 1**: la `StorageClass` `fast-ssd` non esiste.

### 3.3 Perché il Pod `webapp` è in CrashLoop / Readiness fallita?

```bash
kubectl -n broken-app logs deployment/webapp --tail=30
kubectl -n broken-app describe pod -l app=webapp
```

🎯 **Diagnosi 2**: l'app non riesce a connettersi al DB perché `DATABASE_HOST=postgres-svc` è errato (il servizio si chiama `db`).

### 3.4 Perché il Pod `db-0` non parte anche dopo aver sbloccato il PVC?

Anche creando la StorageClass, il database non partirà correttamente perché il `PGDATA` nella ConfigMap punta a `/var/lib/postgresql/wrong-path/data`, mentre il `volumeMount` dello StatefulSet monta il volume su `/var/lib/postgresql/data`. PostgreSQL inizializzerà i dati nel path sbagliato e fallirà all'avvio.

🎯 **Diagnosi 3**: `PGDATA` nella ConfigMap `postgres-config` è incoerente con il mount path.

---

## 4. Fase 2 — Fix #1: sbloccare il PVC creando la StorageClass

🔗 **Riferimento**: [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

Poiché non possiamo modificare lo StatefulSet, dobbiamo creare la StorageClass `fast-ssd` richiesta dal PVC.

```bash
cat > "$LAB_DIR/fix-storageclass.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
YAML

kubectl apply -f "$LAB_DIR/fix-storageclass.yaml"
```

Verifica:
```bash
kubectl get storageclass
kubectl -n broken-app get pvc
```

**Output atteso:**
```
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-data-db-0   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            fast-ssd       3m
```

⚠️ **Nota**: se il PVC rimane in `Pending` anche dopo aver creato la StorageClass, è perché lo StatefulSet ha già tentato il binding. In tal caso:
```bash
kubectl -n broken-app delete pod db-0
# Lo StatefulSet ricreerà il pod e il PVC si legherà alla nuova StorageClass
```

---

## 5. Fase 3 — Fix #2: correggere la ConfigMap del database

🔗 **Riferimento**: [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)

Il mount path del volume è `/var/lib/postgresql/data` (fisso nello StatefulSet). Dobbiamo allineare `PGDATA` di conseguenza.

```bash
cat > "$LAB_DIR/fix-postgres-configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: broken-app
data:
  POSTGRES_DB: appdb
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: supersecret
  # Corretto: allineato al mountPath /var/lib/postgresql/data dello StatefulSet
  PGDATA: "/var/lib/postgresql/data/pgdata"
YAML

kubectl apply -f "$LAB_DIR/fix-postgres-configmap.yaml"
```

⚠️ **Attenzione**: le ConfigMap montate via `envFrom` non vengono ricaricate automaticamente dai pod esistenti. È necessario ricreare il pod:

```bash
kubectl -n broken-app delete pod db-0
# Lo StatefulSet lo ricrea con la nuova ConfigMap
```

Verifica che il DB sia `Running` e `Ready`:
```bash
kubectl -n broken-app get pods -l app=postgres -w
kubectl -n broken-app logs db-0 --tail=20
```

**Output atteso (ultime righe):**
```
... database system is ready to accept connections
```

---

## 6. Fase 4 — Fix #3: correggere la ConfigMap dell'applicazione

🔗 **Riferimento**: [Expose a StatefulSet with a Headless Service](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#creating-a-headless-service)

Il servizio del DB si chiama `db` (non `postgres-svc`). Correggiamo la ConfigMap:

```bash
cat > "$LAB_DIR/fix-webapp-configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: broken-app
data:
  # Corretto: il Service del DB si chiama "db"
  DATABASE_HOST: "db"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "appdb"
  DATABASE_USER: "appuser"
  DATABASE_PASSWORD: "supersecret"
YAML

kubectl apply -f "$LAB_DIR/fix-webapp-configmap.yaml"
```

Ricreiamo il pod dell'app per forzare il reload delle variabili d'ambiente:

```bash
kubectl -n broken-app rollout restart deployment/webapp
```

Verifica:
```bash
kubectl -n broken-app get pods -w
```

**Output atteso:**
```
NAME                      READY   STATUS    RESTARTS   AGE
db-0                      1/1     Running   0          10m
webapp-xxxx-yyyy          1/1     Running   0          30s
```

---

## 7. Verifica Finale End-to-End

🔗 **Riferimento**: [Access Clusters Using the Kubernetes API](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/)

### 7.1 Stato completo

```bash
kubectl -n broken-app get all,pvc,storageclass
```

Tutto deve essere `Running` / `Bound` / presente.

### 7.2 Test di connessione dall'app al DB

```bash
# Port-forward verso l'app
kubectl -n broken-app port-forward svc/webapp 8080:80 &
PF_PID=$!
sleep 5

# Test HTTP
curl -s http://localhost:8080 | grep -E "DB OK|DB KO"

# Chiusura port-forward
kill $PF_PID 2>/dev/null
```

**Output atteso:**
```
✅ DB OK: connected to db
```

### 7.3 Test diretto dentro il pod DB

```bash
kubectl -n broken-app exec -it db-0 -- psql -U appuser -d appdb -c "SELECT version();"
```

**Output atteso:**
```
                                                 version
---------------------------------------------------------------------------------------------------------
 PostgreSQL 16.x on x86_64-pc-linux-musl, compiled by gcc (Alpine 13.x) 13.x, 64-bit
```

### 7.4 Verifica persistenza dei dati

```bash
# Creo una tabella e inserisco un record
kubectl -n broken-app exec -it db-0 -- psql -U appuser -d appdb -c \
  "CREATE TABLE IF NOT EXISTS test(id serial PRIMARY KEY, msg text); INSERT INTO test(msg) VALUES ('hello cnpe');"

# Elimino il pod (lo StatefulSet lo ricrea)
kubectl -n broken-app delete pod db-0
kubectl -n broken-app wait --for=condition=Ready pod/db-0 --timeout=120s

# Verifico che il dato persista (grazie al PVC ora correttamente bound)
kubectl -n broken-app exec -it db-0 -- psql -U appuser -d appdb -c "SELECT * FROM test;"
```

**Output atteso:**
```
 id |    msg
----+------------
  1 | hello cnpe
```

---

## 8. Riepilogo delle Azioni Eseguite

| # | Problema | Diagnosi | Fix (senza toccare Deploy/Sts) |
|---|----------|----------|--------------------------------|
| 1 | PVC `postgres-data-db-0` in `Pending` | `StorageClass fast-ssd` inesistente | Creata `StorageClass fast-ssd` con provisioner `minikube-hostpath` |
| 2 | Pod `db-0` non diventa Ready | `PGDATA` in ConfigMap puntava a `/var/lib/postgresql/wrong-path/data` | Corretto in `/var/lib/postgresql/data/pgdata` e restart del pod |
| 3 | Pod `webapp` in CrashLoop/Readiness KO | `DATABASE_HOST=postgres-svc` errato | Corretto in `DATABASE_HOST=db` e rollout restart |

---

## 9. Cleanup

```bash
kubectl delete namespace broken-app
kubectl delete storageclass fast-ssd
rm -rf "$LAB_DIR"
```

---

## 📚 Riepilogo Documentazione Ufficiale Utilizzata

| Argomento | Link |
|-----------|------|
| ConfigMap | https://kubernetes.io/docs/concepts/configuration/configmap/ |
| Use a ConfigMap from a Pod | https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/ |
| Persistent Volumes | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |
| Storage Classes | https://kubernetes.io/docs/concepts/storage/storage-classes/ |
| StatefulSet Basics | https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/ |
| Debug Running Pods | https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/ |
| Debug CrashLoopBackOff | https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/ |

---

**Laboratorio pronto all'uso!** 🎯

Vuoi che nella prossima versione aggiunga:
- 🔐 Un **Secret** rotto (es. password DB in chiaro vs base64 errato) da fixare?
- 🌐 Un **Ingress** con annotation sbagliate da correggere?
- 🔍 Un caso di **NetworkPolicy** che blocca il traffico tra app e DB?
- 📊 L'integrazione con **Prometheus/Grafana** per monitorare il recupero?

Fammi sapere!