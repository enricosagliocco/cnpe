# Crossplane Composition - 20 exam-style tasks

Crossplane is installed together with `function-patch-and-transform`. The
function can take 1-2 minutes to become healthy.

Each question is independent. The supplied `xrd.yaml` and `composition.yaml`
are complete: apply them, inspect the API and Composition, create the requested
composite resource, and verify every composed resource.

Useful commands:

```bash
kubectl get functions
kubectl get compositions
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q1 - Create a TeamSpace

Work in `~/course-crossplane/01`.

Apply `xrd.yaml` and `composition.yaml`. Create a `TeamSpace` named
`team-alpha` with `projectId: alpha-123`, then verify all composed resources.

**Tip 1**

```bash
kubectl apply -f ~/course-crossplane/01/xrd.yaml
kubectl apply -f ~/course-crossplane/01/composition.yaml
```

**Tip 2**

The API is `platform.example.com/v1alpha1`. Examine the Composition to
understand which resources are created and where.

**Solution**

```yaml
apiVersion: platform.example.com/v1alpha1
kind: TeamSpace
metadata:
  name: team-alpha
spec:
  projectId: alpha-123
```

```bash
kubectl get teamspaces
kubectl get namespace team-alpha
kubectl -n team-alpha get networkpolicy default-deny-ingress
```

---

### Q2 - Create a ProjectSpace

Work in `~/course-crossplane/02`. Apply the supplied definitions and create
`ProjectSpace` `payments` with `owner: finance`. Verify Namespace `payments`,
its annotation, and ConfigMap `project-config`.

**Tip**

Inspect `spec.names`, the schema, and `spec.pipeline` before writing the XR.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/02/xrd.yaml -f ~/course-crossplane/02/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ProjectSpace
metadata:
  name: payments
spec:
  owner: finance
YAML
kubectl get ns payments -o yaml
kubectl -n payments get cm project-config -o yaml
```

---

### Q3 - Create an EnvironmentSpace

Work in `~/course-crossplane/03`. Create `EnvironmentSpace` `staging-blue`
with `environment: staging`. Verify Namespace and `environment-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/03/xrd.yaml -f ~/course-crossplane/03/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: EnvironmentSpace
metadata:
  name: staging-blue
spec:
  environment: staging
YAML
kubectl get ns staging-blue
kubectl -n staging-blue get cm environment-config -o yaml
```

---

### Q4 - Create a CostSpace

Work in `~/course-crossplane/04`. Create `CostSpace` `billing` with
`costCenter: cc-4100`. Verify Namespace annotation and `cost-config` data.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/04/xrd.yaml -f ~/course-crossplane/04/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: CostSpace
metadata:
  name: billing
spec:
  costCenter: cc-4100
YAML
kubectl get ns billing -o yaml
kubectl -n billing get cm cost-config -o yaml
```

---

### Q5 - Create a ProductSpace

Work in `~/course-crossplane/05`. Create `ProductSpace` `catalog` with
`productId: product-88`. Verify Namespace and `product-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/05/xrd.yaml -f ~/course-crossplane/05/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ProductSpace
metadata:
  name: catalog
spec:
  productId: product-88
YAML
kubectl get ns catalog
kubectl -n catalog get cm product-config -o yaml
```

---

### Q6 - Create a TenantSpace

Work in `~/course-crossplane/06`. Create `TenantSpace` `tenant-acme` with
`tenantId: acme-001`. Verify Namespace and `tenant-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/06/xrd.yaml -f ~/course-crossplane/06/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: TenantSpace
metadata:
  name: tenant-acme
spec:
  tenantId: acme-001
YAML
kubectl get ns tenant-acme
kubectl -n tenant-acme get cm tenant-config -o yaml
```

---

### Q7 - Create a ClusterSpace

Work in `~/course-crossplane/07`. Create `ClusterSpace` `edge-west` with
`clusterName: edge-west-01`. Verify Namespace and `cluster-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/07/xrd.yaml -f ~/course-crossplane/07/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ClusterSpace
metadata:
  name: edge-west
spec:
  clusterName: edge-west-01
YAML
kubectl get ns edge-west
kubectl -n edge-west get cm cluster-config -o yaml
```

---

### Q8 - Create a RegionSpace

Work in `~/course-crossplane/08`. Create `RegionSpace` `apps-eu` with
`region: eu-west-1`. Verify Namespace and `region-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/08/xrd.yaml -f ~/course-crossplane/08/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: RegionSpace
metadata:
  name: apps-eu
spec:
  region: eu-west-1
YAML
kubectl get ns apps-eu
kubectl -n apps-eu get cm region-config -o yaml
```

---

### Q9 - Create an AccountSpace

Work in `~/course-crossplane/09`. Create `AccountSpace` `shared-services`
with `accountId: "123456789012"`. Verify Namespace and `account-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/09/xrd.yaml -f ~/course-crossplane/09/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: AccountSpace
metadata:
  name: shared-services
spec:
  accountId: "123456789012"
