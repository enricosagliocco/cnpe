# CNPE Simulator - Batteria Specifica Argo Rollouts - Domande
> Killer Shell style | Kubernetes 1.35 | Focus esclusivo: Argo Rollouts

---

## Indice delle Domande

| Q 1 | Installazione e stato controller Rollouts |
| Q 2 | Migrazione Deployment -> Rollout |
| Q 3 | Strategia Canary base |
| Q 4 | Pause e promozione manuale |
| Q 5 | AnalysisTemplate con Prometheus |
| Q 6 | Abort e rollback |
| Q 7 | Blue/Green e Service switching |
| Q 8 | setWeight progressivo |
| Q 9 | Canary con traffico HTTPRoute |
| Q10 | Dashboard plugin kubectl-argo-rollouts |
| Q11 | Experiment e comparative analysis |
| Q12 | Notification trigger |
| Q13 | Anti-affinity e surge tuning |
| Q14 | ProgressDeadline e failure handling |
| Q15 | Pause conditions e retry |
| Q16 | Autoscaling interplay (HPA + Rollout) |
| Q17 | GitOps sync behavior con Rollouts |
| Q18 | Security context e policy compliance |
| Q19 | Troubleshooting stuck rollout |
| Q20 | End-to-end canary con metric gates |

---

## Question 1 | Installazione e stato controller Rollouts

> Instance: `ssh cnpe-ar01`

1. Verifica che il controller Argo Rollouts sia installato nel namespace argo-rollouts.
2. Verifica CRD, Deployment controller e stato Pod Ready.
3. Salva evidenze in /course/1/ar-rollouts-controller.txt.

---

## Question 2 | Migrazione Deployment -> Rollout

> Instance: `ssh cnpe-ar02`

1. Converti il Deployment webapp in una risorsa Rollout mantenendo selector e template.
2. Imposta replicas=3 e strategy canary.
3. Applica e verifica lo stato con kubectl argo rollouts get rollout.
4. Salva YAML finale in /course/2/rollout-migrated.yaml.

---

## Question 3 | Strategia Canary base

> Instance: `ssh cnpe-ar03`

1. Configura steps: setWeight 20, pause 30s, setWeight 50, pause 30s, setWeight 100.
2. Aggiorna immagine container a nginx:1.27.
3. Verifica avanzamento e completa il rollout.
4. Salva output stato in /course/3/canary-basic.txt.

---

## Question 4 | Pause e promozione manuale

> Instance: `ssh cnpe-ar04`

1. Inserisci una pausa manuale nella strategia canary dopo il primo step.
2. Triggera un aggiornamento immagine e lascia il rollout in Paused.
3. Esegui promozione manuale e verifica il completamento.
4. Salva evidenza comandi in /course/4/manual-promotion.txt.

---

## Question 5 | AnalysisTemplate con Prometheus

> Instance: `ssh cnpe-ar05`

1. Crea AnalysisTemplate che controlli error-rate < 2% tramite query Prometheus.
2. Collega l'analysis alla strategia canary del Rollout payments.
3. Esegui rollout e verifica che l'analysis venga valutata.
4. Salva template e risultato in /course/5/analysis-prometheus.yaml.

---

## Question 6 | Abort e rollback

> Instance: `ssh cnpe-ar06`

1. Simula failure metric durante canary e forza stato Degraded.
2. Esegui abort del rollout.
3. Verifica che il traffico torni completamente alla versione stable.
4. Salva evidenza in /course/6/abort-rollback.txt.

---

## Question 7 | Blue/Green e Service switching

> Instance: `ssh cnpe-ar07`

1. Configura Rollout in modalità blueGreen con activeService e previewService.
2. Esegui update immagine.
3. Verifica switch corretto dei Service selectors.
4. Salva output in /course/7/bluegreen-services.txt.

---

## Question 8 | setWeight progressivo

> Instance: `ssh cnpe-ar08`

1. Definisci una progressione setWeight: 5, 15, 35, 60, 100.
2. Inserisci pause di 10s tra ogni step.
3. Verifica history del rollout.
4. Salva risultato in /course/8/progressive-weights.txt.

