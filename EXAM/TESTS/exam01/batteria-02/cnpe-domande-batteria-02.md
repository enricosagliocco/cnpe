# CNPE Simulator - Batteria 02 (Domains & Competencies)
> Killer Shell style | Kubernetes 1.35 | Exam-oriented practice set

---

## Distribuzione per dominio

- Platform Architecture and Infrastructure (15%): Q1-Q3
- GitOps and Continuous Delivery (25%): Q4-Q8
- Platform APIs and Self-Service Capabilities (25%): Q9-Q13
- Observability and Operations (20%): Q14-Q17
- Security and Policy Enforcement (15%): Q18-Q20

Totale: 20 domande

---

## Question 1 | Platform Architecture - Multi-tenancy Compute and Storage

> Instance: `ssh cnpe6101`

In cluster sono presenti i namespace tenant-a, tenant-b e tenant-c.
Implementa i limiti multi-tenant come segue:

1. In tenant-a applica un ResourceQuota con:
   - requests.cpu: 2
   - requests.memory: 4Gi
   - persistentvolumeclaims: 2
2. In tenant-b applica un LimitRange che imposti default:
   - cpu: 200m
   - memory: 256Mi
3. In tenant-c impedisci la creazione di nuovi PVC.
4. Verifica che tenant-c non possa creare un PVC di test.

---

## Question 2 | Platform Architecture - Right-Sizing with Metrics

> Instance: `ssh cnpe6102`

Il team vuole fare right-sizing su namespace market.

1. Usa metriche reali (metrics-server o Prometheus) per identificare il Deployment con overprovisioning CPU piu alto.
2. Aggiorna requests.cpu e limits.cpu del Deployment identificato riducendo rispettivamente del 30%.
3. Mantieni invariato il numero di repliche.
4. Salva prima e dopo in /course/2/right-sizing-report.txt.

---

## Question 3 | Platform Architecture - Network Segmentation

> Instance: `ssh cnpe6103`

Nel namespace shared-apps devi separare il traffico tra frontend, api e db.

1. Crea una NetworkPolicy default-deny ingress per tutto il namespace.
2. Consenti traffico:
   - frontend -> api su TCP 8080
   - api -> db su TCP 5432
3. Blocca qualsiasi accesso diretto frontend -> db.
4. Verifica con pod test e salva gli esiti in /course/3/network-check.txt.

---

## Question 4 | GitOps - Flux Reconciliation and Drift Recovery

> Instance: `ssh cnpe6201`

FluxCD e installato e gestisce il path /course/4/team-red.

1. Individua la Kustomization che gestisce team-red e forzane una reconcile manuale.
2. Introduci un drift manuale su un Deployment gestito da Flux (replicas +1).
3. Verifica che Flux riporti lo stato a quello dichiarato in Git.
4. Salva evidenze comandi e output in /course/4/flux-drift.txt.

---

## Question 5 | GitOps - Argo CD Multi-Env Strategy

> Instance: `ssh cnpe6202`

Hai il repository locale in /course/5/payment-app con branch main e staging.

1. Aggiorna il branch staging impostando label version=v2 sui Pod e contenuto pagina: Payment API Staging v2.
2. Crea o aggiorna Application Argo CD payment-api-staging puntando a branch staging e namespace payment-staging.
3. Assicurati che sync policy sia automated con prune e selfHeal attivi.
4. Verifica applicazione Healthy/Synced.

---

## Question 6 | CI/CD - Tekton Pipeline Hardening

> Instance: `ssh cnpe6203`

Nel namespace builder esiste una pipeline ci-service.

1. Aggiungi task lint prima del task build.
2. Aggiungi task image-scan dopo build e prima di deploy.
3. Se image-scan fallisce, deploy non deve partire.
4. Esegui una PipelineRun e salva i log in /course/6/tekton-ci.log.

---

## Question 7 | Progressive Delivery - Argo Rollouts Canary

> Instance: `ssh cnpe6204`

Nel namespace checkout il Rollout web e configurato in modo incompleto.

1. Configura steps canary:
   - setWeight 10
   - pause 20s
   - setWeight 40
   - pause 30s
   - setWeight 100
2. Aggiorna immagine a nginx:1.27.
3. Promuovi il rollout fino al completamento.
4. Esporta storia e stato in /course/7/rollout-status.txt.

---

## Question 8 | GitOps - Kustomize Promotion Flow

> Instance: `ssh cnpe6205`

In /course/8/app-config hai base + overlays/dev + overlays/prod.

1. In base aggiungi env var FEATURE_FLAG=true al container principale.
2. In overlay prod imposta replicas=4.
3. Applica dev e poi prod verificando che il rendering sia coerente.
4. Commit in branch main con messaggio: promote feature flag with prod scale.

---

## Question 9 | Platform APIs - CRD Design and Versioning

> Instance: `ssh cnpe6301`

Devi introdurre un API self-service chiamata AppEnvironment.

1. Crea CRD appenvironments.platform.example.io.
2. Supporta versioni v1alpha1 e v1beta1 (storage v1beta1).
3. In v1beta1 aggiungi campi:
   - spec.size (enum: small, medium, large)
   - spec.owner (string)
4. Applica CRD e crea una risorsa di esempio env-sandbox nel namespace dev-platform.

---

## Question 10 | Platform APIs - Operator-driven Provisioning

> Instance: `ssh cnpe6302`

Nel namespace platform-ops e installato un operator che osserva DatabaseClaim.

