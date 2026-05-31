# CNPE Batteria 07 - FinOps e Capacity Optimization

Focus strumenti: OpenCost, Prometheus, HPA, VPA, KEDA, ResourceQuota, Kubecost API.

## Domande (10)
1. Aggiorna custom pricing OpenCost (CPU, RAM, egress).
2. Identifica top 3 namespace per costo giornaliero.
3. Imposta budget alert per namespace analytics.
4. Crea report rightsizing per deployment con utilization < 20%.
5. Introduci HPA su servizio api basato su RPS/custom metric.
6. Applica VPA in modalità Initial su workload batch.
7. Configura KEDA scaler su queue depth per worker.
8. Definisci quota multi-tenant con burst controllato.
9. Confronta costo pre/post ottimizzazione in /course/7/cost-diff.txt.
10. Proponi policy di chargeback con label mandatory.

## Risposte guida sintetiche
1. Edit config pricing e restart/reload opencost.
2. Query OpenCost UI/API con finestra 24h.
3. Alertmanager o rule custom su threshold costo.
4. Usa usage/request ratio da Prometheus.
5. HPA autoscaling/v2 con metriche adatte.
6. VPA con min/max bounds e restart pod.
7. ScaledObject KEDA con trigger queue.
8. ResourceQuota + LimitRange per tenant.
9. Report numerico before/after.
10. Enforce label via policy engine.
