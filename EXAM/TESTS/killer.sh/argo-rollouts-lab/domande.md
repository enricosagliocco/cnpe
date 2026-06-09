# Le 20 domande dell'esame - Argo Rollouts Lab

Scenario creato da `setup-argo-rollouts-lab.sh`. Gli starter sono in
`~/course-argo-rollouts/` e le risorse nel Namespace `argo-rollouts-lab`.

**Vincolo:** non modificare il controller o le CRD. Conserva i selector dei
Service e usa Rollout, AnalysisTemplate, AnalysisRun ed Experiment.

---

### Q1 - Rollout base

Completa `01/rollout.yaml` con selector e pod labels coerenti. Applica e
verifica `Healthy` con tre repliche.

### Q2 - Canary steps

Configura in `02/rollout.yaml` peso 20%, pausa 10 secondi, peso 50%, pausa
manuale e peso 100%.

### Q3 - Stable e canary Service

Collega `canary-stable` e `canary-preview` al Rollout. Durante un update
verifica gli hash aggiunti ai selector.

### Q4 - Promozione manuale

Avvia v2, attendi la pausa manuale, esegui promote e salva ReplicaSet, step e
revisioni in `04/evidence.txt`.

### Q5 - Abort

Avvia una revisione con immagine inesistente, osserva il degrado, esegui abort
e verifica che il Service stabile continui a servire la revisione precedente.

### Q6 - Undo

Completa un update a v2, avvia v3 e usa undo verso la revisione precedente.
Documenta immagini, revisioni e stato finale.

### Q7 - Blue/green

Completa `07/rollout.yaml` con Service active e preview, promozione manuale e
`scaleDownDelaySeconds: 30`.

### Q8 - Preview verification

Avvia v2 e verifica che preview esponga v2 mentre active resta su v1. Salva
selector e endpoint in `08/evidence.txt`.

### Q9 - Blue/green promotion

Promuovi v2 e verifica lo switch atomico dell'active Service e il ritardo
prima dello scale-down del vecchio ReplicaSet.

### Q10 - Pre-promotion analysis

Collega `10/analysis-template.yaml` come prePromotionAnalysis. Una verifica
riuscita deve consentire la promozione.

### Q11 - Post-promotion analysis

Configura una postPromotionAnalysis che fallisce per v3 e verifica rollback o
stato degradato senza perdita del Service active.

### Q12 - Background analysis

Nel canary, avvia l'analisi dalla soglia del 20% e termina l'AnalysisRun alla
fine dell'update.

### Q13 - Metric success condition

Completa il job provider nell'AnalysisTemplate: `successCondition` deve
accettare risultato `0`, con tre misurazioni e failure limit 1.

### Q14 - Analysis arguments

Passa `service-name` e `target-version` dal Rollout all'AnalysisTemplate.
Verifica gli argomenti nell'AnalysisRun generato.

### Q15 - Inconclusive e retry

Configura metriche con `inconclusiveLimit`, `failureLimit` e intervallo.
Riproduci uno stato inconclusive e documenta il comportamento.

### Q16 - Experiment

Completa `16/experiment.yaml` con baseline e canary, una replica ciascuno e
durata due minuti. Verifica ReplicaSet e AnalysisRun associati.

### Q17 - Anti-affinity

Configura anti-affinity tra pod canary e stable e verifica la distribuzione
sui nodi disponibili senza rendere impossibile lo scheduling su kind.

### Q18 - Scale-down controls

Imposta `abortScaleDownDelaySeconds`, `scaleDownDelayRevisionLimit` e
`dynamicStableScale`. Verifica il numero di pod durante promote e abort.

### Q19 - Troubleshooting

`19/rollout.yaml` ha selector, Service e strategia incoerenti. Riproduci il
problema, correggilo e salva condizioni, eventi e causa in `19/report.md`.

### Q20 - Simulazione a tempo

Completa una delivery canary con Service stable/canary, step 10/30/60/100,
pause manuale, background analysis, abort e rollback verificabile.

```bash
kubectl -n argo-rollouts-lab get rollouts,replicasets,services,analysisruns,experiments
kubectl -n argo-rollouts-lab describe rollout final-api
```

Salva timeline, selector, metriche e revisioni in `20/final-report.md`.
