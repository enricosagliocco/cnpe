# CNPE Alternative Simulator — 20 task lab

Setup: `./setup-cnpe-alt-lab.sh`. Directory: `~/course-alt`.

## Domain coverage
- Platform Architecture and Infrastructure: Q1, Q4, Q8, Q10, Q17, Q18
- GitOps and Continuous Delivery: Q3, Q5, Q6, Q7, Q20
- Platform APIs and Self-Service: Q1, Q8, Q9, Q10
- Observability and Operations: Q2, Q11, Q12, Q17, Q18, Q20
- Security and Policy Enforcement: Q13, Q14, Q15, Q16, Q20

---

### Q1 — CRD evolution, Kustomize, Git
Path: `~/course-alt/1/platform-service`.

The `PlatformService` CRD is installed from a local Kustomize Git repository.

Tasks:
1. Add version `v1alpha2`.
2. In `v1alpha2`, add `spec.tier` as string enum `bronze|silver|gold` and `spec.exposure` as object with string properties `hostname` and `path`.
3. Make `v1alpha2` the storage version and keep `v1alpha1` served but not storage.
4. Apply with Kustomize.
5. Commit locally on branch `main`.
6. Create a `PlatformService` named `payments` in namespace `selfservice-alt` with tier `gold`, hostname `payments.internal`, path `/api`.

### Q2 — Prometheus scrape and scaling decision
Namespace: `atlas`.

Prometheus is installed by the base setup. Two apps exist: `checkout` and `proxy`.

Tasks:
1. Extend Prometheus scraping so that `proxy` pods are scraped too.
2. Reload or restart Prometheus safely.
3. Query request metrics and identify the highest traffic workload.
4. Scale the selected deployment to 2 replicas.
5. Save commands and output in `~/course-alt/2/prometheus-report.txt`.

### Q3 — Argo CD branch promotion
Path: `~/course-alt/3/portal-client`.

Tasks:
1. Update `portal-client` labels from `version: v1` to `version: v2`, commit and push.
2. Create branch `staging`, set label `version: v3`, commit and push.
3. Create Argo CD application `portal-client-staging` from branch `staging` into namespace `baltic-staging`.
4. Sync and verify health.

### Q4 — Progressive delivery pre-check
Namespace: `delivery-alt`.

Deployment `catalog` has `APP_VERSION=1.0.0`.

Tasks:
1. Convert or prepare the workload for progressive delivery using the installed progressive delivery tool available in the cluster.
2. Add a pre-rollout HTTP check against the canary/preview service.
3. Bump `APP_VERSION` to `1.0.1`.
4. Save canary/rollout events to `~/course-alt/4/catalog-events.log`.

### Q5 — Argo Rollouts analysis gate
Namespace: `delivery-alt`.

Tasks:
1. Create a Rollout for a workload named `frontend-rollout` using a canary strategy.
2. Add an analysis step that checks success rate or an HTTP endpoint.
3. Pause before full promotion.
4. Promote only after the analysis is successful.

### Q6 — Tekton pipeline repair
Path: `~/course-alt/6/tekton-api/pipeline.yaml`. Namespace: `cicd-alt`.

Tasks:
1. Complete the empty Tekton Pipeline with a `git-clone` task and a second task that prints the commit SHA.
2. Create a PipelineRun using the Gitea repo URL.
3. Verify task status with `tkn` or `kubectl`.
4. Commit and push the fixed pipeline.

### Q7 — Flux GitOps source and Kustomization
Path: `~/course-alt/7/flux-platform`.

Tasks:
1. Add a simple Deployment and Service under `clusters/dev/apps/demo`.
2. Update `clusters/dev/apps/kustomization.yaml` to include it.
3. Create Flux `GitRepository` and `Kustomization` objects pointing to this repo.
4. Verify reconciliation and Ready=True.

### Q8 — Crossplane platform API
Path: `~/course-alt/8/platform-api`.

Tasks:
1. Extend the XRD with claim field `spec.databaseName` and `spec.storageSize`.
2. Complete the Composition so a claim creates a Kubernetes ConfigMap with those values.
3. Apply the XRD and Composition.
4. Create a claim named `orders-db` in namespace `selfservice-alt`.

