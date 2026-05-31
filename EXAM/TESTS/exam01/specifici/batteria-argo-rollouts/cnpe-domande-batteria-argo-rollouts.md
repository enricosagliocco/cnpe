# CNPE Simulator - Batteria Specifica Argo Rollouts - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: Progressive Delivery con Argo Rollouts

---

## Nota formato esame

- Ogni domanda richiede modifiche minime e verificabili.
- Usa solo il namespace indicato.
- Salva sempre una evidenza tecnica nel path richiesto sotto /course.
- La batteria e stata allineata ai comandi e ai campi ufficiali Argo Rollouts.

---

## Indice delle Domande

| Q 1 | Installazione controller e plugin |
| Q 2 | Migrazione Deployment -> Rollout |
| Q 3 | Canary steps base |
| Q 4 | Pausa manuale e promozione |
| Q 5 | AnalysisTemplate (job) |
| Q 6 | Abort e undo |
| Q 7 | Blue/Green con active/preview service |
| Q 8 | Set image e history |
| Q 9 | Retry dopo failure |
| Q10 | Rollback window |
| Q11 | maxSurge, maxUnavailable, anti-affinity |
| Q12 | progressDeadlineSeconds e abort |
| Q13 | Pause/Resume via CLI |
| Q14 | HPA su Rollout |
| Q15 | Plugin get rollout e timeout |
| Q16 | Restart controllato |
| Q17 | Experiment step |
| Q18 | Troubleshooting rollout bloccato |
| Q19 | Canary end-to-end con gate |
| Q20 | Checklist finale e raccolta evidenze |

---

## Question 1 | Installazione controller e plugin

> Instance: `ssh cnpe-ar01`

1. Verifica che il namespace argo-rollouts esista.
2. Verifica CRD rollouts.argoproj.io e deployment controller Ready.
3. Verifica che il plugin kubectl argo rollouts sia disponibile.
4. Salva output comandi in /course/1/controller-check.txt.

---

## Question 2 | Migrazione Deployment -> Rollout

> Instance: `ssh cnpe-ar02`

Namespace: rollouts-lab
File iniziale: /course/2/webapp-deployment.yaml

1. Converti il Deployment webapp in kind Rollout.
2. Mantieni selector e pod template.
3. Imposta replicas=3 e strategia canary con almeno due step.
4. Applica il manifest e salva il risultato in /course/2/rollout-migrated.yaml.

---

## Question 3 | Canary steps base

> Instance: `ssh cnpe-ar03`

Rollout: payments (namespace rollouts-lab)

1. Configura steps: setWeight 20, pausa 15s, setWeight 50, pausa 15s, setWeight 100.
2. Aggiorna immagine del container app a nginx:1.27.
3. Verifica avanzamento con watch.
4. Salva evidenza in /course/3/canary-basic.txt.

---

## Question 4 | Pausa manuale e promozione

> Instance: `ssh cnpe-ar04`

Rollout: payments (namespace rollouts-lab)

1. Inserisci una pausa indefinita nella strategia canary (pause: {}).
2. Triggera un nuovo update immagine.
3. Lascia il rollout in Paused e poi promuovilo manualmente.
4. Salva stato prima/dopo in /course/4/manual-promotion.txt.

---

## Question 5 | AnalysisTemplate (job)

> Instance: `ssh cnpe-ar05`

Namespace: rollouts-lab
Starter: /course/5/analysis-template-job.yaml

1. Completa AnalysisTemplate in modo che il job termini con exit 0.
2. Collega il template al rollout payments come step analysis.
3. Esegui un update immagine e verifica creazione AnalysisRun.
4. Salva manifest finale in /course/5/analysis-template-job-final.yaml.

---

## Question 6 | Abort e undo

> Instance: `ssh cnpe-ar06`

Rollout: payments (namespace rollouts-lab)

1. Imposta una immagine volutamente errata per portare il rollout in errore.
2. Esegui abort del rollout.
3. Ripristina versione precedente con undo.
4. Salva evidenze in /course/6/abort-undo.txt.

---

## Question 7 | Blue/Green con active/preview service

> Instance: `ssh cnpe-ar07`

Rollout: checkout (namespace rollouts-lab)

1. Verifica che activeService e previewService siano configurati.
2. Aggiorna immagine e controlla che il preview service punti alla nuova revisione.
3. Promuovi il rollout e verifica lo switch dell active service.
4. Salva output in /course/7/bluegreen-services.txt.

---

## Question 8 | Set image e history

> Instance: `ssh cnpe-ar08`

Rollout: inventory (namespace rollouts-lab)

1. Usa kubectl argo rollouts set image per aggiornare il container app.
2. Verifica revision e replicaSets generate.
3. Salva stato e revision in /course/8/set-image-history.txt.

