# CNPE Specifici - Batteria Dedicata Flagger - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: Progressive Delivery con Flagger

---

## Git remoto (Gitea)

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/2
rm -rf /course/2/repo-flagger
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-flagger-repo.git" /course/2/repo-flagger
```

## Indice delle Domande

| Q 1 | Verifica installazione Flagger |
| Q 2 | Bootstrap workload e Canary |
| Q 3 | Verifica risorse generate da Flagger |
| Q 4 | Update immagine e canary progression |
| Q 5 | Regolazione stepWeight e maxWeight |
| Q 6 | Metriche di analisi e soglie |
| Q 7 | HPA integration |
| Q 8 | Webhook gate pre-rollout |
| Q 9 | Simulazione failure e rollback |
| Q10 | Pause/resume reconciliation |
| Q11 | Eventi e troubleshooting |
| Q12 | Raccolta evidenze finali |

---

## Question 1 | Verifica installazione Flagger

1. Verifica pod/deploy in flagger-system.
2. Verifica CRD canaries.flagger.app.
3. Salva output in /course/1/flagger-install-check.txt.

## Question 2 | Bootstrap workload e Canary

1. Applica i manifest sotto /course/2/repo-flagger/apps/podinfo.
2. Verifica deployment, service e canary in flagger-lab.
3. Salva output in /course/2/flagger-bootstrap.txt.

## Question 3 | Verifica risorse generate da Flagger

1. Verifica presenza dei service primari/canary generati.
2. Verifica deployment primario creato da Flagger.
3. Salva output in /course/3/flagger-generated-resources.txt.

## Question 4 | Update immagine e canary progression

1. Aggiorna immagine a ghcr.io/stefanprodan/podinfo:6.6.1.
2. Osserva la progressione del canary.
3. Salva output in /course/4/flagger-progression.txt.

## Question 5 | Regolazione stepWeight e maxWeight

1. Imposta stepWeight=20 e maxWeight=60 sul Canary.
2. Triggera un nuovo deploy.
3. Salva output in /course/5/flagger-weights.txt.

## Question 6 | Metriche di analisi e soglie

1. Modifica threshold di request-duration a max 300ms.
2. Mantieni request-success-rate >= 99.
3. Salva manifest aggiornato in /course/6/flagger-analysis-updated.yaml.

## Question 7 | HPA integration

1. Verifica HPA targetRef su deployment podinfo.
2. Imposta minReplicas=2 e maxReplicas=6.
3. Salva output in /course/7/flagger-hpa.txt.

## Question 8 | Webhook gate pre-rollout

1. Aggiungi webhook pre-rollout (tipo confirm-rollout).
2. Usa URL placeholder HTTP interno.
3. Salva manifest in /course/8/flagger-webhook.yaml.

## Question 9 | Simulazione failure e rollback

1. Imposta un tag immagine non valido.
2. Verifica evento rollback/failure.
3. Ripristina tag valido.
4. Salva output in /course/9/flagger-rollback.txt.

## Question 10 | Pause/resume reconciliation

1. Sospendi temporaneamente il Canary (analysis interval molto alto o pause via spec).
2. Verifica stato.
3. Ripristina parametri normali.
4. Salva output in /course/10/flagger-pause-resume.txt.

## Question 11 | Eventi e troubleshooting

1. Raccogli eventi del namespace flagger-lab.
2. Raccogli logs del controller Flagger.
3. Salva in /course/11/flagger-troubleshooting.txt.

## Question 12 | Raccolta evidenze finali

1. Raccogli stato finale di canary/deploy/hpa/service.
2. Salva report in /course/12/flagger-final-report.txt.
