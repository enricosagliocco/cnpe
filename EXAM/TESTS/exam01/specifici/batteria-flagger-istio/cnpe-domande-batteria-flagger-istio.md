# CNPE Specifici - Batteria Dedicata Flagger + Istio (App Non Instrumentata) - Domande
> Killer Shell style | Kubernetes 1.35 | Focus: Progressive Delivery con Flagger su Istio

---

## Perche questo scenario

In questa batteria il workload non espone metriche applicative custom.
L'analisi canary si basa sulle metriche del service mesh Istio (telemetria Envoy via Prometheus), quindi non e richiesta instrumentazione dell'app.

---

## Git remoto (Gitea)

> Nota: il bootstrap da Gitea e il percorso previsto; se il server non e disponibile, il setup salta il clone e il laboratorio continua.

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="${GITEA_OWNER:-organization}"
mkdir -p /course/2
rm -rf /course/2/repo-flagger-istio
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-flagger-istio-repo.git" /course/2/repo-flagger-istio
```

## Indice delle Domande

| Q 1 | Verifica installazione Istio e Flagger |
| Q 2 | Bootstrap workload non instrumentato |
| Q 3 | Verifica sidecar injection |
| Q 4 | Verifica risorse generate da Flagger Istio |
| Q 5 | Canary progression su update immagine |
| Q 6 | Regolazione stepWeight e maxWeight |
| Q 7 | Webhook load-test |
| Q 8 | Simulazione failure e rollback |
| Q 9 | Pause/resume reconciliation |
| Q10 | Gateway host e routing |
| Q11 | Telemetria mesh e troubleshooting |
| Q12 | Raccolta evidenze finali |

---

## Question 1 | Verifica installazione Istio e Flagger

1. Verifica i pod/deploy principali in istio-system (istiod, istio-ingressgateway, flagger).
2. Verifica CRD canaries.flagger.app.
3. Salva output in /course/1/istio-flagger-install-check.txt.

## Question 2 | Bootstrap workload non instrumentato

1. Applica i manifest sotto /course/2/repo-flagger-istio/apps/web.
2. Verifica deployment, service, gateway, canary in flagger-lab.
3. Salva output in /course/2/istio-flagger-bootstrap.txt.

## Question 3 | Verifica sidecar injection

1. Verifica che i pod di web abbiano due container (app + istio-proxy).
2. Verifica label del namespace flagger-lab per auto-injection.
3. Salva output in /course/3/istio-sidecar-check.txt.

## Question 4 | Verifica risorse generate da Flagger Istio

1. Verifica creazione destinationrules e virtualservices in flagger-lab.
2. Verifica service web, web-primary, web-canary.
3. Salva output in /course/4/flagger-istio-generated.txt.

## Question 5 | Canary progression su update immagine

1. Aggiorna immagine a nginx:1.27.
2. Osserva avanzamento del canary (weights/events/status).
3. Salva output in /course/5/flagger-istio-progression.txt.

## Question 6 | Regolazione stepWeight e maxWeight

1. Imposta stepWeight=20 e maxWeight=60 sul Canary web.
2. Triggera un nuovo deploy con immagine nginx:1.27.1.
3. Salva output in /course/6/flagger-istio-weights.txt.

## Question 7 | Webhook load-test

1. Verifica webhook load-test nel canary web.
2. Esegui update immagine e controlla che l'analysis invochi il webhook.
3. Salva output in /course/7/flagger-istio-webhook.txt.

## Question 8 | Simulazione failure e rollback

1. Imposta tag immagine non valido (es. nginx:not-valid).
2. Verifica eventi di failure/rollback nel canary.
3. Ripristina una immagine valida.
4. Salva output in /course/8/flagger-istio-rollback.txt.

## Question 9 | Pause/resume reconciliation

1. Sospendi il canary impostando spec.suspend=true.
2. Verifica stato sospeso.
3. Ripristina con spec.suspend=false.
4. Salva output in /course/9/flagger-istio-pause-resume.txt.

## Question 10 | Gateway host e routing

1. Cambia host in gateway+canary da web.flagger.local a web2.flagger.local.
2. Verifica aggiornamento virtualservice.
3. Salva output in /course/10/flagger-istio-gateway-host.txt.

## Question 11 | Telemetria mesh e troubleshooting

1. Raccogli eventi in flagger-lab.
2. Raccogli log di deploy/flagger in istio-system.
3. Raccogli log di istio-proxy da un pod web.
4. Salva in /course/11/flagger-istio-troubleshooting.txt.

## Question 12 | Raccolta evidenze finali

1. Raccogli stato finale di canary/deploy/hpa/service/virtualservice/destinationrule.
2. Salva report in /course/12/flagger-istio-final-report.txt.