1. Crea DatabaseClaim db-team1 con:
   - engine: postgres
   - size: small
   - storage: 5Gi
2. Verifica che l'operator crei Deployment e Service associati.
3. Salva eventi della claim in /course/10/dbclaim-events.log.

---

## Question 11 | Self-Service - Argo Workflows API

> Instance: `ssh cnpe6303`

In /course/11/workflowtemplate.yaml esiste un WorkflowTemplate parziale.

1. Aggiungi parametro namespace e parametro app-name.
2. Aggiungi uno step parallelo che crea ConfigMap e Secret applicativi.
3. Applica il WorkflowTemplate e lancia un Workflow per namespace team-lake.
4. Mantieni solo un Workflow riuscito eliminando eventuali run fallite.

---

## Question 12 | Platform APIs - Crossplane Composition Extension

> Instance: `ssh cnpe6304`

La Composition in /course/12/composition.yaml crea solo un Deployment.

1. Estendila per creare anche un Service ClusterIP sulla porta 8080.
2. Mantieni patch pattern coerente con le risorse gia presenti.
3. Applica la Composition aggiornata.
4. Verifica che i composite resource esistenti ricevano anche il Service.

---

## Question 13 | Self-Service Automation - Terraform/OpenTofu

> Instance: `ssh cnpe6305`

Sono presenti tre moduli in /course/13.

1. In service-a genera piano leggibile e salva in /course/13/service-a-plan.txt.
2. In service-b aumenta replicas a 3 e applica.
3. In service-c aggiungi Service NodePort chiamato public-api su 30090.
4. Verifica risorse create e registra output in /course/13/tofu-verify.txt.

---

## Question 14 | Observability - Prometheus Alerting

> Instance: `ssh cnpe6401`

In namespace monitor e attivo Prometheus Operator.

1. Crea o aggiorna PrometheusRule con alert High5xxRate:
   - trigger se rate errori 5xx > 5 req/s per 2m
2. Scope dell'alert sul namespace retail.
3. Verifica caricamento regola in Prometheus.
4. Salva YAML finale in /course/14/high5xx-rule.yaml.

---

## Question 15 | Observability - Grafana and Loki Triage

> Instance: `ssh cnpe6402`

Grafana usa Loki come datasource principale.

1. Imposta Maximum lines datasource Loki a 200.
2. Aggiorna pannello Errors con query esatta:

   sum(count_over_time({namespace="retail"} |= "ERROR" [5m]))

3. Identifica i due workload con piu errori negli ultimi 15m.
4. Scala i relativi controller a 0 e annota i nomi in /course/15/error-workloads.txt.

---

## Question 16 | Observability - Tracing with Jaeger

> Instance: `ssh cnpe6403`

Namespace tracing ospita Jaeger e vari servizi.

1. Trova il servizio con tag release=canary e aggiorna env VERSION a 2.4.1.
2. Trova il servizio con tag public=true e scala a 2 repliche.
3. Esporta 10 trace JSON del servizio checkout in /course/16/checkout-traces.json.
4. Verifica che il file contenga esattamente 10 trace.

---

## Question 17 | Operations - Incident Remediation

> Instance: `ssh cnpe6404`

Nel namespace ops-lab un'app e in CrashLoopBackOff.

1. Identifica root cause con describe/logs/eventi.
2. Applica fix minimo senza cambiare immagine container.
3. Ripristina stato Running/Ready.
4. Scrivi il postmortem tecnico breve in /course/17/incident-report.md con:
   - impatto
   - causa
   - fix
   - prevenzione

---

## Question 18 | Security - Service-to-Service Authorization

> Instance: `ssh cnpe6501`

Namespace secure-mesh usa Linkerd.

1. Crea Server resource:
   - frontend (selector app=frontend, porta 80)
   - backend (selector app=backend, porta 80)
2. Correggi AuthorizationPolicy frontend-to-backend per consentire solo frontend -> backend.
3. Verifica con curl da Pod frontend verso backend.
4. Blocca accessi da Pod non autorizzati.

---

## Question 19 | Security - Policy Engine and Admission Control

> Instance: `ssh cnpe6502`

Kyverno deve governare il namespace finance.

1. Crea ClusterPolicy require-finance-labels:
   - Pod devono avere labels owner e data-classification
   - enforce mode
2. Crea mutate policy che aggiunge annotation compliance=required solo se assente.
3. Verifica con un Pod non conforme (deve fallire) e uno conforme (deve passare).
4. Salva test output in /course/19/kyverno-tests.txt.

---

## Question 20 | Security - Pipeline Compliance and Audit Trail

> Instance: `ssh cnpe6503`

La pipeline in /course/20 deve includere controlli sicurezza e audit.

1. Aggiungi step SBOM generation (es. syft o equivalente).
2. Aggiungi step image vulnerability scan con threshold HIGH.
3. Fallisci la pipeline se vulnerabilita HIGH o CRITICAL > 0.
4. Pubblica artifacts sbom.json e scan-report.txt in /course/20/artifacts.
5. Registra risultato finale (PASS/FAIL) in /course/20/compliance-result.txt.

---

## Note operative

- Usa prevalentemente CLI, salvo dove esplicitamente richiesto UI.
- Ogni task e considerato completo solo con verifica oggettiva riuscita.
- In caso di risorse fallite (PipelineRun, Workflow, Rollout), pulisci gli oggetti non riusciti.
- Se un comando modifica stato cluster, raccogli sempre almeno una evidenza in file.
