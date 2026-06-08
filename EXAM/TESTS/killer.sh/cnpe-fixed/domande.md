# Le 20 domande dell'esame — CNPE Full Lab (simulatore lab)

Scenario deployato da `setup-cnpe-lab.sh`. Manifest in `~/course/`.  
Lo script è diviso in 3 parti (part1, part2, part3) eseguite dall'entrypoint.

**Vincolo:** non disinstallare i tool installati (Prometheus, Argo CD, Flagger, Gatekeeper, OpenTofu, OpenCost, Grafana, Kustomize, Argo Workflows, Tekton, Jaeger, VPA, Argo Rollouts, FluxCD, Kyverno, Crossplane, Linkerd). Puoi modificare configurazioni e risorse applicative ma non i core dei tool.

---

### Q1 – Operator Pattern, CRD, Kustomize, Git
La CRD `TeamMonitoring` è installata nel cluster dal repository locale `/course/1/team-monitoring`, che contiene configurazione Kustomize.

1. Crea una nuova versione `v1alpha2` della CRD in cui la property `target` è un **oggetto** con due property string: `namespace` e `service`
2. Applica la CRD aggiornata al cluster usando Kustomize
3. Fai il commit della modifica su Git nel branch `main`
4. Crea una risorsa `TeamMonitoring` nel Namespace `pacific`, chiamata `general`. Il campo `target.namespace` deve essere `test-ns` e `target.service` deve essere `test-svc`

---

### Q2 – Prometheus Monitoring
Prometheus è installato nel Namespace `prometheus`, accessibile su `http://<node>:30020`. Attualmente vengono scrapati solo i Pod nel Namespace `kariba` con label `app=frontend` e `app=backend`.

Accesso GUI (port-forward):

```bash
kubectl -n prometheus port-forward --address 0.0.0.0 svc/prometheus-server 30020:9090
```

Credenziali:
- Prometheus normalmente non richiede credenziali in questo lab.
- Se richieste, verifica eventuale Ingress/Auth custom con:

```bash
kubectl -n prometheus get ingress,svc,secret
```

1. Estendi la configurazione di scrape `minimal` nel ConfigMap `prometheus-server` in modo che vengano scrapati anche i Pod con label `app=proxy`. Assicurati che Prometheus usi la configurazione aggiornata
2. Esegui una query per calcolare la somma di `http_requests_per_minute{}` per ogni Deployment. Identifica quello con la somma più alta e scalalo a 2 repliche

---

### Q3 – Argo CD
Argo CD è installato con UI su `http://<node>:30030`. L'applicazione `web-client` è connessa al repository Git clonato in `/course/3/web-client`.

Accesso GUI (port-forward):

```bash
kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 30030:443
```

Credenziali:
- User: `admin`
- Password come sotto:

```bash
# Genera l'hash della nuova password (sostituisci "nuovapassword" con la tua)
NEW_PASSWORD="admin"
BCRYPT=$(htpasswd -bnBC 10 "" "$NEW_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')

kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {\"admin.password\": \"$BCRYPT\", \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"}}"

# Riavvia il server
kubectl -n argocd rollout restart deployment argocd-server



kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

1. Fai commit, push e sync di queste modifiche:
   - La label `version` del Pod deve essere `v2`
   - Il contenuto restituito dal server Nginx deve essere `Lagoon Web Client v2`
2. In `/course/3/web-client` crea il branch Git `testing`:
   - La label `version` del Pod deve essere `v3`
   - Il contenuto deve essere `Lagoon Web Client v3`
   - Fai push della modifica
3. Crea una nuova applicazione Argo CD `web-client-testing` con le stesse impostazioni di `web-client` eccetto:
   - Branch Git sorgente: `testing`
   - Namespace K8s destinazione: `lagoon-testing`
4. Assicurati che la nuova applicazione venga applicata senza errori

---

### Q4 – Flagger Blue/Green Deployments
Flagger è usato per due app nel Namespace `malawi`. È configurato per Blue/Green senza service mesh.

**Per il Deployment `app1`:**
1. Aumenta di 1 il patch number della versione semantica nella variabile d'ambiente `APP_VERSION`
2. Scrivi gli eventi generati sulla risorsa `Canary` in `/course/4/app1.log`

**Per il Deployment `app2`**, modifica l'analisi del Canary:
1. Aggiungi un webhook `pre-rollout` di base che verifichi se i nuovi Pod rispondono via HTTP, usando il Service canary (usa il template fornito in exam)

Template esplicito:

```yaml
analysis:
  interval: 5s
  iterations: 2
  metrics: []
  webhooks:
    - name: "basic-http-test"
      type: pre-rollout
      url: http://TODO # DNS to canary service
      timeout: 5s
      metadata:
        type: "http"
        method: "GET"
        expectedStatus: "200"
