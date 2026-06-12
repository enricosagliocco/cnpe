# Le 20 domande dell'esame — Delivery and Operations Lab (simulatore lab)

## Metodo operativo obbligatorio

Ogni domanda e un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale nel cluster;
2. raccogliere il sintomo tramite stato, condizioni, eventi, log o output del controller;
3. identificare e registrare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla con un test runtime positivo e, quando previsto, negativo.

La sola modifica del file, il solo dry-run client-side o una risposta teorica
non completano il ticket. Conserva comando, errore iniziale, correzione e
verifica finale nell'evidence file indicato dalla domanda.

Scenario deployato da `setup-delivery-ops-lab.sh`. Manifest e file starter in
`~/course-delivery-ops/`.

**Vincolo:** non disinstallare Argo CD, Argo Rollouts, FluxCD, Tekton,
Prometheus, Grafana, Loki o Jaeger. Non inventare nomi o valori: usa quelli
indicati e conserva in ogni directory i risultati richiesti.

Ogni domanda parte da uno stato incompleto o guasto creato dal setup. Prima
riproduci il problema applicando il file indicato o osservando la risorsa
running; dopo la modifica devi applicare la soluzione e verificare lo stato
finale dalla GUI e con Kubernetes. La sola modifica del file non completa
l'esercizio.

Accesso GUI (port-forward):

```bash
kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 30030:443
kubectl -n argo-rollouts port-forward --address 0.0.0.0 svc/argo-rollouts-dashboard 30160:3100
kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30120:9097
kubectl -n prometheus port-forward --address 0.0.0.0 svc/prometheus-server 30020:80
kubectl -n monitoring port-forward --address 0.0.0.0 svc/grafana 30080:80
kubectl -n tracing port-forward --address 0.0.0.0 svc/jaeger-collector 30014:16686
```

Credenziali:
- Argo CD: user `admin`; recupera la password con:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

- Grafana: user `admin`, password `admin`.
- Argo Rollouts, Tekton, Prometheus e Jaeger non richiedono login nel lab.

Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 - Argo CD source revision
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/01`.


L'Application `storefront` in `01/application.yaml` contiene placeholder e non
può essere creata correttamente.

1. Completa `01/application.yaml`: Application `storefront`, repo `https://github.com/argoproj/argocd-example-apps.git`, path `guestbook`, branch `master`, destinazione `delivery-dev`, sync automatica con prune e self-heal.
2. Applica il file e avvia il sync dalla GUI Argo CD.
3. Verifica che Application, Deployment e Service risultino `Synced` e
   `Healthy`.

---

### Q2 - Argo CD staging promotion
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/02`.


`02/application.yaml` è una copia incompleta della configurazione production.

1. Partendo da `02/application.yaml`, crea `storefront-staging` nel Namespace `delivery-staging`, stesso repo/path della Q1, label `environment=staging` e sync manuale.
2. Applica il file ed esegui manualmente il sync.
3. Verifica `Synced/Healthy` e salva `argocd app get` in `02/result.txt`.

---

### Q3 - Flux GitRepository
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/03`.


Il GitRepository `platform-source` usa il branch inesistente `develop`.

1. Correggi `03/source.yaml`: branch `main`, interval `1m`, URL `https://github.com/fluxcd/flux2-kustomize-helm-example`.
2. Applica il file e forza la riconciliazione.
3. Verifica `Ready=True` e una revisione Git valorizzata.

---

### Q4 - Flux Kustomization
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/04`.


`04/kustomization.yaml` contiene una spec vuota e non è riconciliabile.

1. Completa `04/kustomization.yaml`: source `platform-source`, path `./clusters/staging`, target `flux-staging`, prune true, interval `5m`.
2. Applica il file e forza la riconciliazione.
3. Verifica `Ready=True`, risorse create in `flux-staging` e salva status e
   revisione in `04/result.txt`.

---

### Q5 - GitOps drift
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/05`.


Il Deployment `drift-demo` è già running in `delivery-dev` con 2 repliche.

