# CNPE Targeted Labs

Sette laboratori complementari al simulatore `cnpe-fixed`.

## Mappa delle lacune

Le aree prioritarie sono state dedotte dai problemi e dalle richieste emerse
durante il lavoro sui simulatori:

- configurazione e troubleshooting di Loki, Prometheus, Grafana e OTLP;
- workflow GitOps e progressive delivery con dipendenze verificabili;
- costruzione di Pipeline Tekton oltre il semplice collegamento di due Task;
- progettazione di API self-service e Composition Crossplane v2;
- policy admission, audit, RBAC e isolamento multi-tenant;
- esercizi troppo aperti, privi di file starter o risultati attesi.

## Laboratori

| Cartella | Focus | Curriculum CNPE |
|---|---|---|
| `cnpe-gaps-delivery-ops` | GitOps, CI/CD, rollout, monitoring, logging, tracing, incidenti | GitOps/CD 25% + Observability 20% |
| `cnpe-gaps-platform-security` | CRD, self-service, multi-tenancy, cost, RBAC, policy | Architecture 15% + Platform APIs 25% + Security 15% |
| `tekton-lab` | Task, Pipeline, workspace, results, matrix, finally, RBAC, supply chain | CI/CD pipelines |
| `crossplane-lab` | XRD v2, Composition pipeline, patch, transform, readiness, revisioni | Platform APIs e self-service |
| `kyverno-lab` | ValidatingPolicy e MutatingPolicy CEL, metadata, security, immagini, multi-tenancy | Security e policy enforcement |
| `kyverno-guided-lab` | Sintassi CEL spiegata progressivamente, esempi da adattare e test | Apprendimento policy Kyverno |
| `gatekeeper-guided-lab` | Schema ConstraintTemplate, Rego, match, inventory e audit guidati | Apprendimento policy Gatekeeper |

Ogni laboratorio contiene 20 tracce, setup autonomo, nomi e valori obbligatori,
manifest iniziali e risultati di verifica. Le tracce partono da risorse
running non conformi oppure da starter incompleti o guasti.

I lab `*-guided-lab` hanno invece 10 lezioni progressive. Ogni lezione
contiene un esempio funzionante, uno starter da modificare, spiegazione della
sintassi e test positivo/negativo.

## GUI

- `cnpe-gaps-delivery-ops`: dashboard native Argo CD, Argo Rollouts, Tekton,
  Prometheus e Jaeger, con accesso documentato in `domande.md`.
- `tekton-lab`: Tekton Dashboard installata automaticamente.
- `crossplane-lab`, `cnpe-gaps-platform-security` e `gatekeeper-lab`:
  Lens/OpenLens sul kubeconfig corrente per Custom Resources, eventi e log.
- `kyverno-lab`: Lens/OpenLens per policy/report e CLI `kyverno` per test
  locali prima dell'admission.
- `kyverno-guided-lab` e `gatekeeper-guided-lab`: Lens/OpenLens per osservare
  policy, Constraint e report mentre si seguono le lezioni.
