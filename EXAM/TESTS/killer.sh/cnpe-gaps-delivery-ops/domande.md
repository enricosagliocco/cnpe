# CNPE Gaps - Delivery and Operations - 20 domande

Scenario: `~/course-delivery-ops`. Non inventare nomi o valori: usa quelli
indicati e conserva in ogni directory i risultati richiesti.

### Q1 - Argo CD source revision
Completa `01/application.yaml`: Application `storefront`, repo
`https://github.com/argoproj/argocd-example-apps.git`, path `guestbook`, branch
`master`, destinazione `delivery-dev`, sync automatica con prune e self-heal.
Lo stato finale deve essere `Synced` e `Healthy`.

### Q2 - Argo CD staging promotion
Partendo da `02/application.yaml`, crea `storefront-staging` nel Namespace
`delivery-staging`, stesso repo/path della Q1, label `environment=staging` e
sync manuale. Salva `argocd app get` in `02/result.txt`.

### Q3 - Flux GitRepository
Correggi `03/source.yaml`: branch `main`, interval `1m`, URL
`https://github.com/fluxcd/flux2-kustomize-helm-example`. La source
`platform-source` in `flux-system` deve avere `Ready=True`.

### Q4 - Flux Kustomization
Completa `04/kustomization.yaml`: source `platform-source`, path
`./clusters/staging`, target `flux-staging`, prune true, interval `5m`. Salva
status e revision in `04/result.txt`.

### Q5 - GitOps drift
Il Deployment `drift-demo` in `delivery-dev` deve avere 2 repliche come in
`05/deployment.yaml`. Portalo manualmente a 4, forza la riconciliazione e
dimostra il ritorno a 2 in `05/result.txt`.

### Q6 - Tekton task ordering
In `06/pipeline.yaml`, fai eseguire `test` dopo `clone` e `package` dopo
`test`, condividendo il workspace `source`. Il PipelineRun deve terminare
`Succeeded=True`.

### Q7 - Tekton parallelism
In `07/pipeline.yaml`, esegui `lint` e `unit-test` in parallelo dopo `clone`;
`report` deve attendere entrambi. Salva l'ordine temporale dei TaskRun in
`07/result.txt`.

### Q8 - Tekton results
Completa `08/task.yaml`: il Task `calculate-version` deve produrre il result
`version` con valore `1.4.7`; la Pipeline deve passarlo al Task `print-version`.
Il log finale deve contenere `release=1.4.7`.

### Q9 - Argo Rollouts canary
Completa `09/rollout.yaml` con passi `setWeight: 20`, pausa `30s`,
`setWeight: 50`, pausa manuale e `setWeight: 100`. Service stable
`checkout-stable`, canary `checkout-canary`.

### Q10 - AnalysisTemplate
Completa `10/analysis.yaml`: metric `success-rate`, Prometheus
`http://prometheus-server.prometheus.svc:80`, query
`sum(rate(http_requests_total{status!~"5.."}[2m])) /
sum(rate(http_requests_total[2m]))`, successo `result[0] >= 0.99`.

### Q11 - Rollback progressive delivery
Imposta nel Rollout `checkout` l'immagine inesistente
`nginx:does-not-exist`, osserva il fallimento e annulla l'update. Salva
revisioni, comando di undo e stato finale in `11/result.txt`.

### Q12 - Prometheus target discovery
Completa `12/prometheus-job.yaml` per scoprire Pod nel Namespace `metrics-lab`
con label `metrics=true`, path `/metrics`, porta annotata
`prometheus.io/port`. Il target `traffic-api` deve risultare `up=1`.

### Q13 - PromQL availability
Scrivi in `13/queries.txt` le query per: request rate per workload, percentuale
5xx e disponibilità negli ultimi 5 minuti. Usa metriche
`http_requests_total{namespace="metrics-lab"}` e raggruppa per `app`.

### Q14 - Prometheus alert
Completa `14/rule.yaml`: alert `HighErrorRate`, 5xx ratio maggiore di 5% per
`5m`, severity `critical`, summary con label `app`. Verifica la regola con
`promtool check rules`.

### Q15 - Loki datasource health
Correggi `15/datasource.yaml`: URL `http://loki.monitoring.svc:3100`,
`access: proxy`, default true. Verifica `/api/datasources/uid/loki/health` e
salva status HTTP e body in `15/result.txt`.

### Q16 - LogQL incident
In `16/queries.txt` scrivi le query per trovare log `ERROR`, contarli su 5m e
raggrupparli per Pod nel Namespace `logging-lab`. Identifica il Pod con più
errori e salva nome e controller in `16/result.txt`.

### Q17 - OpenTelemetry endpoint
Correggi `17/deployment.yaml` usando
`OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector.tracing.svc:4317` e
`OTEL_SERVICE_NAME=orders-api`. Verifica DNS e TCP 4317 in `17/result.txt`.

### Q18 - Trace correlation
Il file `18/log.json` contiene `trace_id`. Estrai il valore, interrogalo nella
UI/API Jaeger per il servizio `orders-api` e salva trace ID, durata e span con
errore in `18/result.txt`.

### Q19 - Incident remediation
`19/incident.yaml` descrive tre sintomi: target Prometheus down, datasource
Loki 400 e OTLP non raggiungibile. Correggi i tre manifest nella directory e
compila `19/report.md` con causa, fix, verifica e rollback.

### Q20 - Simulazione a tempo
In massimo 25 minuti completa `20/checklist.md`: Argo Application Healthy,
Flux Ready, PipelineRun riuscito, Rollout Healthy, alert valido, Loki health
200 e OTLP 4317 raggiungibile. Inserisci un comando e il relativo output per
ogni punto.