### Q9 — Backstage software template
Path: `~/course-alt/9/backstage-template/template.yaml`.

Tasks:
1. Add parameters `serviceName`, `owner`, and `namespace`.
2. Add steps to create Kubernetes YAML for Namespace, Deployment, and Service.
3. Add output links to the generated repo or files.
4. Validate YAML structure.

### Q10 — OpenTofu Kubernetes provider
Path: `~/course-alt/10/tofu-k8s`.

Tasks:
1. Add a ConfigMap and ServiceAccount managed by OpenTofu in namespace `team-a`.
2. Run init/plan/apply.
3. Import or reference one pre-existing Kubernetes object.
4. Save output in `~/course-alt/10/tofu-output.txt`.

### Q11 — OpenTelemetry endpoint fix
Namespace: `obs-alt`.

Deployment `telemetry-api` points to a wrong OTLP endpoint.

Tasks:
1. Find the available collector/Jaeger endpoint in the cluster.
2. Patch `OTEL_EXPORTER_OTLP_ENDPOINT` to a valid endpoint.
3. Restart the workload.
4. Verify traces or collector connectivity.

### Q12 — Logs and dashboard triage
Namespace: `obs-alt`.

Tasks:
1. Generate logs from `telemetry-api`.
2. Ensure logs are queryable from the installed log stack if available.
3. Create a short troubleshooting note with exact `kubectl` and query commands in `~/course-alt/12/log-triage.md`.

### Q13 — Gatekeeper owner label policy
Path: `~/course-alt/13/gatekeeper/template.yaml`.

Tasks:
1. Replace the TODO message.
2. Create a Constraint that requires label `owner` on Deployments only in namespace `security-alt`.
3. Prove one invalid Deployment is denied and one valid Deployment is accepted.

### Q14 — Kyverno non-root policy
Path: `~/course-alt/14/kyverno/policy.yaml`.

Tasks:
1. Complete a Kyverno ClusterPolicy requiring containers to run as non-root.
2. Change action from Audit to Enforce.
3. Exclude namespace `kube-system`.
4. Test against a bad Pod manifest and a good Pod manifest.

### Q15 — Pod Security Standards remediation
Namespace: `security-alt`.

Deployment `legacy-worker` violates baseline security.

Tasks:
1. Make it compliant with namespace Pod Security labels.
2. Avoid privileged containers.
3. Set `allowPrivilegeEscalation: false`, drop capabilities and set `seccompProfile: RuntimeDefault`.
4. Verify rollout status.

### Q16 — RBAC least privilege
Namespace: `security-alt`.

ServiceAccount `report-reader` exists.

Tasks:
1. Create a Role allowing only get/list/watch on Pods and ConfigMaps.
2. Bind it to `report-reader`.
3. Verify with `kubectl auth can-i`.
4. Confirm it cannot delete Pods.

### Q17 — KEDA scaling object
Path: `~/course-alt/17/keda/scaledobject.yaml`. Namespace: `data-alt`.

Tasks:
1. Complete the ScaledObject for `queue-worker` using a CPU or cron trigger supported by your installed KEDA.
2. Apply it.
3. Verify HPA creation.
4. Save status output.

### Q18 — OpenCost / cost visibility
Namespace: `cost-alt`.

Tasks:
1. Find the installed OpenCost service.
2. Port-forward it.
3. Query allocation/cost API or UI endpoint.
4. Save the access command and one useful endpoint in `~/course-alt/18/opencost.txt`.

### Q19 — Linkerd/service mesh check
Namespace: `mesh-alt`.

Tasks:
1. Deploy a simple client/server app.
2. Inject the namespace or manifests with Linkerd if available.
3. Verify proxy sidecars.
4. Run a connectivity test from client to server.

### Q20 — Final integrated incident
A platform team reports that delivery, policy and observability are all partially broken.

Tasks:
1. Fix one GitOps sync issue from Q3 or Q7.
2. Fix one policy issue from Q13-Q15.
3. Fix one observability issue from Q11-Q12.
4. Write `~/course-alt/20/final/report.md` with: root cause, commands used, verification, and rollback plan.
