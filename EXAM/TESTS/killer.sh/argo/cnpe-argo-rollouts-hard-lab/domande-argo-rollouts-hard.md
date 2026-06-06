# CNPE Hard Lab — Argo Rollouts

Scenario: `argo-rollouts-hard`  
Namespace: `rollouts-lab`  
Directory: `/course/argo-rollouts-hard`  
Tempo consigliato: 75–90 minuti.

## Q1 — Stato iniziale

Verifica:

- controller Argo Rollouts;
- CRD Rollout/AnalysisTemplate;
- Rollout `payments`;
- Service `payments`, `payments-stable`, `payments-canary`.

Salva:

```bash
/course/argo-rollouts-hard/q1-status.txt
```

---

## Q2 — Service stable/canary

I Service stable/canary hanno selector troppo generici.

Correggi la configurazione in modo che Argo Rollouts gestisca correttamente stable e canary service.

Verifica selector dopo la riconciliazione e salva:

```bash
/course/argo-rollouts-hard/q2-services.txt
```

---

## Q3 — AnalysisTemplate

L’AnalysisTemplate ha una `successCondition` che si aspetta `ok`, ma il job stampa altro.

Correggi:

- usa l’argomento `service-name`;
- il check deve chiamare `http://<service-name>.rollouts-lab/`;
- l’output deve soddisfare `successCondition`.

Salva:

```bash
/course/argo-rollouts-hard/q3-analysis.yaml
```

---

## Q4 — Strategia canary

La strategia deve essere:

1. `setWeight: 25`
2. `pause: {}`
3. analysis
4. `setWeight: 50`
5. `pause: {}`
6. `setWeight: 100`

Correggi il Rollout se necessario e salva:

```bash
/course/argo-rollouts-hard/q4-rollout-strategy.yaml
```

---

## Q5 — Verifica baseline

Il Rollout deve essere Healthy/Available con immagine iniziale.

Salva:

```bash
/course/argo-rollouts-hard/q5-baseline.txt
```

---

## Q6 — Bad update e abort

Applica:

```bash
kubectl apply -f /course/argo-rollouts-hard/30-bad-update.yaml
```

Verifica che la nuova ReplicaSet non diventi healthy per immagine errata.

Esegui abort o rollback secondo stato osservato.

Salva:

```bash
/course/argo-rollouts-hard/q6-bad-update-abort.txt
```

---

## Q7 — Good update canary

Applica:

```bash
kubectl apply -f /course/argo-rollouts-hard/40-good-update.yaml
```

Verifica:

- rollout in pausa al 25%;
- stable e canary ReplicaSet;
- AnalysisRun creato quando previsto.

Salva:

```bash
/course/argo-rollouts-hard/q7-good-update.txt
```

---

## Q8 — Promote step by step

Promuovi manualmente il rollout fino al 50%, poi fino al completamento.

Puoi usare plugin `kubectl argo rollouts` se disponibile oppure patchare pause/gestire rollout secondo risorse Kubernetes.

Salva eventi e stato:

```bash
/course/argo-rollouts-hard/q8-promote.txt
```

---

## Q9 — AnalysisRun

Ispeziona l’AnalysisRun generato.

Salva:

- nome;
- phase;
- metric result;
- eventuali job creati.

File:

```bash
/course/argo-rollouts-hard/q9-analysisrun.txt
```

---

## Q10 — Verifica traffico

Usa NodePort indicato in README.

Verifica che dopo promozione completa il servizio esposto risponda con versione v2.

Salva:

```bash
/course/argo-rollouts-hard/q10-traffic.txt
```

---

## Q11 — Revision history

Mostra ReplicaSet e revisioni Rollout.

Salva:

```bash
/course/argo-rollouts-hard/q11-revisions.txt
```

---

## Q12 — Undo

Esegui rollback/undo alla revisione precedente.

Verifica che il servizio torni alla versione precedente oppure documenta lo stato osservato.

Salva:

```bash
/course/argo-rollouts-hard/q12-undo.txt
```

---

## Q13 — Report finale

Crea:

```bash
/course/argo-rollouts-hard/final-report.txt
```

Deve contenere:

- stato finale Rollout;
- stableService/canaryService;
- ultima AnalysisRun;
- immagine stabile attuale;
- differenza tra Rollout, ReplicaSet, AnalysisTemplate, AnalysisRun, pause, promote, abort.
