# CNPE Hard Lab — Argo Rollouts

## Avvio

```bash
chmod +x setup-argo-rollouts-hard.sh
./setup-argo-rollouts-hard.sh
```

## Cleanup

```bash
./setup-argo-rollouts-hard.sh --cleanup
```

## Namespace

```text
argo-rollouts
rollouts-lab
```

## File

```text
/course/argo-rollouts-hard/00-services.yaml
/course/argo-rollouts-hard/10-analysis-broken.yaml
/course/argo-rollouts-hard/20-rollout-broken.yaml
/course/argo-rollouts-hard/30-bad-update.yaml
/course/argo-rollouts-hard/40-good-update.yaml
```

## Focus

Rollout canary, stable/canary service, AnalysisTemplate, AnalysisRun, pause, promote, abort, rollback.
