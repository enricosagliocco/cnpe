# CNPE Batteria 08 - Observability, SLO e Incident Response

Focus strumenti: Prometheus, Alertmanager, Grafana, Loki, Jaeger, kubectl-debug, Argo Events.

## Domande (10)
1. Definisci SLI error-rate e latency p95 per servizio checkout.
2. Crea SLO 99.5% availability e burn-rate alerts multi-window.
3. Dashboard Grafana con pannelli golden signals.
4. Query Loki per correlare ERROR e traceID negli ultimi 30m.
5. Trova servizio degradato via Jaeger e identifica span critico.
6. Crea runbook alert-to-action in /course/8/runbook.md.
7. Simula incidente CPU throttling e mitiga senza downtime.
8. Aggiungi registrazione eventi di deploy in audit stream.
9. Misura MTTR dalla detection al recovery.
10. Esegui retrospettiva tecnica con 3 azioni preventive.

## Risposte guida sintetiche
1. PromQL su req total/5xx e histogram buckets.
2. Alerting rules 5m/1h burn-rate.
3. Dashboard con template namespace/app.
4. Filtra log con pattern trace/span id.
5. Service graph e trace comparison.
6. Passi operativi, owner, escalation.
7. Tune requests/limits o scaling mirato.
8. Collega eventi CD a Loki/Elasticsearch.
9. Timestamp incident lifecycle.
10. Action items misurabili con owner.