YAML
kubectl get ns shared-services
kubectl -n shared-services get cm account-config -o yaml
```

---

### Q10 - Create an ApplicationSpace

Work in `~/course-crossplane/10`. Create `ApplicationSpace` `checkout` with
`applicationId: app-checkout`. Verify Namespace and `application-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/10/xrd.yaml -f ~/course-crossplane/10/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ApplicationSpace
metadata:
  name: checkout
spec:
  applicationId: app-checkout
YAML
kubectl get ns checkout
kubectl -n checkout get cm application-config -o yaml
```

---

### Q11 - Create a DomainSpace

Work in `~/course-crossplane/11`. Create `DomainSpace` `orders` with
`domain: commerce`. Verify Namespace and `domain-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/11/xrd.yaml -f ~/course-crossplane/11/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: DomainSpace
metadata:
  name: orders
spec:
  domain: commerce
YAML
kubectl get ns orders
kubectl -n orders get cm domain-config -o yaml
```

---

### Q12 - Create a ServiceSpace

Work in `~/course-crossplane/12`. Create `ServiceSpace` `identity` with
`serviceOwner: iam-team`. Verify Namespace and `service-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/12/xrd.yaml -f ~/course-crossplane/12/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ServiceSpace
metadata:
  name: identity
spec:
  serviceOwner: iam-team
YAML
kubectl get ns identity
kubectl -n identity get cm service-config -o yaml
```

---

### Q13 - Create a DataSpace

Work in `~/course-crossplane/13`. Create `DataSpace` `analytics` with
`classification: confidential`. Verify Namespace and `data-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/13/xrd.yaml -f ~/course-crossplane/13/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: DataSpace
metadata:
  name: analytics
spec:
  classification: confidential
YAML
kubectl get ns analytics
kubectl -n analytics get cm data-config -o yaml
```

---

### Q14 - Create a SecuritySpace

Work in `~/course-crossplane/14`. Create `SecuritySpace` `restricted` with
`securityTier: high`. Verify Namespace and `security-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/14/xrd.yaml -f ~/course-crossplane/14/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: SecuritySpace
metadata:
  name: restricted
spec:
  securityTier: high
YAML
kubectl get ns restricted
kubectl -n restricted get cm security-config -o yaml
```

---

### Q15 - Create a ComplianceSpace

Work in `~/course-crossplane/15`. Create `ComplianceSpace` `pci-workloads`
with `policySet: pci-dss`. Verify Namespace and `compliance-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/15/xrd.yaml -f ~/course-crossplane/15/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ComplianceSpace
metadata:
  name: pci-workloads
spec:
  policySet: pci-dss
YAML
kubectl get ns pci-workloads
kubectl -n pci-workloads get cm compliance-config -o yaml
```

---

### Q16 - Create a RuntimeSpace

Work in `~/course-crossplane/16`. Create `RuntimeSpace` `java-services` with
`runtime: java-21`. Verify Namespace and `runtime-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/16/xrd.yaml -f ~/course-crossplane/16/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: RuntimeSpace
metadata:
  name: java-services
spec:
  runtime: java-21
YAML
kubectl get ns java-services
kubectl -n java-services get cm runtime-config -o yaml
```

---

### Q17 - Create a ReleaseSpace

Work in `~/course-crossplane/17`. Create `ReleaseSpace` `canary` with
`releaseChannel: canary`. Verify Namespace and `release-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/17/xrd.yaml -f ~/course-crossplane/17/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ReleaseSpace
metadata:
  name: canary
spec:
  releaseChannel: canary
YAML
kubectl get ns canary
kubectl -n canary get cm release-config -o yaml
```

---

### Q18 - Create an ObservabilitySpace

Work in `~/course-crossplane/18`. Create `ObservabilitySpace` `sre-tools`
with `monitoringProfile: full`. Verify Namespace and `observability-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/18/xrd.yaml -f ~/course-crossplane/18/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: ObservabilitySpace
metadata:
  name: sre-tools
spec:
  monitoringProfile: full
YAML
kubectl get ns sre-tools
kubectl -n sre-tools get cm observability-config -o yaml
```

---

### Q19 - Create a BackupSpace

Work in `~/course-crossplane/19`. Create `BackupSpace` `critical-backups`
with `backupPolicy: daily-30d`. Verify Namespace and `backup-config`.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/19/xrd.yaml -f ~/course-crossplane/19/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: BackupSpace
metadata:
  name: critical-backups
spec:
  backupPolicy: daily-30d
YAML
kubectl get ns critical-backups
kubectl -n critical-backups get cm backup-config -o yaml
```

---

### Q20 - Create a PlatformSpace

Work in `~/course-crossplane/20`. Create `PlatformSpace` `developer-portal`
with `platformOwner: platform-team`. Verify the XR, both resource references,
Namespace annotation, and `platform-config` data.

**Tip**

Use `kubectl describe platformspace developer-portal` to inspect conditions
and resource references.

**Solution**

```bash
kubectl apply -f ~/course-crossplane/20/xrd.yaml -f ~/course-crossplane/20/composition.yaml
kubectl apply -f - <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: PlatformSpace
metadata:
  name: developer-portal
spec:
  platformOwner: platform-team
YAML
kubectl get platformspaces
kubectl describe platformspace developer-portal
kubectl get ns developer-portal -o yaml
kubectl -n developer-portal get cm platform-config -o yaml
```
