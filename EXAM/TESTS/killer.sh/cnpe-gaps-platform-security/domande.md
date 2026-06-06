# CNPE Gaps - Platform APIs and Security - 20 domande

Scenario: `~/course-platform-security`. Ogni esercizio specifica nomi,
parametri e risultato atteso.

### Q1 - CRD structural schema
Completa `01/crd.yaml` per `DatabaseClaim`: `engine` enum postgres/mysql,
`storageGi` integer minimo 1, entrambi required, nessuna proprietà aggiuntiva.
`01/valid.yaml` deve essere accettato e `01/invalid.yaml` rifiutato.

### Q2 - CRD versioning
In `02/crd.yaml` aggiungi `v1beta1` served/storage e mantieni `v1alpha1`
served/non-storage. In `v1beta1` aggiungi `spec.highAvailability` boolean
default false. Verifica le storedVersions.

### Q3 - Status subresource
Abilita `subresources.status` in `03/crd.yaml`; crea `cache-a` e aggiorna solo
lo status a `phase: Ready` senza modificare spec. Salva i comandi in
`03/result.txt`.

### Q4 - Printer columns
Aggiungi colonne `Engine`, `Storage` e `Phase` in `04/crd.yaml` usando i
JSONPath corretti. `kubectl get databaseclaims` deve mostrare i tre valori.

### Q5 - Namespaced platform API
Completa `05/xrd.yaml` Crossplane v2, scope Namespaced, kind `AppEnvironment`,
campi required `team` e `environment`, quest'ultimo enum dev/staging/prod.

### Q6 - Composition patching
Completa `06/composition.yaml` affinché crei Namespace logico tramite
ConfigMap `environment-config`, copiando team/environment nei data e il
Namespace dell'XR nei metadata.

### Q7 - Composition transforms
In `07/composition.yaml` trasforma `spec.environment`: dev -> `1`, staging ->
`2`, prod -> `3`, scrivendo il valore in `data.replicas`.

### Q8 - Composition readiness
Aggiungi readiness check `MatchString` su `data.ready` valore `"true"` alla
risorsa ConfigMap di `08/composition.yaml`. L'XR deve restare non Ready finché
il campo non è presente.

### Q9 - Self-service claim validation
Correggi `09/xr.yaml`: nome `payments-prod`, Namespace `team-payments`, team
`payments`, environment `prod`. Verifica le resource references in
`09/result.txt`.

### Q10 - Multi-tenancy quota
Completa `10/quota.yaml` nel Namespace `tenant-a`: requests.cpu `2`,
requests.memory `4Gi`, limits.cpu `4`, limits.memory `8Gi`, pods `20`,
persistentvolumeclaims `5`.

### Q11 - LimitRange defaults
Completa `11/limitrange.yaml`: default request `100m/128Mi`, default limit
`500m/512Mi`, max `2/2Gi`. Il Pod fornito deve ricevere i default.

### Q12 - NetworkPolicy default deny
Applica default deny ingress/egress in `tenant-a`, poi consenti al Pod
`frontend` di raggiungere `backend` solo TCP 8080 e DNS kube-system UDP/TCP
53. Completa `12/policies.yaml`.

### Q13 - RBAC tenant admin
Completa `13/rbac.yaml`: ServiceAccount `tenant-admin`, Role su
deployments/services/configmaps con get/list/watch/create/update/patch/delete,
senza Secret o RBAC. I test in `13/checks.txt` devono rifletterlo.

### Q14 - Pod Security restricted
Etichetta `tenant-a` con restricted/latest e correggi `14/deployment.yaml`:
runAsNonRoot, runAsUser 1000, RuntimeDefault, no privilege escalation, drop
ALL. Il rollout deve riuscire.

### Q15 - Gatekeeper required owner
Completa template e Constraint in `15`: parametro annotation string, messaggio
`Missing annotation: owner`, Deployment in `tenant-a`, deny. Bad negato, good
accettato.

### Q16 - Gatekeeper allowed repositories
Completa `16/template.yaml` e consenti soltanto `registry.k8s.io/` ai Pod in
`tenant-a`, includendo initContainer. Il Pod bad deve essere negato indicando
nome container e immagine.

### Q17 - Audit and remediation
Applica `17/constraint.yaml` in dryrun per richiedere label `cost-center` ai
Deployment di `tenant-a`. Esporta violazioni in `17/audit.txt`, correggi i
Deployment e porta la Constraint a deny.

### Q18 - Supply-chain check
Completa `18/pipeline-policy.yaml`: lo step deve fallire se `18/sbom.json` non
contiene `SPDXID` o contiene package con license `NOASSERTION`. Il file
fornito deve fallire con exit code 1.

### Q19 - Cost and right-sizing
Da `19/usage.csv`, imposta in `19/deployment.yaml` request CPU al percentile
95 arrotondato ai 10m superiori e memory al massimo più 20%. Limiti pari a 2x
le request. Documenta il calcolo.

### Q20 - Simulazione a tempo
Completa `20/report.md` in 25 minuti dimostrando: CRD valida, XR Ready, quota e
LimitRange attivi, NetworkPolicy funzionante, RBAC least privilege, PSS
restricted, Gatekeeper deny e controllo SBOM fallito correttamente.
