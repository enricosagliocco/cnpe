# CNPE Batteria 03 - Service Mesh, Gateway API, Zero Trust

Focus strumenti: Linkerd, Gateway API, NetworkPolicy, cert-manager, Argo Rollouts, Prometheus.

## Domande (10)
1. Configura mTLS strict in namespace apps-mesh e verifica handshake tra frontend e backend.
2. Crea AuthorizationPolicy per permettere solo frontend->backend:80 e bloccare pod non autorizzati.
3. Crea HTTPRoute canary 20/80 tra backend-v1 e backend-v2.
4. Aggiungi retry+timeout policy lato route per endpoint /checkout.
5. Abilita TLS termination con cert-manager su Gateway public.
6. Esegui rollout canary con Argo Rollouts e promuovi dopo analisi positiva.
7. Crea default deny ingress+egress in team-a e aperture minime richieste.
8. Esporta metriche mesh latency p95 e genera report in /course/3/mesh-latency.txt.
9. Crea alert Prometheus su error rate > 3% per 5m su backend.
10. Simula incidente (deny errato), ripristina traffico e scrivi postmortem sintetico.

## Risposte guida sintetiche
1. Annota namespace per injection Linkerd, applica Server/ServerAuthorization o AuthorizationPolicy.
2. Usa selector app=frontend su policy auth e target app=backend.
3. Crea HTTPRoute con backendRefs weighted: 20/80.
4. Inserisci rules.filters o policy compatibile controller con timeout e retry.
5. Issuer/ClusterIssuer + Certificate + listener TLS su Gateway.
6. Rollout steps progressivi + metric query Prometheus; promote finale.
7. NetworkPolicy default-deny e whitelist DNS/DB/API minime.
8. Query PromQL (histogram_quantile) e redirect output file.
9. PrometheusRule con expr rate(5xx)/rate(total) > 0.03.
10. Root cause via events/log, fix e validazione end-to-end.
