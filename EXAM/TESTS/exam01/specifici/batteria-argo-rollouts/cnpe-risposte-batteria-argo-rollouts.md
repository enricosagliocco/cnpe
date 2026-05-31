# CNPE Simulator - Batteria Specifica Argo Rollouts - Risposte Guida
> Guida operativa sintetica | Focus: task pratici stile esame

---

## Regole pratiche consigliate

1. Prima verifica stato attuale (get/describe/events).
2. Applica solo il delta minimo richiesto.
3. Conferma risultato con kubectl argo rollouts get rollout.
4. Salva output in /course/<q>/... come richiesto.

---

## Question 1

```bash
kubectl get ns argo-rollouts
kubectl get crd rollouts.argoproj.io
kubectl -n argo-rollouts get deploy,pods
kubectl argo rollouts version
{
  kubectl get ns argo-rollouts
  kubectl get crd rollouts.argoproj.io
  kubectl -n argo-rollouts get deploy,pods
  kubectl argo rollouts version
} > /course/1/controller-check.txt
```

---

## Question 2

```bash
cp /course/2/webapp-deployment.yaml /course/2/rollout-migrated.yaml
# Modifica: kind Rollout, apiVersion argoproj.io/v1alpha1, replicas 3, strategy.canary.steps
kubectl apply -f /course/2/rollout-migrated.yaml
kubectl argo rollouts get rollout webapp -n rollouts-lab
```

---

## Question 3

```bash
kubectl -n rollouts-lab edit rollout payments
# steps:
# - setWeight: 20
# - pause: {duration: 15s}
# - setWeight: 50
# - pause: {duration: 15s}
# - setWeight: 100
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27
kubectl argo rollouts -n rollouts-lab get rollout payments -w
kubectl argo rollouts -n rollouts-lab get rollout payments > /course/3/canary-basic.txt
```

---

## Question 4

```bash
kubectl -n rollouts-lab edit rollout payments
# aggiungi uno step: - pause: {}
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27.1
kubectl argo rollouts -n rollouts-lab get rollout payments > /course/4/manual-promotion.txt
kubectl argo rollouts -n rollouts-lab promote payments
kubectl argo rollouts -n rollouts-lab get rollout payments >> /course/4/manual-promotion.txt
```

---

## Question 5

```bash
kubectl apply -f /course/5/analysis-template-job.yaml
kubectl -n rollouts-lab edit rollout payments
# aggiungi uno step:
# - analysis:
#     templates:
#     - templateName: success-job
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27.2
kubectl -n rollouts-lab get analysisrun
cp /course/5/analysis-template-job.yaml /course/5/analysis-template-job-final.yaml
```

---

## Question 6

```bash
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:not-a-real-tag
kubectl argo rollouts -n rollouts-lab get rollout payments -w --timeout-seconds 60 || true
kubectl argo rollouts -n rollouts-lab abort payments
kubectl argo rollouts -n rollouts-lab undo payments
{
  kubectl argo rollouts -n rollouts-lab get rollout payments
  kubectl -n rollouts-lab get rs
} > /course/6/abort-undo.txt
```

---

## Question 7

```bash
kubectl argo rollouts -n rollouts-lab get rollout checkout
kubectl argo rollouts -n rollouts-lab set image checkout app=nginx:1.27
kubectl -n rollouts-lab get svc checkout-active checkout-preview -o wide > /course/7/bluegreen-services.txt
kubectl argo rollouts -n rollouts-lab promote checkout
kubectl -n rollouts-lab get svc checkout-active checkout-preview -o wide >> /course/7/bluegreen-services.txt
```

---

## Question 8

```bash
kubectl argo rollouts -n rollouts-lab set image inventory app=nginx:1.27
{
  kubectl argo rollouts -n rollouts-lab get rollout inventory
  kubectl -n rollouts-lab get rs -l app=inventory
} > /course/8/set-image-history.txt
```

---

## Question 9

```bash
kubectl argo rollouts -n rollouts-lab set image inventory app=nginx:broken
kubectl argo rollouts -n rollouts-lab get rollout inventory -w --timeout-seconds 60 || true
kubectl argo rollouts -n rollouts-lab set image inventory app=nginx:1.27
kubectl argo rollouts -n rollouts-lab retry inventory
kubectl argo rollouts -n rollouts-lab get rollout inventory > /course/9/retry.txt
```

---

## Question 10

