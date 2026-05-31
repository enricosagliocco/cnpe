# CNPE Batteria 10 - Governance, Policy Engines e Audit Compliance

Focus strumenti: Kyverno, OPA Gatekeeper, PSA/PSS, RBAC, audit logs, compliance reports.

## Domande (10)
1. Imposta namespace regulated con Pod Security restricted enforce.
2. Gatekeeper ConstraintTemplate: deployment min replicas >=2.
3. Kyverno: richiedi labels owner,cost-center su Pod/Deploy.
4. Kyverno mutate idempotente per annotation compliance=required.
5. Blocca immagini da registry non trusted.
6. Verifica RBAC least privilege per service account ci-bot.
7. Genera report violazioni policy in /course/10/policy-report.txt.
8. Abilita audit trail per operazioni cluster-admin.
9. Integra controllo policy in pipeline pre-deploy.
10. Simula eccezione temporanea policy con scadenza controllata.

## Risposte guida sintetiche
1. Label namespace PSS enforce restricted.
2. Rego deny su spec.replicas <2.
3. validate pattern labels non-empty.
4. add if not exists.
5. deny su image registry whitelist.
6. kubectl auth can-i matrix.
7. esporta policyreports/violations.
8. collezione audit log e query eventi.
9. test manifest con kyverno apply/test.
10. policy exception con ownership e TTL.
