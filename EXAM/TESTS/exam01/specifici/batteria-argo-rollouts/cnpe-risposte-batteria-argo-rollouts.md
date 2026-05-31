# CNPE Simulator - Batteria Specifica Argo Rollouts - Risposte
> Guida operativa sintetica | Focus esclusivo: Argo Rollouts

---

## Question 1

1. `kubectl -n argo-rollouts get deploy`
2. `kubectl get crd | grep rollouts.argoproj.io`
3. `kubectl -n argo-rollouts get pods -o wide`

---

## Question 2

1. Converti Deployment in `kind: Rollout` mantenendo labels/selector.
2. `kubectl apply -f rollout.yaml`
3. `kubectl argo rollouts get rollout webapp -n default`

---

## Question 3

1. Configura steps canary nel manifest Rollout.
2. `kubectl set image rollout/webapp web=nginx:1.27 -n default`
3. `kubectl argo rollouts get rollout webapp -n default --watch`

---

## Question 4

1. Inserisci `pause: {}` nello step canary.
2. `kubectl argo rollouts promote webapp -n default`

---

## Question 5

1. Crea `AnalysisTemplate` con provider Prometheus.
2. Referenzia il template in `strategy.canary.analysis`.
3. `kubectl argo rollouts get rollout payments -n default`

---

## Question 6

1. `kubectl argo rollouts abort payments -n default`
2. Verifica stable RS attivo con `kubectl argo rollouts get rollout payments -n default`

---

## Question 7

1. Configura `strategy.blueGreen.activeService` e `previewService`.
2. Verifica selector service con `kubectl get svc -n default -o yaml`.

---

## Question 8

1. Imposta i setWeight richiesti.
2. Verifica history con `kubectl argo rollouts get rollout <name> -n <ns>`.

---

## Question 9

1. Configura `trafficRouting.gatewayAPI.httpRoute` nel Rollout.
2. Verifica traffico durante step canary.

---

## Question 10

1. `kubectl argo rollouts dashboard`
2. Controlla step, RS e pause.

---

## Question 11

1. Crea `Experiment` con template baseline/canary.
2. Applica manifest e verifica stato con `kubectl get experiment -A`.

---

## Question 12

1. Configura trigger su eventi rollout.
2. Verifica notifiche su progressing/completed/degraded.

---

## Question 13

1. Aggiungi `podAntiAffinity` al template.
2. Imposta `maxSurge` e `maxUnavailable`.

---

## Question 14

1. Imposta `progressDeadlineSeconds`.
2. Controlla eventi con `kubectl describe rollout <name> -n <ns>`.

---

## Question 15

1. `kubectl argo rollouts pause inventory -n default`
2. `kubectl argo rollouts retry inventory -n default`

---

## Question 16

1. Associa HPA al Rollout.
2. Verifica targetRef e scaling durante update.

---

## Question 17

1. Commit Git su `/course/17/rollouts-git`.
2. Verifica riconciliazione GitOps.

---

## Question 18

1. Adegua securityContext a restricted.
2. Verifica policy compliance e rollout completo.

---

## Question 19

1. Diagnosi con describe/events/logs.
2. Fix minimo e verifica stato completed.

---

## Question 20

1. Esegui pipeline canary completa con analysis.
2. Valida gate metriche e promozione finale.

---
