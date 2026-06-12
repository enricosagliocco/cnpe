# Observability and Incident Response Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
Le soluzioni sono raccolte nella sezione finale del documento.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - Diagnosi target Prometheus

Percorso: `~/course-observability-incident/01`.

1. Analizza Service, ServiceMonitor e target discovery di `incident-api`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Correzione ServiceMonitor

Percorso: `~/course-observability-incident/01`.

1. Seleziona Namespace `observability-app`, label `app=incident-api`, porta
   `metrics`, path `/metrics`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - PromQL error rate

Percorso: `~/course-observability-incident/01`.

1. Scrivi la query del rapporto failure/request e verifica che restituisca una
   serie valida.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Alerting

Percorso: `~/course-observability-incident/01`.

1. Completa l'alert oltre 5% per 5 minuti, severity critical, e salva target,
   query e stato in `01/monitoring-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/01` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Diagnosi datasource Loki

Percorso: `~/course-observability-incident/02`.

1. Analizza la ConfigMap `02/loki-datasource.yaml` e la health della
   datasource.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/loki-datasource.yaml
```

---

### Q6 - Correzione datasource

Percorso: `~/course-observability-incident/02`.

1. Imposta URL `http://loki.monitoring.svc:3100`, accesso proxy e default
   true.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Query LogQL

Percorso: `~/course-observability-incident/02`.

1. Completa `02/queries.txt` per errori, conteggio 5m per Pod ed estrazione
   JSON di `trace_id`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Evidenza logging

Percorso: `~/course-observability-incident/02`.

1. Identifica il Pod con più errori e salva query, risultato e trace ID in
   `02/logging-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/02` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Diagnosi collector OTLP

Percorso: `~/course-observability-incident/03`.

1. Analizza receiver, exporter e pipeline mancanti in
   `03/otel-collector.yaml`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/otel-collector.yaml
```

---

### Q10 - Receiver ed exporter

Percorso: `~/course-observability-incident/03`.

1. Configura OTLP gRPC su `0.0.0.0:4317` ed exporter verso Jaeger 4317
   insecure.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - Traces pipeline

Percorso: `~/course-observability-incident/03`.

1. Configura pipeline traces con receiver ed exporter OTLP e verifica i log
   del collector.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Generazione e ricerca trace

Percorso: `~/course-observability-incident/03`.

1. Esegui `03/trace-generator.yaml`, trova 10 trace `checkout-api` e salva ID,
   durata e span in `03/tracing-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 03/trace-generator.yaml
```

---

### Q13 - Deployment frequency

Percorso: `~/course-observability-incident/04`.

1. Crea la recording rule per deployment giornalieri usando totale e finestra
   di misurazione.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - Change failure rate

Percorso: `~/course-observability-incident/04`.

1. Crea la recording rule failure/deployment e confrontala con target 15%.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Lead time e MTTR

Percorso: `~/course-observability-incident/04`.

1. Crea le due medie da sum/count e compila i valori in `04/baseline.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 - Availability e piano miglioramento

Percorso: `~/course-observability-incident/04`.

1. Calcola availability HTTP, individua il KPI peggiore e definisci tre azioni
   misurabili.

2. Salva query in `04/kpi-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - Triage incidente

Percorso: `~/course-observability-incident/05`.

1. Genera 20 richieste e quantifica error rate, Pod coinvolti e blast radius
   con Prometheus.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 - Correlazione log-trace

Percorso: `~/course-observability-incident/05`.

1. Da Loki estrai backend e trace ID; apri lo stesso trace in Jaeger e
   identifica lo span in errore.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Remediation

Percorso: `~/course-observability-incident/05`.

1. Correggi soltanto `05/incident-api-config.yaml`, riavvia i Pod per
   ricaricare la ConfigMap e verifica HTTP 200, nuovi log e trace sane.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 05/incident-api-config.yaml
```

---

### Q20 - Verifica finale incident response

Percorso: `~/course-observability-incident/05`.

1. Completa `05/runbook.md` con detection, timeline, root cause, remediation,
   rollback e prevenzione.

2. Allega verifiche:

```bash
kubectl -n monitoring get servicemonitors,prometheusrules
kubectl -n tracing-lab get deployments,jobs,pods,services
kubectl -n observability-app get deployments,pods,services,configmaps
```

**Tip 1**

Esamina tutti i manifest presenti in `~/course-observability-incident/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Diagnosi target Prometheus

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Correzione ServiceMonitor

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - PromQL error rate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - Alerting

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/01
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - Diagnosi datasource Loki

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/02
kubectl apply -f 02/loki-datasource.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - Correzione datasource

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - Query LogQL

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Evidenza logging

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/02
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - Diagnosi collector OTLP

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/03
kubectl apply -f 03/otel-collector.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - Receiver ed exporter

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - Traces pipeline

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - Generazione e ricerca trace

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/03
kubectl apply -f 03/trace-generator.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - Deployment frequency

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Change failure rate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - Lead time e MTTR

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - Availability e piano miglioramento

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - Triage incidente

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - Correlazione log-trace

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - Remediation

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/05
kubectl apply -f 05/incident-api-config.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - Verifica finale incident response

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-observability-incident/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
