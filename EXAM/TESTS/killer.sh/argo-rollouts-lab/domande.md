# Argo Rollouts Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
`Solution` riporta il flusso operativo di applicazione e verifica.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - Rollout base

Percorso: `~/course-argo-rollouts/01`.

1. Completa `01/rollout.yaml` con selector e pod labels coerenti.

2. Applica e verifica `Healthy` con tre repliche.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 01/rollout.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/01
kubectl apply -f 01/rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q2 - Canary steps

Percorso: `~/course-argo-rollouts/02`.

1. Configura in `02/rollout.yaml` peso 20%, pausa 10 secondi, peso 50%, pausa
   manuale e peso 100%.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 02/rollout.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/02
kubectl apply -f 02/rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q3 - Stable e canary Service

Percorso: `~/course-argo-rollouts/03`.

1. Collega `canary-stable` e `canary-preview` al Rollout.

2. Durante un update verifica gli hash aggiunti ai selector.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/03` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/03
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q4 - Promozione manuale

Percorso: `~/course-argo-rollouts/04`.

1. Avvia v2, attendi la pausa manuale, esegui promote e salva ReplicaSet, step
   e revisioni in `04/evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/04` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/04
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q5 - Abort

Percorso: `~/course-argo-rollouts/05`.

1. Avvia una revisione con immagine inesistente, osserva il degrado, esegui
   abort e verifica che il Service stabile continui a servire la revisione
   precedente.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q6 - Undo

Percorso: `~/course-argo-rollouts/06`.

1. Completa un update a v2, avvia v3 e usa undo verso la revisione precedente.

2. Documenta immagini, revisioni e stato finale.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/06` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/06
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q7 - Blue/green

Percorso: `~/course-argo-rollouts/07`.

1. Completa `07/rollout.yaml` con Service active e preview, promozione manuale
   e `scaleDownDelaySeconds: 30`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/07` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 07/rollout.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/07
kubectl apply -f 07/rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q8 - Preview verification

Percorso: `~/course-argo-rollouts/08`.

1. Avvia v2 e verifica che preview esponga v2 mentre active resta su v1.

2. Salva selector e endpoint in `08/evidence.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/08` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/08
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q9 - Blue/green promotion

Percorso: `~/course-argo-rollouts/09`.

1. Promuovi v2 e verifica lo switch atomico dell'active Service e il ritardo
   prima dello scale-down del vecchio ReplicaSet.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/09` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/09
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q10 - Pre-promotion analysis

Percorso: `~/course-argo-rollouts/10`.

1. Collega `10/analysis-template.yaml` come prePromotionAnalysis.

2. Una verifica riuscita deve consentire la promozione.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 10/analysis-template.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/10
kubectl apply -f 10/analysis-template.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - Post-promotion analysis

Percorso: `~/course-argo-rollouts/11`.

1. Configura una postPromotionAnalysis che fallisce per v3 e verifica rollback
   o stato degradato senza perdita del Service active.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/11` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/11
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q12 - Background analysis

Percorso: `~/course-argo-rollouts/12`.

1. Nel canary, avvia l'analisi dalla soglia del 20% e termina l'AnalysisRun
   alla fine dell'update.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/12` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/12
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Metric success condition

Percorso: `~/course-argo-rollouts/13`.

1. Completa il job provider nell'AnalysisTemplate: `successCondition` deve
   accettare risultato `0`, con tre misurazioni e failure limit 1.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/13` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/13
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - Analysis arguments

Percorso: `~/course-argo-rollouts/14`.

1. Passa `service-name` e `target-version` dal Rollout all'AnalysisTemplate.

2. Verifica gli argomenti nell'AnalysisRun generato.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/14` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/14
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Inconclusive e retry

Percorso: `~/course-argo-rollouts/15`.

1. Configura metriche con `inconclusiveLimit`, `failureLimit` e intervallo.

2. Riproduci uno stato inconclusive e documenta il comportamento.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/15` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/15
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q16 - Experiment

Percorso: `~/course-argo-rollouts/16`.

1. Completa `16/experiment.yaml` con baseline e canary, una replica ciascuno e
   durata due minuti.

2. Verifica ReplicaSet e AnalysisRun associati.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/16` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 16/experiment.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/16
kubectl apply -f 16/experiment.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - Anti-affinity

Percorso: `~/course-argo-rollouts/17`.

1. Configura anti-affinity tra pod canary e stable e verifica la distribuzione
   sui nodi disponibili senza rendere impossibile lo scheduling su kind.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/17` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/17
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q18 - Scale-down controls

Percorso: `~/course-argo-rollouts/18`.

1. Imposta `abortScaleDownDelaySeconds`, `scaleDownDelayRevisionLimit` e
   `dynamicStableScale`.

2. Verifica il numero di pod durante promote e abort.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/18` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/18
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q19 - Troubleshooting

Percorso: `~/course-argo-rollouts/19`.

1. `19/rollout.yaml` ha selector, Service e strategia incoerenti.

2. Riproduci il problema, correggilo e salva condizioni, eventi e causa in
   `19/report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/19` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f 19/rollout.yaml
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/19
kubectl apply -f 19/rollout.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q20 - Simulazione a tempo

Percorso: `~/course-argo-rollouts/20`.

1. Completa una delivery canary con Service stable/canary, step 10/30/60/100,
   pause manuale, background analysis, abort e rollback verificabile.

```bash
kubectl -n argo-rollouts-lab get rollouts,replicasets,services,analysisruns,experiments
kubectl -n argo-rollouts-lab describe rollout final-api
```

2. Salva timeline, selector, metriche e revisioni in `20/final-report.md`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-argo-rollouts/20` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

**Solution**

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-argo-rollouts/20
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```