```bash
kubectl -n rollouts-lab patch rollout inventory --type='merge' -p '{"spec":{"rollbackWindow":{"revisions":3}}}'
kubectl argo rollouts -n rollouts-lab set image inventory app=nginx:1.27.1
kubectl argo rollouts -n rollouts-lab promote inventory
kubectl argo rollouts -n rollouts-lab set image inventory app=nginx:1.27.2
kubectl argo rollouts -n rollouts-lab promote inventory
{
  kubectl argo rollouts -n rollouts-lab get rollout inventory
  kubectl -n rollouts-lab get rs -l app=inventory
} > /course/10/rollback-window.txt
```

---

## Question 11

```bash
kubectl -n rollouts-lab edit rollout payments
# strategy.canary.maxSurge: 1
# strategy.canary.maxUnavailable: 0
# strategy.canary.antiAffinity.preferredDuringSchedulingIgnoredDuringExecution.weight: 50
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27.3
{
  kubectl argo rollouts -n rollouts-lab get rollout payments
  kubectl -n rollouts-lab get pods -o wide
} > /course/11/surge-unavailable-affinity.txt
```

---

## Question 12

```bash
kubectl -n rollouts-lab patch rollout payments --type='merge' -p '{"spec":{"progressDeadlineSeconds":90,"progressDeadlineAbort":true}}'
# Introduci una condizione bloccante (es. immagine non valida)
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:nope
{
  kubectl argo rollouts -n rollouts-lab get rollout payments
  kubectl -n rollouts-lab describe rollout payments
  kubectl -n rollouts-lab get events --sort-by=.lastTimestamp | tail -n 30
} > /course/12/progress-deadline.txt
```

---

## Question 13

```bash
kubectl argo rollouts -n rollouts-lab pause search
kubectl argo rollouts -n rollouts-lab get rollout search > /course/13/pause-resume.txt
kubectl argo rollouts -n rollouts-lab resume search
kubectl argo rollouts -n rollouts-lab get rollout search >> /course/13/pause-resume.txt
```

---

## Question 14

```bash
kubectl -n rollouts-lab autoscale rollout search --cpu-percent=70 --min=2 --max=5
{
  kubectl -n rollouts-lab get hpa
  kubectl -n rollouts-lab describe hpa search
} > /course/14/hpa-rollout.txt
```

---

## Question 15

```bash
kubectl argo rollouts -n rollouts-lab get rollout payments -w --timeout-seconds 60 > /course/15/get-rollout-timeout.txt || true
```

---

## Question 16

```bash
kubectl argo rollouts -n rollouts-lab restart inventory
{
  kubectl argo rollouts -n rollouts-lab get rollout inventory
  kubectl -n rollouts-lab get rollout inventory -o yaml | grep -n restartAt || true
} > /course/16/restart.txt
```

---

## Question 17

```bash
kubectl -n rollouts-lab edit rollout payments
# aggiungi uno step experiment con baseline/canary
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27.4
{
  kubectl -n rollouts-lab get experiment
  kubectl argo rollouts -n rollouts-lab get rollout payments
} > /course/17/experiment.txt
```

---

## Question 18

```bash
kubectl argo rollouts -n rollouts-lab get rollout stuck-app
kubectl -n rollouts-lab describe rollout stuck-app
kubectl -n rollouts-lab get events --sort-by=.lastTimestamp | tail -n 40
# applica fix minimo (es. immagine valida o resume da pausa)
kubectl argo rollouts -n rollouts-lab set image stuck-app app=nginx:1.27
kubectl argo rollouts -n rollouts-lab promote stuck-app
kubectl argo rollouts -n rollouts-lab get rollout stuck-app > /course/18/troubleshooting.md
```

---

## Question 19

```bash
kubectl argo rollouts -n rollouts-lab set image payments app=nginx:1.27.5
kubectl -n rollouts-lab get analysisrun
kubectl argo rollouts -n rollouts-lab promote payments
{
  kubectl argo rollouts -n rollouts-lab get rollout payments
  kubectl -n rollouts-lab get analysisrun
} > /course/19/e2e-canary-gate.txt
```

---

## Question 20

```bash
{
  kubectl argo rollouts -n rollouts-lab get rollout payments
  kubectl argo rollouts -n rollouts-lab get rollout checkout
  kubectl argo rollouts -n rollouts-lab get rollout inventory
  kubectl argo rollouts -n rollouts-lab get rollout search
  kubectl -n rollouts-lab get rs
  kubectl -n rollouts-lab get analysisrun
} > /course/20/final-report.txt
```

---

## Riferimenti verificati online

- https://argo-rollouts.readthedocs.io/en/stable/installation/
- https://argo-rollouts.readthedocs.io/en/stable/features/specification/
- https://argo-rollouts.readthedocs.io/en/stable/generated/kubectl-argo-rollouts/kubectl-argo-rollouts_get_rollout/
