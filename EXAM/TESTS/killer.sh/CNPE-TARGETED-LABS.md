# CNPE Targeted Labs

Quattro laboratori complementari al simulatore `cnpe-fixed`.

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

Ogni laboratorio contiene 20 tracce, setup autonomo, nomi e valori obbligatori,
manifest iniziali e risultati di verifica.