1. Gestiscilo con una sorgente GitOps usando `05/deployment.yaml`.
2. Portalo manualmente a 4 repliche per creare drift.
3. Forza la riconciliazione.
4. Verifica il ritorno automatico a 2 e salva prima/dopo in `05/result.txt`.

---

### Q6 - Tekton task ordering
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/06`.


La Pipeline `ordered-build` ha dipendenze e workspace mancanti.

1. In `06/pipeline.yaml`, fai eseguire `test` dopo `clone` e `package` dopo `test`, condividendo il workspace `source`.
2. Crea un PipelineRun con workspace `emptyDir`.
3. Verifica dalla Dashboard ordine e `Succeeded=True`.

---

### Q7 - Tekton parallelism
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/07`.


`07/pipeline.yaml` deve essere completata in modo che il grafo sia realmente
parallelo.

1. In `07/pipeline.yaml`, esegui `lint` e `unit-test` in parallelo dopo `clone`; `report` deve attendere entrambi.
2. Esegui un PipelineRun.
3. Verifica la sovrapposizione temporale di `lint` e `unit-test` e salva i
   timestamp in `07/result.txt`.

---

### Q8 - Tekton results
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/08`.


Il Task `calculate-version` produce ancora il valore `TODO`.

1. Completa `08/task.yaml`: il Task `calculate-version` deve produrre il result `version` con valore `1.4.7`; la Pipeline deve passarlo al Task `print-version`.
2. Implementa e avvia il PipelineRun.
3. Verifica `Succeeded=True` e log finale `release=1.4.7`.

---

### Q9 - Argo Rollouts canary
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/09`.


I Service stable/canary esistono già, mentre `09/rollout.yaml` contiene
placeholder nella strategia.

1. Completa `09/rollout.yaml` con passi `setWeight: 20`, pausa `30s`, `setWeight: 50`, pausa manuale e `setWeight: 100`.
2. Usa `checkout-stable` e `checkout-canary`.
3. Applica il Rollout e avvia una nuova revisione.
4. Verifica dalla Dashboard i pesi, la pausa manuale e lo stato finale
   `Healthy`.

---

### Q10 - AnalysisTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/10`.


`10/analysis.yaml` non può essere usato perché address, query e condizione sono
placeholder.

1. Completa `10/analysis.yaml`: metric `success-rate`, Prometheus `http://prometheus-server.prometheus.svc:80`, query `sum(rate(http_requests_total{status!~"5.."}[2m])) / sum(rate(http_requests_total[2m]))`, successo `result[0] >= 0.99`.
2. Applica l'AnalysisTemplate e collegalo al Rollout `checkout`.
3. Avvia una nuova revisione e verifica un AnalysisRun `Successful`.

---

### Q11 - Rollback progressive delivery
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/11`.


Il Rollout `checkout` deve rimanere disponibile anche durante una revisione
non valida.

1. Imposta nel Rollout `checkout` l'immagine inesistente `nginx:does-not-exist`, osserva il fallimento e annulla l'update.
2. Verifica che la revisione stabile continui a servire traffico.
3. Esegui undo e verifica `Healthy`.
4. Salva revisioni, comando e stato finale in `11/result.txt`.

---

### Q12 - Prometheus target discovery
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/12`.


Il Deployment `traffic-api` è già running in `metrics-lab`, espone `/metrics`
su `8080` ed è annotato, ma Prometheus non lo scopre.

1. Completa `12/prometheus-job.yaml` per scoprire Pod nel Namespace `metrics-lab` con label `metrics=true`, path `/metrics`, porta annotata `prometheus.io/port`.
2. Inserisci il job nella configurazione Prometheus e ricaricala.
3. Verifica in **Status > Targets** `traffic-api` UP e query `up=1`.

---