---

## Question 9 | Canary con traffico HTTPRoute

> Instance: `ssh cnpe-ar09`

1. Configura trafficRouting con Gateway API HTTPRoute.
2. Associa il Rollout checkout alla route esistente.
3. Verifica la distribuzione traffico durante i passaggi canary.
4. Salva evidenza in /course/9/httproute-canary.txt.

---

## Question 10 | Dashboard plugin kubectl-argo-rollouts

> Instance: `ssh cnpe-ar10`

1. Usa kubectl argo rollouts dashboard per ispezionare rollout orders.
2. Verifica stato step, pause conditions e replica sets.
3. Esporta uno screenshot o descrizione tecnica in /course/10/dashboard-report.md.

---

## Question 11 | Experiment e comparative analysis

> Instance: `ssh cnpe-ar11`

1. Crea un Experiment con baseline e canary templates.
2. Esegui test comparativo su latenza (mock o metrica disponibile).
3. Salva manifest e risultato in /course/11/experiment.yaml.

---

## Question 12 | Notification trigger

> Instance: `ssh cnpe-ar12`

1. Configura trigger notification su eventi Rollout (progressing, completed, degraded).
2. Collega almeno un notifier disponibile.
3. Verifica invocazione trigger durante update.
4. Salva evidenza in /course/12/notifications.txt.

---

## Question 13 | Anti-affinity e surge tuning

> Instance: `ssh cnpe-ar13`

1. Aggiorna il template Pod del Rollout api con podAntiAffinity preferita.
2. Configura maxSurge=1 e maxUnavailable=0.
3. Verifica scheduling e comportamento rollout.
4. Salva output in /course/13/surge-affinity.txt.

---

## Question 14 | ProgressDeadline e failure handling

> Instance: `ssh cnpe-ar14`

1. Imposta progressDeadlineSeconds=120.
2. Introduci una condizione che blocchi la progressione.
3. Verifica timeout e stato failure.
4. Salva eventi e descrizione in /course/14/progress-deadline.txt.

---

## Question 15 | Pause conditions e retry

> Instance: `ssh cnpe-ar15`

1. Metti il rollout inventory in pausa tramite comando CLI.
2. Riprendi con retry e verifica che riparta dallo step corretto.
3. Salva stato prima/dopo in /course/15/pause-retry.txt.

---

## Question 16 | Autoscaling interplay (HPA + Rollout)

> Instance: `ssh cnpe-ar16`

1. Associa HPA al Rollout search.
2. Verifica scaling behavior durante una release canary.
3. Assicurati che non ci siano conflitti tra replicas desired e HPA decisions.
4. Salva evidenza in /course/16/hpa-rollout.txt.

---

## Question 17 | GitOps sync behavior con Rollouts

> Instance: `ssh cnpe-ar17`

1. Versiona il manifest Rollout in repository Git locale /course/17/rollouts-git.
2. Esegui una modifica canary e commit su main.
3. Verifica sync con controller GitOps installato.
4. Salva log e commit id in /course/17/gitops-rollout.txt.

---

## Question 18 | Security context e policy compliance

> Instance: `ssh cnpe-ar18`

1. Adegua il Rollout worker ai requisiti Pod Security restricted.
2. Verifica compliance policy (Kyverno/Gatekeeper se presenti).
3. Applica update e verifica che il rollout completi senza violazioni.
4. Salva evidenza in /course/18/security-compliance.txt.

---

## Question 19 | Troubleshooting stuck rollout

> Instance: `ssh cnpe-ar19`

1. Individua la causa di un rollout bloccato in Progressing.
2. Risolvi il problema con il fix minimo.
3. Verifica stato Healthy/Completed.
4. Scrivi root cause e fix in /course/19/troubleshooting.md.

---

## Question 20 | End-to-end canary con metric gates

> Instance: `ssh cnpe-ar20`

1. Implementa una pipeline completa: update immagine + canary + analysis metriche + promozione.
2. Definisci gate su success-rate e latency.
3. Esegui il rollout end-to-end e verifica outcome.
4. Salva report finale in /course/20/e2e-canary-report.md.

---
