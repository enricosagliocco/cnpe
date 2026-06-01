# CNPE Simulator - Batteria 02 - Risposte Guida
> Guida rapida operativa | Kubernetes 1.35 | CLI-first

---

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
for q in 1 3 5 9 10 11 17 19; do
  mkdir -p /course/${q}
  rm -rf /course/${q}/repo-b02
  git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b02-q${q}.git" "/course/${q}/repo-b02"
done
```

## Question 1 | Platform Architecture - Multi-tenancy Compute and Storage

1. Crea ResourceQuota tenant-a:
   - requests.cpu: 2
   - requests.memory: 4Gi
   - persistentvolumeclaims: 2
2. Crea LimitRange tenant-b con default cpu 200m e memory 256Mi.
3. Crea ResourceQuota tenant-c con persistentvolumeclaims: "0".
4. Verifica con PVC dry-run in tenant-c (deve essere rifiutato).

Comandi di verifica tipici:
- kubectl -n tenant-a get resourcequota
- kubectl -n tenant-b get limitrange
- kubectl -n tenant-c create pvc test --image=nginx --dry-run=server

---

## Question 2 | Platform Architecture - Right-Sizing with Metrics

1. Identifica deployment overprovisionato:
   - kubectl top pod -n market --containers
   - confronta usage vs requests/limits (kubectl get deploy -o yaml)
2. Riduci requests.cpu e limits.cpu del 30%.
3. Applica patch mantenendo repliche invariate.
4. Salva prima/dopo in /course/2/right-sizing-report.txt.

---

## Question 3 | Platform Architecture - Network Segmentation

1. Applica default-deny ingress in shared-apps.
2. Aggiungi policy allow frontend->api:8080.
3. Aggiungi policy allow api->db:5432.
4. Esegui test con Pod temporanei e salva output in /course/3/network-check.txt.

---

## Question 4 | GitOps - Flux Reconciliation and Drift Recovery

1. Elenca kustomizations:
   - flux get kustomizations -A
2. Forza reconcile della kustomization team-red:
   - flux reconcile kustomization <name> -n <ns>
3. Introduci drift (es. scale manuale deployment).
4. Verifica convergenza automatica o reconcile manuale.
5. Salva evidenze in /course/4/flux-drift.txt.

---

## Question 5 | GitOps - Argo CD Multi-Env Strategy

1. In /course/5/payment-app passa a branch staging.
2. Aggiorna label Pod version=v2 e contenuto pagina.
3. Commit e push su staging.
4. Crea/aggiorna Application payment-api-staging:
   - source branch: staging
   - destination namespace: payment-staging
   - automated + prune + selfHeal
5. Verifica con argocd app get payment-api-staging.

---

## Question 6 | CI/CD - Tekton Pipeline Hardening

1. Modifica pipeline ci-service:
   - lint prima di build
   - image-scan dopo build
   - deploy dipende da image-scan
2. Assicurati che deploy non parta se scan fallisce.
3. Esegui PipelineRun.
4. Salva log in /course/6/tekton-ci.log.

---

## Question 7 | Progressive Delivery - Argo Rollouts Canary

1. Aggiorna steps canary nel Rollout web.
2. Aggiorna immagine nginx:1.27.
3. Avanza rollout (promote) fino a completamento.
4. Salva stato in /course/7/rollout-status.txt.

Comandi utili:
- kubectl argo rollouts get rollout web -n checkout
- kubectl argo rollouts promote web -n checkout

---

## Question 8 | GitOps - Kustomize Promotion Flow

1. In base aggiungi FEATURE_FLAG=true.
2. In overlays/prod imposta replicas=4.
3. Verifica rendering:
   - kubectl kustomize overlays/dev
   - kubectl kustomize overlays/prod
4. Applica dev e prod.
5. Commit in main con messaggio richiesto.

---

## Question 9 | Platform APIs - CRD Design and Versioning

1. Definisci CRD appenvironments.platform.example.io con v1alpha1 + v1beta1.
2. Imposta storage=true su v1beta1.
3. In schema v1beta1 aggiungi spec.size (enum) e spec.owner (string).
4. Applica CRD.
5. Crea risorsa env-sandbox in dev-platform.

---

## Question 10 | Platform APIs - Operator-driven Provisioning

1. Crea DatabaseClaim db-team1 con parametri richiesti.
2. Verifica oggetti secondari creati dall'operator (Deployment/Service).
3. Esporta eventi:
   - kubectl -n platform-ops describe databaseclaim db-team1 > /course/10/dbclaim-events.log

---

## Question 11 | Self-Service - Argo Workflows API

1. Aggiorna WorkflowTemplate con params namespace e app-name.
2. Crea step paralleli per ConfigMap e Secret (stesso blocco steps).
3. Applica template e submit workflow per team-lake.
4. Elimina workflow falliti e mantieni uno succeeded.

---

## Question 12 | Platform APIs - Crossplane Composition Extension

1. In Composition aggiungi risorsa Service ClusterIP su 8080.
2. Riusa patch/readinessChecks coerenti al pattern esistente.
3. Applica composizione aggiornata.
4. Verifica che istanze composite esistenti includano anche Service.

---

## Question 13 | Self-Service Automation - Terraform/OpenTofu

1. service-a: tofu plan > /course/13/service-a-plan.txt
2. service-b: aggiorna replicas=3, poi tofu apply.
3. service-c: aggiungi resource kubernetes_service public-api NodePort 30090.
4. Verifica con kubectl get deploy,svc e salva in /course/13/tofu-verify.txt.

---

## Question 14 | Observability - Prometheus Alerting

1. Crea PrometheusRule High5xxRate con durata for: 2m.
2. Usa expr basata su rate 5xx > 5 req/s e filtra namespace retail.
3. Applica regola e verifica stato PrometheusRule.
4. Salva YAML finale in /course/14/high5xx-rule.yaml.

---

## Question 15 | Observability - Grafana and Loki Triage

1. Imposta Maximum lines del datasource Loki a 200.
2. Aggiorna query pannello con stringa esatta richiesta.
3. Identifica due workload con maggiori ERROR negli ultimi 15m.
4. Scala i controller a 0 e scrivi nomi in /course/15/error-workloads.txt.

---

## Question 16 | Observability - Tracing with Jaeger

1. Cerca trace con tag release=canary, individua servizio e aggiorna VERSION=2.4.1.
2. Cerca servizio con tag public=true e scala a 2.
3. Esporta 10 trace JSON di checkout in /course/16/checkout-traces.json.
4. Verifica cardinalita trace esportate (=10).

---

## Question 17 | Operations - Incident Remediation

1. Diagnosi:
   - kubectl describe pod
   - kubectl logs --previous
   - kubectl get events --sort-by=.lastTimestamp
2. Applica fix minimo (env/config/command/probe) senza cambiare immagine.
3. Verifica rollout e stato Ready.
4. Redigi postmortem breve in /course/17/incident-report.md.

---

## Question 18 | Security - Service-to-Service Authorization

1. Crea Server frontend e backend in secure-mesh (port 80).
2. Correggi AuthorizationPolicy frontend-to-backend usando targetRef/backend e requiredAuthenticationRefs corretti.
3. Testa con curl da frontend verso backend (deve funzionare).
4. Testa da Pod non autorizzato (deve fallire).

---

## Question 19 | Security - Policy Engine and Admission Control

1. Crea ClusterPolicy require-finance-labels (enforce).
2. Regola mutate idempotente: compliance=required solo se assente.
3. Testa creazione Pod non conforme (deny) e conforme (allow).
4. Salva output test in /course/19/kyverno-tests.txt.

---

## Question 20 | Security - Pipeline Compliance and Audit Trail

1. Aggiungi step SBOM generation (es. syft).
2. Aggiungi step scan vulnerabilita con fail threshold HIGH.
3. Se HIGH/CRITICAL > 0, pipeline deve fallire.
4. Pubblica artifacts in /course/20/artifacts:
   - sbom.json
   - scan-report.txt
5. Scrivi esito finale in /course/20/compliance-result.txt.

---

## Suggerimenti verifiche rapide

- Usa sempre dry-run=server per controllare admission/policy prima dell'apply definitivo.
- Per GitOps verifica sia stato controller (Flux/Argo) sia stato risorse Kubernetes.
- Per progressive delivery controlla sempre events, ReplicaSet e stato finale promoted/success.
- Per incident response, documenta sempre la root cause in modo ripetibile.
