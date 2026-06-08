# Le 20 domande dell'esame — Observability and Incident Response Lab

Scenario creato da `setup-observability-incident-lab.sh`. Gli starter sono in
`~/course-observability-incident/`.

**Vincolo:** non modificare i componenti core Prometheus, Loki, Promtail,
Grafana o Jaeger per nascondere i sintomi. Ogni remediation deve includere
evidenza runtime e rollback. Non usare `trace_id` come label Prometheus.

---

### Q1 – Diagnosi target Prometheus

Analizza Service, ServiceMonitor e target discovery di `incident-api`.

### Q2 – Correzione ServiceMonitor

Seleziona Namespace `observability-app`, label `app=incident-api`, porta
`metrics`, path `/metrics`.

### Q3 – PromQL error rate

Scrivi la query del rapporto failure/request e verifica che restituisca una
serie valida.

### Q4 – Alerting

Completa l'alert oltre 5% per 5 minuti, severity critical, e salva target,
query e stato in `01/monitoring-check.txt`.

---

### Q5 – Diagnosi datasource Loki

Analizza la ConfigMap `02/loki-datasource.yaml` e la health della datasource.

### Q6 – Correzione datasource

Imposta URL `http://loki.monitoring.svc:3100`, accesso proxy e default true.

### Q7 – Query LogQL

Completa `02/queries.txt` per errori, conteggio 5m per Pod ed estrazione JSON
di `trace_id`.

### Q8 – Evidenza logging

Identifica il Pod con più errori e salva query, risultato e trace ID in
`02/logging-check.txt`.

---

### Q9 – Diagnosi collector OTLP

Analizza receiver, exporter e pipeline mancanti in `03/otel-collector.yaml`.

### Q10 – Receiver ed exporter

Configura OTLP gRPC su `0.0.0.0:4317` ed exporter verso Jaeger 4317 insecure.

### Q11 – Traces pipeline

Configura pipeline traces con receiver ed exporter OTLP e verifica i log del
collector.

### Q12 – Generazione e ricerca trace

Esegui `03/trace-generator.yaml`, trova 10 trace `checkout-api` e salva ID,
durata e span in `03/tracing-check.txt`.

---

### Q13 – Deployment frequency

Crea la recording rule per deployment giornalieri usando totale e finestra
di misurazione.

### Q14 – Change failure rate

Crea la recording rule failure/deployment e confrontala con target 15%.

### Q15 – Lead time e MTTR

Crea le due medie da sum/count e compila i valori in `04/baseline.md`.

### Q16 – Availability e piano miglioramento

Calcola availability HTTP, individua il KPI peggiore e definisci tre azioni
misurabili. Salva query in `04/kpi-check.txt`.

---

### Q17 – Triage incidente

Genera 20 richieste e quantifica error rate, Pod coinvolti e blast radius con
Prometheus.

### Q18 – Correlazione log-trace

Da Loki estrai backend e trace ID; apri lo stesso trace in Jaeger e identifica
lo span in errore.

### Q19 – Remediation

Correggi soltanto `05/incident-api-config.yaml`, riavvia i Pod per ricaricare
la ConfigMap e verifica HTTP 200, nuovi log e trace sane.

### Q20 – Verifica finale incident response

Completa `05/runbook.md` con detection, timeline, root cause, remediation,
rollback e prevenzione. Allega verifiche:

```bash
kubectl -n monitoring get servicemonitors,prometheusrules
kubectl -n tracing-lab get deployments,jobs,pods,services
kubectl -n observability-app get deployments,pods,services,configmaps
```