```

2. Una volta fatto, avvia un nuovo rollout impostando `APP_VERSION` a `1.0.1`

---

### Q5 – OPA Gatekeeper + Helm
OPA Gatekeeper è installato. In `/course/5/infra-opa`:

1. Completa e crea il `ConstraintTemplate` con queste regole:
   - I Pod devono avere la label `planet` con qualsiasi valore
   - I Deployment devono definire almeno 2 repliche
   - Sostituisci i placeholder `TODO` nei messaggi di violazione con testo appropriato
2. Aggiorna la `PlanetAppConstraint` affinché si applichi solo al Namespace `planet-apps`, poi creala
3. Per il chart Helm in `/course/5/app-saturn`:
   - Aggiorna il manifest del Deployment per soddisfare i requisiti OPA **senza usare Helm values**
   - Imposta la versione del chart a `1.0.2`
   - Deploya il chart come `app-saturn` nel Namespace `planet-apps`

---

### Q6 – OpenTofu / Terraform
Il tuo team usa OpenTofu per gestire risorse Kubernetes.

1. Per `/course/6/service-black-bean`: genera un diff human-readable delle modifiche che verrebbero applicate e salvalo in `/course/6/service-black-bean/diff.txt`
2. Per `/course/6/service-green-curry`: aumenta le repliche del Deployment `green-curry` a 2 e applica la modifica
3. Aggiorna `/course/6/service-red-velvet/main.tf`:
   - Aggiungi un nuovo Service NodePort chiamato `cake`, `nodePort` 30060
   - Il nome della risorsa OpenTofu deve essere `cake`
   - Deve puntare al Deployment `red-velvet` esistente

---

### Q7 – OpenCost + Prometheus
OpenCost è installato con UI su `http://<node>:30070`. Prometheus è su `http://<node>:30077`.

Accesso GUI (port-forward):

```bash
kubectl -n opencost port-forward --address 0.0.0.0 svc/opencost-nodeport 30070:9090
kubectl -n prometheus port-forward --address 0.0.0.0 svc/prometheus-server 30077:9090
```

Credenziali:
- OpenCost e Prometheus in genere non richiedono credenziali in questo lab.
- Se richieste, controlla eventuali secret/ingress:

```bash
kubectl -n opencost get svc,ingress,secret
kubectl -n prometheus get svc,ingress,secret
```

1. Aggiorna il modello di prezzi custom di OpenCost nel Namespace `opencost`:
   - Imposta `internetNetworkEgress` a `0.25`
   - Imposta `spotCPU` a `0.015`
   - Assicurati che OpenCost usi i valori aggiornati
2. Esegui la query Prometheus `kube_pod_info{...}` filtrata per Namespace `atlantic` e scrivi il risultato in `/course/7/result.txt`
3. Trova i target Prometheus con errori di scraping e scrivi il messaggio di errore in `/course/7/error.txt`

---

### Q8 – Grafana, Loki, Logging
Grafana è accessibile su `http://<node>:30080`. Loki è configurato come unica datasource.

