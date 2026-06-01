# CNPE Specifici - Batteria Dedicata Flagger - Risposte Guida
> Guida operativa sintetica e verificabile

---

## Bootstrap Git da Gitea

> Nota: il bootstrap da Gitea è best-effort; se il server non risponde, il setup salta il seeding remoto e prosegue.

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/2
rm -rf /course/2/repo-flagger
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-flagger-repo.git" /course/2/repo-flagger
```

## Question 1

```bash
{
  kubectl -n flagger-system get deploy,pods
  kubectl get crd canaries.flagger.app
} > /course/1/flagger-install-check.txt
```

## Question 2

```bash
kubectl apply -f /course/2/repo-flagger/apps/podinfo/deploy.yaml
kubectl apply -f /course/2/repo-flagger/apps/podinfo/svc.yaml
kubectl apply -f /course/2/repo-flagger/apps/podinfo/hpa.yaml
kubectl apply -f /course/2/repo-flagger/apps/podinfo/canary.yaml
{
  kubectl -n flagger-lab get deploy,svc,hpa,canary
} > /course/2/flagger-bootstrap.txt
```

## Question 3

```bash
{
  kubectl -n flagger-lab get svc
  kubectl -n flagger-lab get deploy
  kubectl -n flagger-lab get canary podinfo -o yaml
} > /course/3/flagger-generated-resources.txt
```

## Question 4

```bash
kubectl -n flagger-lab set image deployment/podinfo app=ghcr.io/stefanprodan/podinfo:6.6.1
{
  kubectl -n flagger-lab get canary podinfo
  kubectl -n flagger-lab get events --sort-by=.lastTimestamp | tail -n 30
} > /course/4/flagger-progression.txt
```

## Question 5

```bash
kubectl -n flagger-lab patch canary podinfo --type=merge -p '{"spec":{"analysis":{"stepWeight":20,"maxWeight":60}}}'
kubectl -n flagger-lab set image deployment/podinfo app=ghcr.io/stefanprodan/podinfo:6.6.2
kubectl -n flagger-lab get canary podinfo -o yaml > /course/5/flagger-weights.txt
```

## Question 6

```bash
kubectl -n flagger-lab patch canary podinfo --type=merge -p '{"spec":{"analysis":{"metrics":[{"name":"request-success-rate","thresholdRange":{"min":99},"interval":"1m"},{"name":"request-duration","thresholdRange":{"max":300},"interval":"1m"}]}}}'
kubectl -n flagger-lab get canary podinfo -o yaml > /course/6/flagger-analysis-updated.yaml
```

## Question 7

```bash
kubectl -n flagger-lab patch hpa podinfo --type=merge -p '{"spec":{"minReplicas":2,"maxReplicas":6}}'
{
  kubectl -n flagger-lab get hpa podinfo
  kubectl -n flagger-lab describe hpa podinfo
} > /course/7/flagger-hpa.txt
```

## Question 8

```bash
kubectl -n flagger-lab patch canary podinfo --type=merge -p '{"spec":{"analysis":{"webhooks":[{"name":"pre-rollout-check","type":"confirm-rollout","url":"http://flagger-webhook.flagger-system/confirm"}]}}}'
kubectl -n flagger-lab get canary podinfo -o yaml > /course/8/flagger-webhook.yaml
```

## Question 9

```bash
kubectl -n flagger-lab set image deployment/podinfo app=ghcr.io/stefanprodan/podinfo:not-valid
{
  kubectl -n flagger-lab get canary podinfo
  kubectl -n flagger-lab get events --sort-by=.lastTimestamp | tail -n 40
} > /course/9/flagger-rollback.txt
kubectl -n flagger-lab set image deployment/podinfo app=ghcr.io/stefanprodan/podinfo:6.6.1
kubectl -n flagger-lab get canary podinfo >> /course/9/flagger-rollback.txt
```

## Question 10

```bash
kubectl -n flagger-lab patch canary podinfo --type=merge -p '{"spec":{"analysis":{"interval":"10m"}}}'
{
  kubectl -n flagger-lab get canary podinfo
} > /course/10/flagger-pause-resume.txt
kubectl -n flagger-lab patch canary podinfo --type=merge -p '{"spec":{"analysis":{"interval":"30s"}}}'
kubectl -n flagger-lab get canary podinfo >> /course/10/flagger-pause-resume.txt
```

## Question 11

```bash
{
  kubectl -n flagger-lab get events --sort-by=.lastTimestamp
  kubectl -n flagger-system logs deploy/flagger --tail=200
} > /course/11/flagger-troubleshooting.txt
```

## Question 12

```bash
{
  kubectl -n flagger-lab get canary
  kubectl -n flagger-lab get deploy,svc,hpa
} > /course/12/flagger-final-report.txt
```