### Q13 - PromQL availability
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/13`.


`traffic-api` espone metriche deterministiche, mentre `13/queries.txt` contiene
solo placeholder.

1. Scrivi in `13/queries.txt` le query per: request rate per workload, percentuale 5xx e disponibilità negli ultimi 5 minuti.
2. Usa metriche `http_requests_total{namespace="metrics-lab"}` e raggruppa per `app`.
3. Esegui tutte le query nella GUI Prometheus e salva anche un risultato di
   esempio per ciascuna.
4. Verifica che ogni query restituisca una serie per `traffic-api`.

---

### Q14 - Prometheus alert
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/14`.


`14/rule.yaml` contiene una regola non valida con campi `TODO`.

1. Completa `14/rule.yaml`: alert `HighErrorRate`, 5xx ratio maggiore di 5% per `5m`, severity `critical`, summary con label `app`.
2. Verifica la regola con `promtool check rules`.
3. Caricala in Prometheus e verifica che compaia nella pagina **Rules**.

---

### Q15 - Loki datasource health
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/15`.


Grafana è running, ma `15/datasource.yaml` punta a `wrong-loki` e usa accesso
diretto.

1. Correggi `15/datasource.yaml`: URL `http://loki.monitoring.svc:3100`, `access: proxy`, default true.
2. Applica/provisiona la datasource e riavvia Grafana se necessario.
3. Verifica `/api/datasources/uid/loki/health` con HTTP 200 e salva status e
   body in `15/result.txt`.

---

### Q16 - LogQL incident
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/16`.


I Deployment `log-heavy` e `log-light` stanno già producendo errori con
frequenze diverse, raccolti da Promtail.

1. In `16/queries.txt` scrivi le query per trovare log `ERROR`, contarli su 5m e raggrupparli per Pod nel Namespace `logging-lab`.
2. Esegui le query in Grafana Explore.
3. Identifica il Pod con più errori, risali al controller e salva entrambi in
   `16/result.txt`.
4. Verifica che il controller identificato sia `log-heavy`.

---

### Q17 - OpenTelemetry endpoint
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/17`.


Il Deployment `orders-api` è già running con endpoint OTLP e service name
errati.

1. Correggi `17/deployment.yaml` usando `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector.tracing.svc:4317` e `OTEL_SERVICE_NAME=orders-api`.
2. Applica la modifica e verifica il rollout.
3. Verifica dal Pod DNS e TCP 4317 e salva l'output in `17/result.txt`.

---

### Q18 - Trace correlation
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/18`.


`18/log.json` simula il log di un incidente e contiene il campo `trace_id`.

1. Il file `18/log.json` contiene `trace_id`.
2. Estrai il valore, interrogalo nella UI/API Jaeger per il servizio `orders-api` e salva trace ID, durata e span con errore in `18/result.txt`.
3. La verifica è completa solo se il trace ID del report coincide con quello
   del log.

---

### Q19 - Incident remediation
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/19`.


La directory `19/` contiene contemporaneamente tre configurazioni guaste che
riproducono i sintomi descritti in `incident.yaml`.

1. `19/incident.yaml` descrive tre sintomi: target Prometheus down, datasource Loki 400 e OTLP non raggiungibile.
2. Correggi i tre manifest nella directory e compila `19/report.md` con causa, fix, verifica e rollback.
3. Verifica target UP, datasource HTTP 200 e TCP OTLP raggiungibile.

---

### Q20 - Simulazione a tempo
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-delivery-ops/20`.


`20/checklist.md` è il test integrato del lab e deve riferirsi a risorse
realmente create nelle domande precedenti.

1. In massimo 25 minuti completa `20/checklist.md`: Argo Application Healthy, Flux Ready, PipelineRun riuscito, Rollout Healthy, alert valido, Loki health 200 e OTLP 4317 raggiungibile.
2. Inserisci un comando e il relativo output per ogni punto.
3. Verifica che nessun punto della checklist resti privo di evidenza runtime.

---

## Tracce di soluzione

Le soluzioni sono operative: usa gli starter, gli eventi e i comandi di verifica
indicati in ogni ticket. Conserva in `evidence.txt` sintomo iniziale, correzione e
risultato runtime finale; non sostituire i manifest completi senza diagnosi.