Accesso GUI (port-forward):

```bash
kubectl -n monitoring port-forward --address 0.0.0.0 svc/grafana 30080:80
```

Credenziali:
- In questo lab Grafana ha `adminPassword=admin` e auth anonima abilitata (puoi entrare anche senza login).
- Se vuoi recuperare user/password dai secret:

```bash
kubectl -n monitoring get secret | grep -i grafana
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

1. Imposta il "Maximum lines" per la datasource Loki a `100`
2. Nel dashboard di logging, aggiorna la query del pannello esistente con la seguente e salva il dashboard:
   ```
   count(rate({pod=~"connection.*"}[5m]))
   ```
3. Due Pod stanno producendo log di errore. Esegui la query Loki `{namespace="arctic-workload"} |= "ERROR"` per localizzarli, poi scala a 0 i rispettivi controller

---

### Q9 – Kustomize + Prometheus Operator CRDs
La configurazione in `/course/9/prom-config` ha un overlay staging e production. È stata applicata con:
```bash
kubectl apply -k /course/9/prom-config/overlays/staging
kubectl apply -k /course/9/prom-config/overlays/production
```

1. Il ConfigMap `operator-config` deve avere:
   - `reconcile_interval_seconds: "30"` in staging
   - `reconcile_interval_seconds: "10"` in production
2. Il PodMonitor `proxy-monitor` deve avere:
   - `attachMetadata: { node: true }` nella base (ereditato da entrambi)
   - `sampleLimit: 6000` in staging
   - `sampleLimit: 7000` in production
3. Aggiungi `crd-prometheusrules.yaml` alla configurazione base così da installarlo in tutti gli ambienti
4. Applica tutte le modifiche

---

### Q10 – ResourceQuota + Git
Limita l'uso dello storage nei Namespace `caspian-pipeline1`, `caspian-pipeline2` e `caspian-pipeline3` usando ResourceQuota.

1. Uno di questi Namespace ha richiesto recentemente 100Gi di storage, ma la modifica è stata revertita. Controlla i commit nel repository Git `/course/10/pipelines-repo` per identificarlo
2. Per il Namespace identificato (che aveva richiesto i 100Gi):
   - Impedisci la creazione di qualsiasi PVC
   - Elimina anche i PVC esistenti, scala down i Pod se necessario
3. Per gli altri due Namespace, limita ciascuno a:
   - Massimo 2 PVC creabili
   - Un totale di 100Mi storage richiesto su tutti i PVC

---

### Q11 – Argo Workflows
Argo Workflows è installato con UI su `http://<node>:30110`.

Accesso GUI (port-forward):

```bash
kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 30110:2746
```

Credenziali:
- Se l'istanza usa auth SSO/basic, verifica secret/config:

```bash
kubectl -n argo get secret,cm | grep -Ei 'argo|auth|server'
```
- In molte installazioni lab la UI è accessibile senza credenziali aggiuntive dal nodo.

1. Il Workflow esistente del WorkflowTemplate `greeter` è fallito. Correggi l'errore nel WorkflowTemplate e sottometti un nuovo Workflow che abbia successo
2. C'è un WorkflowTemplate `/course/11/configurator.yaml` che crea ConfigMap in un Namespace passato come parametro:
   - Crea lo step `create-config2` copiando `create-config1`, deve creare il ConfigMap `cm2`
   - Esegui il nuovo step **in parallelo** con quello esistente
   - Applica il WorkflowTemplate aggiornato
   - Sottometti un nuovo Workflow per il Namespace `kaw` che abbia successo
3. Elimina i Workflow falliti e mantieni solo uno di quelli riusciti per ogni WorkflowTemplate

---

### Q12 – Tekton
Tekton Pipelines è installato con Tekton Dashboard su `http://<node>:30120`. Tutti i Tekton Pipeline devono essere eseguiti nel Namespace `builder`.

Accesso GUI (port-forward):