---

## Question 9 | Retry dopo failure

> Instance: `ssh cnpe-ar09`

Rollout: inventory (namespace rollouts-lab)

1. Introduci un errore transitorio (esempio immagine non valida).
2. Correggi il manifest/immagine.
3. Usa retry per riprendere il rollout.
4. Salva output in /course/9/retry.txt.

---

## Question 10 | Rollback window

> Instance: `ssh cnpe-ar10`

Rollout: inventory (namespace rollouts-lab)

1. Imposta rollbackWindow.revisions a 3.
2. Esegui almeno due update immagine validi.
3. Verifica revisionHistory mantenuta.
4. Salva evidenze in /course/10/rollback-window.txt.

---

## Question 11 | maxSurge, maxUnavailable, anti-affinity

> Instance: `ssh cnpe-ar11`

Rollout: payments (namespace rollouts-lab)

1. Imposta maxSurge=1 e maxUnavailable=0.
2. Aggiungi antiAffinity preferred tra vecchia e nuova ReplicaSet.
3. Esegui update e verifica scheduling.
4. Salva risultato in /course/11/surge-unavailable-affinity.txt.

---

## Question 12 | progressDeadlineSeconds e abort

> Instance: `ssh cnpe-ar12`

Rollout: payments (namespace rollouts-lab)

1. Imposta progressDeadlineSeconds=90.
2. Abilita progressDeadlineAbort=true.
3. Simula una condizione che blocchi la progressione.
4. Salva events e status in /course/12/progress-deadline.txt.

---

## Question 13 | Pause/Resume via CLI

> Instance: `ssh cnpe-ar13`

Rollout: search (namespace rollouts-lab)

1. Metti in pausa con CLI.
2. Verifica pauseConditions nello status.
3. Riprendi e verifica completamento.
4. Salva output in /course/13/pause-resume.txt.

---

## Question 14 | HPA su Rollout

> Instance: `ssh cnpe-ar14`

Rollout: search (namespace rollouts-lab)

1. Crea/aggiorna HPA con targetRef al rollout search.
2. Imposta minReplicas=2 e maxReplicas=5.
3. Verifica che HPA legga metriche e target corretto.
4. Salva in /course/14/hpa-rollout.txt.

---

## Question 15 | Plugin get rollout e timeout

> Instance: `ssh cnpe-ar15`

Rollout: payments (namespace rollouts-lab)

1. Usa kubectl argo rollouts get rollout payments -w --timeout-seconds 60.
2. Interrompi in sicurezza il watch dopo aver ottenuto output utile.
3. Salva output in /course/15/get-rollout-timeout.txt.

---

## Question 16 | Restart controllato

> Instance: `ssh cnpe-ar16`

Rollout: inventory (namespace rollouts-lab)

1. Esegui restart del rollout.
2. Verifica restartAt e rotazione pod.
3. Salva evidenza in /course/16/restart.txt.

---

## Question 17 | Experiment step

> Instance: `ssh cnpe-ar17`

Rollout: payments (namespace rollouts-lab)

1. Inserisci uno step experiment nella canary strategy.
2. Definisci template baseline e canary con durata breve.
3. Esegui update e verifica risorsa Experiment.
4. Salva output in /course/17/experiment.txt.

---

## Question 18 | Troubleshooting rollout bloccato

> Instance: `ssh cnpe-ar18`

Rollout: stuck-app (namespace rollouts-lab)

1. Identifica la causa del blocco con describe/events/get rollout.
2. Applica il fix minimo per completare il rollout.
3. Conferma stato Healthy/Completed.
4. Scrivi root cause e fix in /course/18/troubleshooting.md.

---

## Question 19 | Canary end-to-end con gate

> Instance: `ssh cnpe-ar19`

Rollout: payments (namespace rollouts-lab)

1. Applica update immagine.
2. Esegui avanzamento canary con gate analysis configurato.
3. Promuovi solo dopo analysis positiva.
4. Salva report in /course/19/e2e-canary-gate.txt.

---

## Question 20 | Checklist finale e raccolta evidenze

> Instance: `ssh cnpe-ar20`

1. Verifica che i rollout payments, checkout, inventory, search siano Healthy.
2. Esporta elenco rollout, replicasets e analysisrun del namespace rollouts-lab.
3. Salva report finale in /course/20/final-report.txt.

---

## Verifica online utilizzata per questa batteria

- https://argo-rollouts.readthedocs.io/en/stable/installation/
- https://argo-rollouts.readthedocs.io/en/stable/features/specification/
- https://argo-rollouts.readthedocs.io/en/stable/generated/kubectl-argo-rollouts/kubectl-argo-rollouts_get_rollout/
