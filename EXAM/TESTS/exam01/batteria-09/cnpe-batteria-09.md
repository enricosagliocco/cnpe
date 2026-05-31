# CNPE Batteria 09 - Platform APIs, Operator Pattern e Self-Service

Focus strumenti: CRD versioning, controller-runtime pattern, Crossplane, Argo Workflows, Backstage-like API flow.

## Domande (10)
1. Disegna CRD TeamEnvironment v1alpha1/v1beta1 con conversion strategy.
2. Aggiungi validation schema (enum, required, defaults).
3. Crea risorsa claim che provisiona namespace+quota+networkpolicy.
4. Estendi Composition Crossplane con Service e ConfigMap.
5. Implementa workflow self-service approvazione -> provisioning.
6. Aggiungi finalizer cleanup su deprovision.
7. Gestisci status.conditions su risorsa custom.
8. Versiona API senza breaking change su client esistenti.
9. Crea test contract API in /course/9/api-contract-tests.txt.
10. Documenta API usage in /course/9/platform-api.md.

## Risposte guida sintetiche
1. CRD multi-version con storage controllato.
2. OpenAPI schema rigoroso.
3. Controller/automation che rende idempotente provisioning.
4. Patch from composite fields.
5. WorkflowTemplate parametrico con step approvazione.
6. Delete path con garbage collection sicura.
7. Conditions Ready/Progressing/Failed.
8. Deprecation policy e compatibilita.
9. Test create/update/delete e edge cases.
10. Esempi YAML e limiti operativi.