```bash
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30120:9097
```

Credenziali:
- Tekton Dashboard in lab spesso non richiede login dedicato.
- Se richieste credenziali/token, verifica ServiceAccount/secret nel namespace:

```bash
kubectl -n tekton-pipelines get sa,secret
```

1. Aggiungi il nuovo Task `p1-create-labels` alla Pipeline `p1-team-onboarding`:
   - Deve aggiungere la label `auto-created: true` al Namespace creato in `p1-create-namespace`
   - Deve eseguirsi **in parallelo** con il Task `p1-create-roles`
2. Esegui la Pipeline aggiornata per il team `butter`
3. Esegui la Pipeline aggiornata per il team `croissant`
4. Applica tutte le risorse da `/course/12/p2-team-scanner`
5. Esegui la Pipeline `p2-team-scanner` con i parametri:
   - `team-name: bread`
   - `forbidden1: miner`
   - `forbidden2: torrent`
6. Scrivi i log del PipelineRun in `/course/12/p2.log`
7. Se una Pipeline fallisce, elimina il PipelineRun fallito per pulizia

---

### Q13 – Pod Security Standards
Il Namespace `ammersee-legacy` non ha Pod Security Standards applicati. I manifest dei workload esistenti sono in `/course/13`.

1. Configura il Namespace per applicare il Pod Security Standard `restricted` in modalità `enforce`
2. Identifica e correggi i workload non conformi in modo che possano essere riavviati

---

### Q14 – Jaeger
Jaeger è installato con UI su `http://<node>:30014`. Diversi servizi generano trace distribuiti.

Accesso GUI (port-forward):

```bash
kubectl -n eyre port-forward --address 0.0.0.0 svc/jaeger 30014:16686
```

Credenziali:
- Jaeger UI nel lab tipicamente non richiede credenziali.
- Se presenti policy/auth custom, verifica:

```bash
kubectl -n eyre get svc,ingress,secret
```

1. Trova il servizio con tag `ai.model=fast_v1.2` e aggiorna il suo Deployment per usare `thinking_v1.6` al posto
2. Trova il servizio con tag `access.public=true` e scala il suo Deployment a 2 repliche
3. Esporta esattamente **10 trace** dal servizio `speechai` in formato JSON su `/course/14/traces.json`

---

### Q15 – Vertical Pod Autoscaler (VPA)
Un singolo `etcd` è in esecuzione nel Namespace `sargasso`.

1. Aggiungi un VPA chiamato `etcd-vpa` al file `/course/15/etcd.yaml` e crealo. Non modificare lo StatefulSet nel file
2. Il VPA deve applicare raccomandazioni solo alla creazione del Pod:
   - Minimo: cpu `20m`, memory `20Mi`
   - Massimo: cpu `50m`, memory `50Mi`
3. Riavvia il Pod in modo che le raccomandazioni VPA vengano applicate

---

### Q16 – Argo Rollouts, Canary
Argo Rollouts è installato con dashboard su `http://<node>:30160`. Nel Namespace `baltic`, un Rollout `webapp` è attualmente in pausa durante un canary deployment al 50% di traffico.

Accesso GUI (port-forward):

```bash
kubectl -n argo-rollouts port-forward --address 0.0.0.0 svc/argo-rollouts-dashboard 30160:3100
```

Credenziali:
- Dashboard Rollouts in lab normalmente senza login.
- Se richiesto auth/token, verifica:

```bash
kubectl -n argo-rollouts get svc,secret,sa
```

1. Promuovi il Rollout per completare tutti i passi rimanenti
2. Sostituisci il passo `pause` con un passo di analisi:
   - Usa il template in `/course/16/analysis_template.yaml`
   - Completa l'URL del template per verificare il Service `webapp-canary`
3. Avvia un nuovo rollout impostando la variabile d'ambiente `VERSION` a `1.18.4`

---

### Q17 – FluxCD
FluxCD è installato e la CLI `flux` è disponibile.

