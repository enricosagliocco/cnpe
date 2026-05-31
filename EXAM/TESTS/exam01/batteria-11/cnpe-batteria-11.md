# CNPE Batteria 11 - Full Exam Simulation (Nuova Variante)

Focus strumenti: mix completo CNPE con rotazione tool non ripetitiva.

## Domande (12)
1. GitOps: crea pipeline promozione Git tag-based da staging a prod.
2. Progressive delivery: blue/green con webhook pre-rollout HTTP check.
3. Security: enforce signed images + no latest.
4. APIs: CRD AppPlan con tier e autoscaling profile.
5. Self-service: workflow request namespace con approvazione e quota automatica.
6. Observability: alert p95 latency + log correlation + trace export 10 items.
7. Ops: incidente CrashLoop dovuto a secret mancante, remediation e report.
8. FinOps: right-size 2 deployment e dimostra riduzione costo.
9. Networking: implementa split 15/85 via HTTPRoute.
10. Policy: applica deny hostPath e privileged pods.
11. RBAC: SA read-only namespace scoped, verifica deny write.
12. Recovery: backup+restore namespace critico entro RTO target.

## Risposte guida sintetiche
1. Strategy Git + controller reconcile verificato.
2. Canary/bluegreen con metriche o webhook pass.
3. Kyverno/Gatekeeper verify constraints.
4. CRD schema e sample resource valida.
5. WorkflowTemplate parametrico e audit approval.
6. PromQL + Loki query + export Jaeger.
7. Describe/log/events -> fix -> rollout healthy.
8. Misura before/after con OpenCost/Prometheus.
9. Gateway API backendRefs weighted.
10. PSS + policy engine combinati.
11. Role/RoleBinding least privilege.
12. Restore validato con healthcheck finale.
