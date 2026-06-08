# CNPE Observability, Efficiency and Incident Response Lab

Scenario creato da `setup-observability-incident-lab.sh`. Gli starter sono in
`~/course-observability-incident/`.

## Vincoli d'esame

- Non modificare Prometheus, Loki, Promtail, Grafana o Jaeger per nascondere
  i sintomi.
- Non eliminare metriche, log o trace che dimostrano l'incidente.
- Ogni remediation deve includere una verifica runtime e un rollback.
- Usa label a bassa cardinalita; non usare `trace_id` come label Prometheus.
- Non modificare il Deployment `incident-api` nella prova finale.

---

### Q1 – Monitoring e alerting

`incident-api` espone `/metrics`, ma il ServiceMonitor non trova il target.

Correggi `01/monitoring.yaml`:

1. seleziona il Namespace `observability-app`;
2. seleziona il Service con label `app=incident-api`;
3. usa la porta `metrics`;
4. crea un alert quando il rapporto tra failure e richieste supera il 5% per
   5 minuti;
5. usa severity `critical` e un summary informativo.

Verifica target `UP`, query, regola caricata e stato dell'alert. Salva output
ed eventi in `01/monitoring-check.txt`.

---

### Q2 – Logging centralizzato

La ConfigMap di provisioning della datasource Loki è errata. Correggi
`02/loki-datasource.yaml` usando:

- URL `http://loki.monitoring.svc:3100`;
- accesso `proxy`;
- datasource predefinita.

Completa `02/queries.txt` con LogQL per:

1. trovare i log JSON `ERROR` di `incident-api`;
2. contarli su 5 minuti raggruppandoli per Pod;
3. estrarre `trace_id` tramite parser JSON.

Verifica la health della datasource, identifica il Pod con più errori e salva
query e risultati in `02/logging-check.txt`.

---

### Q3 – Distributed tracing

Il collector OpenTelemetry non ascolta sulla rete del Pod, esporta verso un
host inesistente e non ha una traces pipeline.

Correggi `03/otel-collector.yaml`:

1. receiver OTLP gRPC su `0.0.0.0:4317`;
2. exporter OTLP verso `jaeger-collector.tracing-lab.svc:4317`;
3. TLS insecure per il traffico interno del lab;
4. pipeline `traces` con receiver `otlp` ed exporter `otlp`.

Applica il collector, crea il Job da `03/trace-generator.yaml` e verifica in
Jaeger 10 trace del servizio `checkout-api`. Salva log, trace ID, durata e
numero di span in `03/tracing-check.txt`.

---

### Q4 – Efficienza e indicatori della piattaforma

Le metriche `platform_deployments_total`,
`platform_measurement_window_days`,
`platform_deployment_failures_total`,
`platform_deployment_lead_time_seconds_*` e
`platform_incident_recovery_seconds_*` sono esposte da `incident-api`.

Completa `04/platform-kpis.yaml` con recording rule per:

1. deployment frequency;
2. change failure rate;
3. lead time medio;
4. MTTR medio.

Compila `04/baseline.md` includendo anche l'availability ricavata dalle
metriche HTTP. Confronta ogni valore con il target, individua il principale
collo di bottiglia e proponi tre azioni misurabili.

Verifica le recording rule in Prometheus e salva query e risultati in
`04/kpi-check.txt`.

---

### Q5 – Diagnosi e remediation dell'incidente

`incident-api` risponde `503`, genera errori e trace fallite. Non modificare
il Deployment.

1. genera almeno 20 richieste al Service;
2. usa Prometheus per quantificare error rate e impatto;
3. usa Loki per trovare il backend guasto ed estrarre un `trace_id`;
4. apri lo stesso trace in Jaeger e identifica lo span in errore;
5. determina la root cause;
6. correggi soltanto `05/incident-api-config.yaml`;
7. applica la modifica e riavvia il rollout per ricaricare il ConfigMap;
8. verifica HTTP 200, riduzione dei nuovi errori e trace senza errore;
9. documenta rollback e azione preventiva.

Compila `05/runbook.md` e salva comandi e output in
`05/incident-check.txt`.

---

### Verifica finale

```bash
kubectl -n monitoring get servicemonitors,prometheusrules
kubectl -n monitoring get pods,services
kubectl -n tracing-lab get deployments,jobs,pods,services
kubectl -n observability-app get deployments,pods,services,configmaps
```

La prova è completa quando metriche, alert, log e trace descrivono lo stesso
incidente, gli indicatori di efficienza sono misurabili e la remediation
ripristina il servizio con evidenze verificabili.
