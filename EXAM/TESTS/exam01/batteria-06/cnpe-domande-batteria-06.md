# CNPE Simulator - Batteria 06 - Domande
> Killer Shell style | Kubernetes 1.35 | CNPE Exam Simulator

---

> Git remoto (Gitea): per tutte le attivita Git usare i repository remoti su Gitea (non repository locali standalone).

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
for q in 1 3 5 9 10 11 17 19; do
  mkdir -p /course/${q}
  rm -rf /course/${q}/repo-b06
  git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b06-q${q}.git" "/course/${q}/repo-b06"
done
```

## Indice delle Domande

| Q 1 | Operator Pattern, CRD, Kustomize, Git |
| Q 2 | Prometheus Monitoring |
| Q 3 | Argo CD |
| Q 4 | Flagger for Blue/Green Deployments |
| Q 5 | OPA Gatekeeper, Helm |
| Q 6 | OpenTofu, Terraform |
| Q 7 | OpenCost, Prometheus |
| Q 8 | Grafana, Loki, Logging, Monitoring |
| Q 9 | Kustomize, Prometheus CRDs |
| Q10 | ResourceQuota, StorageClass, PV/PVC, Git |
| Q11 | Argo Workflows |
| Q12 | Tekton, Security Scanning, SBOM |
| Q13 | Pod Security Standards, RBAC |
| Q14 | OpenTelemetry, Jaeger |
| Q15 | Vertical Pod Autoscaler (VPA) |
| Q16 | Argo Rollouts, Canary |
| Q17 | FluxCD |
| Q18 | Kyverno |
| Q19 | Crossplane, CloudNativePG |
| Q20 | Linkerd, Istio, Gateway API |

---

## Question 1 | Operator Pattern, CRD, Kustomize, Git

> Instance: `ssh cnpe0601`
A custom operator project is available in /course/1/repo-b06. The TeamMonitoring CRD already exists in the cluster.

1. Add a new CRD version v1beta1 where spec.target is an object with string fields namespace and service.
2. Keep v1alpha1 served, and make v1beta1 the storage version.
3. Deploy changes with Kustomize and commit on branch main with message: crd v1beta1 b06.
4. Create TeamMonitoring resource app-b06-q01 in namespace ns-b06-q01 with target.namespace=metrics and target.service=api.
5. Save kubectl get output to /course/1/b06-q01-evidence.txt.

---

## Question 2 | Prometheus Monitoring

> Instance: `ssh cnpe0602`
Prometheus is installed in namespace monitoring and reachable from the node.

1. Extend the scrape config so Pods with label app=worker in namespace ns-b06-q02 are scraped.
2. Reload Prometheus configuration without deleting resources.
3. Run query sum by (deployment) (rate(http_requests_total{namespace="ns-b06-q02"}[5m])) and identify the highest value deployment.
4. Scale that deployment to 2 replicas and save before/after evidence to /course/2/b06-q02-report.txt.

---

## Question 3 | Argo CD

> Instance: `ssh cnpe0603`
Argo CD is installed and an application app-b06-q03 points to /course/3/repo-b06 branch main.

1. In /course/3/repo-b06 update workload label version to v3 and app response text to "app-b06-q03 main".
2. Commit and push on main.
3. Create branch b06-q03, change response text to "app-b06-q03 testing", commit and push.
4. Create Argo CD application app-b06-q03-testing targeting branch b06-q03 and namespace ns-b06-q03-testing.
5. Ensure both applications end in Healthy and Synced.

---

## Question 4 | Flagger for Blue/Green Deployments

> Instance: `ssh cnpe0604`
Flagger manages Deployment app-b06-q04 in namespace ns-b06-q04.

1. Increase APP_VERSION patch number by 1 on deployment app-b06-q04.
2. Add a pre-rollout webhook in Canary analysis that performs HTTP GET against canary service app-b06-q04-canary.
3. Trigger a rollout and wait until analysis is completed.
4. Write Canary events and rollout result to /course/4/b06-q04-events.log.

---

## Question 5 | OPA Gatekeeper, Helm

> Instance: `ssh cnpe0605`
OPA Gatekeeper is installed and policy files are in /course/5/repo-b06/gatekeeper.

1. Complete ConstraintTemplate so Pods require label owner and Deployments require replicas >= 2.
2. Scope the Constraint to namespace ns-b06-q05 only.
3. Update Helm chart in /course/5/repo-b06/chart to satisfy the policy without adding new values files.
4. Bump chart version to 1.06.05 and deploy release app-b06-q05 in namespace ns-b06-q05.
5. Save successful validation evidence in /course/5/b06-q05-evidence.txt.

---

## Question 6 | OpenTofu, Terraform

> Instance: `ssh cnpe0606`
OpenTofu project contains three services under /course/6/repo-b06.

1. For service-a, generate a readable plan and save it to /course/6/b06-q06-report.txt.
2. For service-b, change deployment replicas to 3 and apply.
3. For service-c, add a NodePort Service named app-b06-q06-public on port 30066.
4. Verify resources created and store terraform/tofu outputs in /course/6/b06-q06-evidence.txt.

---

## Question 7 | OpenCost, Prometheus

> Instance: `ssh cnpe0607`
OpenCost and Prometheus are available in the cluster.

1. Update OpenCost custom pricing: internetNetworkEgress=0.26, spotCPU=0.011.
2. Run a Prometheus query filtered by namespace ns-b06-q07 and save result to /course/7/b06-q07-report.txt.
3. Identify targets with scrape errors and write error messages to /course/7/b06-q07-events.log.
4. Confirm OpenCost reflects new pricing and record command evidence in /course/7/b06-q07-evidence.txt.

---

## Question 8 | Grafana, Loki, Logging, Monitoring

> Instance: `ssh cnpe0608`
Grafana uses Loki as datasource.

1. Set Loki datasource maximum lines to 106.
2. Update existing panel query to exactly: count(rate({namespace="ns-b06-q08"} |= "ERROR" [5m])).
3. Find two workloads with highest error volume in last 15 minutes.
4. Scale corresponding controllers to 0 replicas and write findings to /course/8/b06-q08-report.txt.
5. Pick one failing workload from logs, diagnose root cause (events/logs/describe), apply a minimal fix, and capture remediation evidence in the same report.

---

## Question 9 | Kustomize, Prometheus CRDs

> Instance: `ssh cnpe0609`
Prometheus Operator manifests are managed with Kustomize under /course/9/repo-b06/prom-config.

1. Add a ServiceMonitor selecting app=app-b06-q09 in namespace ns-b06-q09.
2. Add a PrometheusRule alerting on high 5xx rate over 2m.
3. Ensure overlays dev and prod both render successfully.
4. Apply prod overlay and save final rendered resources to /course/9/b06-q09-result.yaml.

---

## Question 10 | ResourceQuota, StorageClass, PV/PVC, Git

> Instance: `ssh cnpe0610`
A multi-team cluster needs quota hardening and Git traceability.

1. Create ResourceQuota in namespace ns-b06-q10 with requests.cpu=2, requests.memory=4Gi, persistentvolumeclaims=2.
2. Add a LimitRange setting default cpu=250m and memory=256Mi.
3. Validate quota enforcement with a failing Pod or PVC test.
4. Commit all manifests in /course/10/repo-b06 on branch main and capture git log + quota checks in /course/10/b06-q10-evidence.txt.
5. Create a static PersistentVolume and a matching PersistentVolumeClaim that references a valid StorageClass, validate binding status and include kubectl describe pv/pvc evidence in the same report.

---

## Question 11 | Argo Workflows

> Instance: `ssh cnpe0611`
Argo Workflows is installed and templates are in /course/11/repo-b06/workflows.

1. Extend WorkflowTemplate with parameters namespace and appName.
2. Add a parallel step creating ConfigMap and Secret.
3. Run one workflow in namespace ns-b06-q11 and ensure it succeeds.
4. Delete failed runs if any and save workflow status output to /course/11/b06-q11-report.txt.

---

## Question 12 | Tekton, Security Scanning, SBOM

> Instance: `ssh cnpe0612`
Tekton pipeline app-b06-q12-ci exists in namespace ns-b06-q12.

1. Insert lint task before build task.
2. Insert image-scan task between build and deploy.
3. Configure pipeline so deploy runs only if scan succeeds.
4. Start a PipelineRun, collect logs, and save evidence to /course/12/b06-q12-events.log.
5. Integrate a security scan task that exports an SBOM (CycloneDX or SPDX) artifact and fail the pipeline on critical findings.

---

## Question 13 | Pod Security Standards, RBAC

> Instance: `ssh cnpe0613`
Pod Security must be enforced in namespace ns-b06-q13.

1. Label namespace ns-b06-q13 to enforce restricted profile at latest version.
2. Update one failing workload so it passes restricted admission without privileged mode.
3. Verify admission blocks an intentionally non-compliant Pod.
4. Save compliant manifest and validation commands in /course/13/b06-q13-result.yaml.
5. Create Role and RoleBinding that grant least-privilege read access to Pods for a service account in the same namespace, then verify with kubectl auth can-i.

---

## Question 14 | OpenTelemetry, Jaeger

> Instance: `ssh cnpe0614`
Jaeger is deployed in namespace tracing.

1. Identify service tagged release=canary and update env VERSION to 2.6.4.
2. Identify public service and scale it to 2 replicas.
3. Export 10 traces for service app-b06-q14 into /course/14/b06-q14-report.txt.
4. Verify exported file contains exactly 10 traces and store check output in /course/14/b06-q14-evidence.txt.
5. Ensure traces are routed through OpenTelemetry Collector before Jaeger storage (validate collector pipeline and exporter status).

---

## Question 15 | Vertical Pod Autoscaler (VPA)

> Instance: `ssh cnpe0615`
Vertical Pod Autoscaler is installed and a workload in namespace ns-b06-q15 needs tuning.

1. Create or update VPA for deployment app-b06-q15 in Auto mode.
2. Configure minAllowed cpu=100m memory=128Mi and maxAllowed cpu=1 memory=1Gi.
3. Trigger load to produce recommendations and inspect VPA status.
4. Save recommendation snapshot and resulting pod resources to /course/15/b06-q15-events.log.

---

## Question 16 | Argo Rollouts, Canary

> Instance: `ssh cnpe0616`
Argo Rollouts manages canary deployment app-b06-q16 in namespace ns-b06-q16.

1. Configure steps: setWeight 10, pause 20s, setWeight 40, pause 30s, setWeight 100.
2. Update image tag to stable-b06.
3. Promote rollout to completion and confirm no degraded status.
4. Save rollout history and current status to /course/16/b06-q16-report.txt.

---

## Question 17 | FluxCD

> Instance: `ssh cnpe0617`
FluxCD is installed and manages /course/17/repo-b06/flux-app.

1. Force reconcile for source and kustomization related to app-b06-q17.
2. Introduce a temporary in-cluster drift (replicas +1) on managed deployment.
3. Verify Flux restores desired state from Git.
4. Save reconcile and drift-recovery evidence in /course/17/b06-q17-evidence.txt.

---

## Question 18 | Kyverno

> Instance: `ssh cnpe0618`
Kyverno policies are required for namespace ns-b06-q18.

1. Create ClusterPolicy enforcing label team on Pods.
2. Add a mutate rule injecting annotation managed-by=kyverno on Deployments.
3. Test both deny and mutate behavior with sample resources.
4. Store policy YAML and test results in /course/18/b06-q18-result.yaml and /course/18/b06-q18-report.txt.

---

## Question 19 | Crossplane, CloudNativePG

> Instance: `ssh cnpe0619`
Crossplane compositions are defined in /course/19/repo-b06/crossplane.

1. Extend existing Composition to provision Deployment plus ClusterIP Service on port 8080.
2. Ensure patch set maps composite field spec.parameters.size to container resources.
3. Apply changes and verify existing XR/XRC resources reconcile successfully.
4. Save rendered managed resources and events to /course/19/b06-q19-events.log.
5. Add a CloudNativePG Cluster or ClusterClaim example managed through Crossplane composition and verify reconciliation status.

---

## Question 20 | Linkerd, Istio, Gateway API

> Instance: `ssh cnpe0620`
Linkerd and Gateway API are installed.

1. Configure HTTPRoute for service app-b06-q20 behind Gateway app-b06-q20-gw in namespace ns-b06-q20.
2. Inject Linkerd sidecars on involved workloads and verify proxies are ready.
3. Create policy so only traffic from namespace ns-b06-q20-client reaches app-b06-q20.
4. Validate path and policy behavior, then save results to /course/20/b06-q20-report.txt.
5. Repeat service-to-service policy validation using Istio AuthorizationPolicy as an alternative implementation and compare outcomes with Linkerd policy.

---

