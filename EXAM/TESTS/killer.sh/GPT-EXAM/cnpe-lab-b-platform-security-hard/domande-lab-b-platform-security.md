# CNPE Lab B — Platform APIs + Self-Service + Security Hard

Focus:
- **Platform APIs and Self-Service Capabilities**
- **Security and Policy Enforcement**

Tempo consigliato: 120 minuti  
Domande: 20  
Directory: `/course/lab-b-platform-security`

---

## Q1 — CRD PlatformApp schema

Ispeziona CRD `platformapps.platform.cnpe.io`.

Aggiungi al campo `spec`:

```yaml
size:
  type: string
  enum:
  - small
  - medium
  - large
```

Salva:

```bash
/course/lab-b-platform-security/q1-platformapp-crd.yaml
```

---

## Q2 — PlatformApp custom resource

Correggi `tenant-a/selfservice-api`:

- image non latest;
- aggiungi `size: small`;
- replicas coerente.

Salva:

```bash
/course/lab-b-platform-security/q2-platformapp.yaml
```

---

## Q3 — Controller RBAC status

Il controller simulato deve aggiornare status dei PlatformApp.

Correggi RBAC:

```text
platformapps/status update/patch
databaseclaims/status update/patch
```

Salva auth can-i:

```bash
/course/lab-b-platform-security/q3-status-rbac.txt
```

---

## Q4 — Controller Job

Correggi Job `reconcile-platformapps`:

- crea Deployment e Service;
- aggiunge limits.cpu;
- aggiorna status `phase=Ready`;
- status `service=<nome>`.

Salva Job YAML:

```bash
/course/lab-b-platform-security/q4-controller-job.yaml
```

---

## Q5 — Reconcile PlatformApp

Rilancia il Job.

Verifica:

- Deployment `selfservice-api` in `tenant-a`;
- Service `selfservice-api`;
- status PlatformApp aggiornato.

Salva:

```bash
/course/lab-b-platform-security/q5-reconcile-platformapp.txt
```

---

## Q6 — DatabaseClaim schema

Ispeziona `databaseclaims.platform.cnpe.io`.

Assicurati che `engine` accetti solo:

```text
postgres
mysql
```

Salva CRD:

```bash
/course/lab-b-platform-security/q6-dbclaim-crd.yaml
```

---

## Q7 — DatabaseClaim provisioning

Correggi/estendi il controller simulato o crea risorse manuali coerenti affinché `DatabaseClaim appdb` produca:

- Secret `appdb-conn`;
- Service `appdb`;
- status `phase=Ready`;
- status `secretName=appdb-conn`.

Salva:

```bash
/course/lab-b-platform-security/q7-dbclaim-ready.txt
```

---

## Q8 — Self-service report

Crea report che spieghi PlatformApp e DatabaseClaim come API self-service.

File:

```bash
/course/lab-b-platform-security/q8-selfservice-report.txt
```

---

## Q9 — Gatekeeper labels

Correggi `k8srequiredlabels`:

- deve validare Deployment;
- richiede `owner` e `environment`;
- enforcement `deny`.

Salva:

```bash
/course/lab-b-platform-security/q9-gatekeeper-labels.txt
```

---

## Q10 — Gatekeeper resources

Correggi `k8srequiredresources`:

- Deployment path corretto;
- richiede `limits.cpu`;
- non deve bloccare risorse già conformi.

Salva:

```bash
/course/lab-b-platform-security/q10-gatekeeper-resources.txt
```

---

## Q11 — Gatekeeper disallowed images

Correggi `k8sdisallowedimages`:

- blocca `latest`;
- blocca immagini senza tag;
- controlla Deployment.

Salva:

```bash
/course/lab-b-platform-security/q11-disallowed-images.txt
```

---

## Q12 — Kyverno mutate

Correggi `mutate-owner`:

- namespace `tenant-a`;
- aggiunge label `owner=platform` ai nuovi Pod.

Verifica con Pod test.

Salva:

```bash
/course/lab-b-platform-security/q12-kyverno-mutate.txt
```

---

## Q13 — Kyverno generate

Correggi/gestisci `generate-deny-all` per namespace `team-*`.

Crea `team-demo`.

Verifica NetworkPolicy `deny-all`.

Salva:

```bash
/course/lab-b-platform-security/q13-kyverno-generate.txt
```

---

## Q14 — cert-manager

Correggi Certificate `platform-api-tls`:

- issuer `platform-selfsigned`;
- Secret creato in namespace `security`.

Salva:

```bash
/course/lab-b-platform-security/q14-certmanager.txt
```

---

## Q15 — RBAC least privilege

Crea ServiceAccount `tenant-a/app-viewer` che può solo:

```text
get/list/watch pods,services
```

nel namespace `tenant-a`.

Salva auth can-i:

```bash
/course/lab-b-platform-security/q15-rbac-least-privilege.txt
```

---

## Q16 — NetworkPolicy tenant-a

Crea deny-all in `tenant-a`, poi allow solo traffico interno verso `selfservice-api` porta 80.

Salva:

```bash
/course/lab-b-platform-security/q16-networkpolicy.txt
```

---

## Q17 — Tekton security gate

Correggi Task `deploy-gate`:

- se `critical > 0` deve fallire;
- se `critical = 0` deve passare.

Esegui PipelineRun con `nginx:latest`, deve fallire.

Salva:

```bash
/course/lab-b-platform-security/q17-tekton-gate-fail.txt
```

---

## Q18 — Tekton SBOM

Esegui PipelineRun con `nginx:1.27-alpine`.

Verifica:

- scan critical = 0;
- SBOM result presente;
- PipelineRun succeeded.

Salva:

```bash
/course/lab-b-platform-security/q18-tekton-sbom.txt
```

---

## Q19 — Compliance audit

Genera audit report con:

- CRD/CR status;
- Deployment/Service self-service;
- Gatekeeper constraints;
- Kyverno policies;
- cert-manager Certificate;
- RBAC;
- Tekton PipelineRun.

Salva:

```bash
/course/lab-b-platform-security/q19-compliance-audit.txt
```

---

## Q20 — Final report

Crea:

```bash
/course/lab-b-platform-security/final-report.txt
```

Deve contenere:

1. PlatformApp funzionante;
2. DatabaseClaim Ready;
3. Gatekeeper enforcement OK;
4. Kyverno mutate/generate OK;
5. TLS Secret OK;
6. RBAC least privilege OK;
7. Tekton gate OK;
8. differenza tra CRD, CR, controller, status, claim, policy engine, admission controller.