1. Riprendi la Kustomization `havel-west` per correggere il drift del repository `/course/17/havel-west`
2. Deploya `/course/17/havel-east`:
   - Crea il GitRepository `havel-east` che punta al repository `${GITEA_URL}/${GITEA_ORG}/havel-east.git`, branch `main`
   - Crea la Kustomization `havel-east` che deploya dal GitRepository `havel-east` al Namespace `havel-east`

---

### Q18 – Kyverno
Kyverno è installato. La CLI `kyverno` è disponibile.

Crea una `NamespacedMutatingPolicy` chiamata `security-check` che:
- Muta i Pod durante `CREATE` e `UPDATE`
- Aggiunge la label `audit: pending` ai Pod, **ma solo se la label non esiste già**

Poi:
1. Crea due Pod chiamati `test-pending` e `test-passed` con immagine `nginx:1-alpine`
2. Aggiorna la label su `test-passed` a `audit: passed` — Kyverno non deve cambiarla di nuovo

---

### Q19 – Crossplane
Crossplane è installato. Il team ha creato una `CompositeResourceDefinition` `redis.cache.killer.sh` e una Composition parziale.

1. Crea una risorsa `Redis` chiamata `cache` nel Namespace `danau` con `size: medium`
2. Estendi la Composition in `/course/19/composition.yaml` per creare anche un Service:
   - Chiamato `redis`
   - Che mappa la porta `6379` ai Pod dello StatefulSet
   - Tipo `ClusterIP`
   - Segui il pattern esistente per `patches` e `readinessChecks`
3. Verifica che il Service sia stato aggiunto alle risorse Redis esistenti

---

### Q20 – Linkerd + Gateway API
Il Namespace `saltlake-app` è parte della mesh Linkerd.

1. Crea due risorse `Server`:
   - `frontend` per label Pod `app: frontend` su porta `80`
   - `backend` per label Pod `app: backend` su porta `80`
2. Correggi l'`AuthorizationPolicy` `frontend-to-backend` esistente per consentire ai Pod frontend di accedere ai Pod backend
3. Crea un `HTTPRoute` (Gateway API) chiamato `backend-canary` per il Service `backend` che implementi il traffic splitting:
   - `10%` verso `backend-v1`
   - `90%` verso `backend-v2`

---

### Verifica finale end-to-end

1. CRD `TeamMonitoring` v1alpha2 applicata con risorsa `general` in `pacific`
2. Prometheus scrape esteso a Pod `app=proxy` con query eseguita
3. Argo CD `web-client` e `web-client-testing` sincronizzati con branch corretti
4. Flagger Canary per `app1` e `app2` con webhook configurato
5. Gatekeeper ConstraintTemplate e Constraint applicati in `planet-apps`
6. OpenTofu state aggiornato per `service-black-bean`, `service-green-curry`, `service-red-velvet`
7. OpenCost pricing model aggiornato con query Prometheus eseguita
8. Grafana Loki query aggiornata e Pod errori scalati a 0
9. Kustomize overlay staging e production applicati con valori corretti
10. ResourceQuota applicato ai Namespace caspian-pipeline con Git history analizzata
11. Argo Workflows `greeter` e `configurator` eseguiti con successo
12. Tekton Pipeline `p1-team-onboarding` e `p2-team-scanner` eseguite con successo
13. Pod Security Standards `restricted` applicato a `ammersee-legacy`
14. Jaeger trace esportate per `speechai` con Deployment aggiornati
15. VPA `etcd-vpa` applicato con raccomandazioni
16. Argo Rollouts `webapp` promosso con analysis template configurato
17. FluxCD Kustomization `havel-west` e `havel-east` sincronizzate
18. Kyverno NamespacedMutatingPolicy `security-check` applicata con test Pod
19. Crossplane Composition estesa con Service per Redis
20. Linkerd Server e HTTPRoute configurati con traffic splitting funzionante

---
