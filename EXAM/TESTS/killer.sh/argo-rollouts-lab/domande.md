# Le 20 domande dell'esame - Argo Rollouts Lab (simulatore lab)

Scenario creato da `setup-argo-rollouts-lab.sh`. Gli starter sono in
`~/course-argo-rollouts/` e le risorse nel Namespace `argo-rollouts-lab`.

**Vincolo:** non modificare il controller o le CRD. Conserva i selector dei
Service e usa Rollout, AnalysisTemplate, AnalysisRun ed Experiment.

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

### Q2 - Canary steps

Percorso: `~/course-argo-rollouts/02`.

1. Configura in `02/rollout.yaml` peso 20%, pausa 10 secondi, peso 50%, pausa
   manuale e peso 100%.

### Q3 - Stable e canary Service

Percorso: `~/course-argo-rollouts/03`.

1. Collega `canary-stable` e `canary-preview` al Rollout.

2. Durante un update verifica gli hash aggiunti ai selector.

### Q4 - Promozione manuale

Percorso: `~/course-argo-rollouts/04`.

1. Avvia v2, attendi la pausa manuale, esegui promote e salva ReplicaSet, step
   e revisioni in `04/evidence.txt`.

### Q5 - Abort

Percorso: `~/course-argo-rollouts/05`.

1. Avvia una revisione con immagine inesistente, osserva il degrado, esegui
   abort e verifica che il Service stabile continui a servire la revisione
   precedente.

### Q6 - Undo

Percorso: `~/course-argo-rollouts/06`.

1. Completa un update a v2, avvia v3 e usa undo verso la revisione precedente.

2. Documenta immagini, revisioni e stato finale.

### Q7 - Blue/green

Percorso: `~/course-argo-rollouts/07`.

1. Completa `07/rollout.yaml` con Service active e preview, promozione manuale
   e `scaleDownDelaySeconds: 30`.

### Q8 - Preview verification

Percorso: `~/course-argo-rollouts/08`.

1. Avvia v2 e verifica che preview esponga v2 mentre active resta su v1.

2. Salva selector e endpoint in `08/evidence.txt`.

### Q9 - Blue/green promotion

Percorso: `~/course-argo-rollouts/09`.

1. Promuovi v2 e verifica lo switch atomico dell'active Service e il ritardo
   prima dello scale-down del vecchio ReplicaSet.

### Q10 - Pre-promotion analysis

Percorso: `~/course-argo-rollouts/10`.

1. Collega `10/analysis-template.yaml` come prePromotionAnalysis.

2. Una verifica riuscita deve consentire la promozione.

### Q11 - Post-promotion analysis

Percorso: `~/course-argo-rollouts/11`.

1. Configura una postPromotionAnalysis che fallisce per v3 e verifica rollback
   o stato degradato senza perdita del Service active.

### Q12 - Background analysis

Percorso: `~/course-argo-rollouts/12`.

1. Nel canary, avvia l'analisi dalla soglia del 20% e termina l'AnalysisRun
   alla fine dell'update.

### Q13 - Metric success condition

Percorso: `~/course-argo-rollouts/13`.

1. Completa il job provider nell'AnalysisTemplate: `successCondition` deve
   accettare risultato `0`, con tre misurazioni e failure limit 1.

### Q14 - Analysis arguments

Percorso: `~/course-argo-rollouts/14`.

1. Passa `service-name` e `target-version` dal Rollout all'AnalysisTemplate.

2. Verifica gli argomenti nell'AnalysisRun generato.

### Q15 - Inconclusive e retry

Percorso: `~/course-argo-rollouts/15`.

1. Configura metriche con `inconclusiveLimit`, `failureLimit` e intervallo.

2. Riproduci uno stato inconclusive e documenta il comportamento.

### Q16 - Experiment

Percorso: `~/course-argo-rollouts/16`.

1. Completa `16/experiment.yaml` con baseline e canary, una replica ciascuno e
   durata due minuti.

2. Verifica ReplicaSet e AnalysisRun associati.

### Q17 - Anti-affinity

Percorso: `~/course-argo-rollouts/17`.

1. Configura anti-affinity tra pod canary e stable e verifica la distribuzione
   sui nodi disponibili senza rendere impossibile lo scheduling su kind.

### Q18 - Scale-down controls

Percorso: `~/course-argo-rollouts/18`.

1. Imposta `abortScaleDownDelaySeconds`, `scaleDownDelayRevisionLimit` e
   `dynamicStableScale`.

2. Verifica il numero di pod durante promote e abort.

### Q19 - Troubleshooting

Percorso: `~/course-argo-rollouts/19`.

1. `19/rollout.yaml` ha selector, Service e strategia incoerenti.

2. Riproduci il problema, correggilo e salva condizioni, eventi e causa in
   `19/report.md`.

### Q20 - Simulazione a tempo

Percorso: `~/course-argo-rollouts/20`.

1. Completa una delivery canary con Service stable/canary, step 10/30/60/100,
   pause manuale, background analysis, abort e rollback verificabile.

```bash
kubectl -n argo-rollouts-lab get rollouts,replicasets,services,analysisruns,experiments
kubectl -n argo-rollouts-lab describe rollout final-api
```

2. Salva timeline, selector, metriche e revisioni in `20/final-report.md`.
