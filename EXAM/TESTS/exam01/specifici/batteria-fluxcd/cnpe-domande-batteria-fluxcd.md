# CNPE Specifici - Batteria Dedicata FluxCD - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: GitOps con FluxCD

---

## Git remoto (Gitea)

> Nota: il bootstrap da Gitea è il percorso previsto; se il server non è disponibile, lo setup salta il clone e il laboratorio continua.

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/2 /course/6
rm -rf /course/2/repo-fluxcd-app /course/6/repo-fluxcd-infra
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-app.git" /course/2/repo-fluxcd-app
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-infra.git" /course/6/repo-fluxcd-infra
```

## Indice delle Domande

| Q 1 | Verifica installazione Flux |
| Q 2 | GitRepository da repo applicativo |
| Q 3 | Kustomization per clusters/dev |
| Q 4 | Reconciliazione manuale e drift |
| Q 5 | Sospensione e resume Kustomization |
| Q 6 | Secondo source repo (infra) |
| Q 7 | DependsOn tra Kustomization |
| Q 8 | Prune e cancellazione risorse |
| Q 9 | Health checks e timeout |
| Q10 | Multi-branch workflow |
| Q11 | Failure recovery da commit errato |
| Q12 | Raccolta evidenze finali |

---

## Question 1 | Verifica installazione Flux

1. Verifica pod e deployment in namespace flux-system.
2. Verifica CRD source.toolkit.fluxcd.io e kustomize.toolkit.fluxcd.io.
3. Salva output in /course/1/flux-install-check.txt.

## Question 2 | GitRepository da repo applicativo

1. Crea una GitRepository flux-app in flux-system.
2. Punta al repo Gitea cnpe-specific-fluxcd-app sul branch main.
3. Intervallo massimo: 1m.
4. Salva manifest in /course/2/flux-app-source.yaml.

## Question 3 | Kustomization per clusters/dev

1. Crea Kustomization flux-app-dev.
2. Path richiesto: ./clusters/dev.
3. targetNamespace: flux-lab.
4. Abilita prune.
5. Salva manifest in /course/3/flux-app-kustomization.yaml.

## Question 4 | Reconciliazione manuale e drift

1. Modifica live il deployment web (replicas=4).
2. Esegui reconcile manuale del source e della kustomization.
3. Verifica ritorno allo stato Git.
4. Salva evidenza in /course/4/flux-reconcile-drift.txt.

## Question 5 | Sospensione e resume Kustomization

1. Sospendi flux-app-dev.
2. Modifica il repo locale e fai push (replicas=2).
3. Verifica che non venga applicato durante suspend.
4. Riprendi (resume) e verifica rollout.
5. Salva output in /course/5/flux-suspend-resume.txt.

## Question 6 | Secondo source repo (infra)

1. Crea GitRepository flux-infra.
2. Punta al repo cnpe-specific-fluxcd-infra.
3. Salva manifest in /course/6/flux-infra-source.yaml.

## Question 7 | DependsOn tra Kustomization

1. Crea Kustomization flux-infra-dev su path ./tenants/dev.
2. Crea/aggiorna flux-app-dev con dependsOn verso flux-infra-dev.
3. Verifica ordine logico di applicazione.
4. Salva in /course/7/flux-dependson.txt.

## Question 8 | Prune e cancellazione risorse

1. Rimuovi namespace.yaml dal repo infra e fai push.
2. Reconcilia flux-infra-dev.
3. Verifica rimozione risorsa dal cluster per prune.
4. Salva evidenze in /course/8/flux-prune.txt.

## Question 9 | Health checks e timeout

1. Imposta wait=true e timeout=2m su flux-app-dev.
2. Verifica condizioni Ready/Healthy.
3. Salva describe in /course/9/flux-health-timeout.txt.

## Question 10 | Multi-branch workflow

1. Crea branch stage sul repo app.
2. Crea GitRepository flux-app-stage (ref branch: stage).
3. Crea Kustomization flux-app-stage in namespace flux-lab.
4. Salva output in /course/10/flux-multibranch.txt.

## Question 11 | Failure recovery da commit errato

1. Inserisci un manifest invalido nel branch main.
2. Esegui reconcile e osserva failure.
3. Ripristina commit valido e verifica recovery.
4. Salva output in /course/11/flux-failure-recovery.txt.

## Question 12 | Raccolta evidenze finali

1. Raccogli stato finale di GitRepository e Kustomization.
2. Raccogli stato namespace flux-lab.
3. Salva report in /course/12/flux-final-report.txt.
