# CNPE Hard Lab — StorageClass / PV / PVC Troubleshooting

Scenario: `storage-hard`  
Namespace: `storage-hard`  
Directory: `/course/storage-hard`  
Tempo consigliato: 60–75 minuti.

Vincolo fondamentale:

**Non modificare lo YAML del Deployment `webapp` e dello StatefulSet `db`.**  
Puoi modificare o creare: `StorageClass`, `PV`, `PVC`, `Service`, `ConfigMap`, eventuali Secret/Job di debug.

Obiettivo finale:

- `db-0` Running;
- PVC del DB Bound;
- `webapp` Running;
- app configurata per puntare al DB corretto;
- `cache-check` Running con PVC Bound;
- report finali salvati.

---

## Q1 — Stato iniziale

Raccogli stato iniziale:

```bash
kubectl -n storage-hard get pod,deploy,sts,svc,pvc -o wide
kubectl get pv,sc
kubectl -n storage-hard describe pod db-0
kubectl -n storage-hard describe pod -l app=webapp
```

Salva tutto in:

```bash
/course/storage-hard/q1-initial-status.txt
```

---

## Q2 — PVC del database

Il Pod `db-0` non sale correttamente.

Indaga:

- PVC generata dal `volumeClaimTemplate`;
- PV disponibile;
- StorageClass richiesta;
- eventi del Pod;
- nodeAffinity del PV.

Salva diagnosi in:

```bash
/course/storage-hard/q2-db-pvc-diagnosis.txt
```

---

## Q3 — StorageClass mancante/errata

Lo StatefulSet richiede `storageClassName: fast-local`, ma la situazione iniziale non è coerente.

Senza modificare lo StatefulSet:

1. crea o correggi la StorageClass `fast-local`;
2. assicurati che il PVC del DB possa bindare al PV giusto;
3. usa `WaitForFirstConsumer` se serve per local PV.

Salva:

```bash
kubectl get sc fast-local -o yaml > /course/storage-hard/q3-fast-local-sc.yaml
```

---

## Q4 — PV local nodeAffinity

Il PV `db-local-pv` ha nodeAffinity sbagliata.

Correggi il problema senza modificare lo StatefulSet.

Suggerimento: i campi di nodeAffinity del PV possono essere scomodi da patchare; in esame puoi dover ricreare PV se non è ancora in uso.

Salva:

```bash
kubectl get pv db-local-pv -o yaml > /course/storage-hard/q4-db-pv.yaml
```

---

## Q5 — DB ConfigMap PGDATA

Il container Postgres legge `PGDATA` dalla ConfigMap `db-config`, ma il valore non è coerente con il mount path.

Correggi solo la ConfigMap.

Valore atteso:

```text
/var/lib/postgresql/data/pgdata
```

Riavvia solo quanto necessario senza modificare lo YAML dello StatefulSet.

Salva:

```bash
kubectl -n storage-hard get cm db-config -o yaml > /course/storage-hard/q5-db-config.yaml
```

---

## Q6 — Headless Service StatefulSet

Lo StatefulSet ha:

```yaml
serviceName: db
```

ma il Service creato non ha quel nome.

Senza modificare lo StatefulSet:

1. crea il Service headless corretto `db`;
2. selector corretto verso `app=db`;
3. porta `5432`.

Salva:

```bash
kubectl -n storage-hard get svc db -o yaml > /course/storage-hard/q6-db-service.yaml
```

---

## Q7 — Verifica DB

Porta `db-0` a `Running`.

Verifica:

```bash
kubectl -n storage-hard get pod db-0
kubectl -n storage-hard logs db-0 --tail=30
kubectl -n storage-hard get pvc
```

Salva in:

```bash
/course/storage-hard/q7-db-running.txt
```

---

## Q8 — ConfigMap app DB endpoint

`webapp` non deve essere modificato, ma legge `DB_HOST` e `DB_PORT` da `app-config`.

Correggi `app-config` in modo che punti al DB reale.

Valori attesi:

```text
DB_HOST=db.storage-hard.svc.cluster.local
DB_PORT=5432
```

Salva:

```bash
kubectl -n storage-hard get cm app-config -o yaml > /course/storage-hard/q8-app-config.yaml
```

---

## Q9 — Riavvio controllato webapp

Dopo la correzione della ConfigMap, il Pod `webapp` può non ricaricare automaticamente le env.

Senza modificare il Deployment YAML:

1. forza un rollout restart o elimina il Pod;
2. verifica che initContainer `wait-db` termini con successo;
3. verifica Pod Running.

Salva:

```bash
/course/storage-hard/q9-webapp-running.txt
```

---

## Q10 — PVC cache Pending

Il Pod `cache-check` è bloccato perché `cache-pvc` non riesce a bindare.

Indaga:

- StorageClass richiesta dal PVC;
- StorageClass del PV `cache-local-pv`;
- accessModes;
- size;
- eventi PVC.

Salva diagnosi in:

```bash
/course/storage-hard/q10-cache-diagnosis.txt
```

---

## Q11 — Fix cache PVC/PV

Risolvi `cache-pvc` senza modificare il Pod `cache-check`.

Puoi scegliere una di queste strade:

- correggere/ricreare PVC;
- correggere/ricreare PV;
- creare StorageClass coerente.

Requisiti:

- PVC `cache-pvc` Bound;
- Pod `cache-check` Running;
- file `/cache/ok` presente nel container.

Salva:

```bash
/course/storage-hard/q11-cache-fixed.txt
```

---

## Q12 — Test DNS e connessione DB

Esegui un Pod temporaneo di debug oppure usa `webapp` se disponibile.

Verifica:

```bash
nslookup db.storage-hard.svc.cluster.local
nc -z db.storage-hard.svc.cluster.local 5432
```

Salva:

```bash
/course/storage-hard/q12-dns-db-test.txt
```

---

## Q13 — StorageClass default

Verifica se nel cluster esiste una StorageClass default.

Documenta:

- nome;
- provisioner;
- se è default;
- perché in questo scenario il PVC DB usa una classe specifica.

Salva:

```bash
/course/storage-hard/q13-default-sc.txt
```

---

## Q14 — Reclaim policy

Mostra e spiega le reclaim policy di:

- `db-local-pv`;
- `cache-local-pv`.

Non modificare se non necessario.

Salva:

```bash
/course/storage-hard/q14-reclaim-policy.txt
```

---

## Q15 — Report finale

Crea:

```bash
/course/storage-hard/final-report.txt
```

Deve contenere:

1. stato finale Pod/Deployment/StatefulSet;
2. stato finale PVC/PV;
3. StorageClass usate;
4. endpoint DB corretto;
5. conferma che Deployment `webapp` e StatefulSet `db` non sono stati modificati come YAML applicativo;
6. breve spiegazione di:
   - StorageClass;
   - PV;
   - PVC;
   - local PV;
   - nodeAffinity;
   - headless Service per StatefulSet;
   - ConfigMap come punto di configurazione app/db.

---

# Comandi utili

```bash
kubectl -n storage-hard get pod,deploy,sts,svc,pvc -o wide
kubectl get pv,sc
kubectl -n storage-hard describe pvc <name>
kubectl describe pv <name>
kubectl -n storage-hard describe pod db-0
kubectl -n storage-hard logs db-0

kubectl -n storage-hard get cm app-config -o yaml
kubectl -n storage-hard get cm db-config -o yaml

kubectl -n storage-hard rollout restart deploy/webapp
kubectl -n storage-hard delete pod db-0
```
