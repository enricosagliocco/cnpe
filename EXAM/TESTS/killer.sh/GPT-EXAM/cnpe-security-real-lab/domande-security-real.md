# CNPE Security & Policy Enforcement — Real Lab

Scenario: `security-real`  
Directory: `/course/security-real`  
Tempo consigliato: 120 minuti  
Domande: 20

Namespace:

```text
payments
catalog
security
ci
```

Installati dallo script:

```text
Gatekeeper
Kyverno
cert-manager
Tekton Pipelines
```

Nota: Trivy, Cosign e SBOM sono simulati con Task Tekton reali per tenere il lab leggero e riproducibile su Minikube.

---

## Q1 — RBAC minimale nel namespace payments

La ServiceAccount `payments/app-reader` deve poter fare:

```text
get
list
watch
```

solo sui Pod nel namespace `payments`.

Correggi l'RBAC esistente.

Verifica:

```bash
kubectl auth can-i get pods -n payments --as system:serviceaccount:payments:app-reader
kubectl auth can-i list pods -n payments --as system:serviceaccount:payments:app-reader
kubectl auth can-i watch pods -n payments --as system:serviceaccount:payments:app-reader
```

Salva:

```bash
/course/security-real/q1-rbac-payments.txt
```

---

## Q2 — RBAC cross-namespace senza ClusterRoleBinding

La ServiceAccount `payments/app-reader` deve leggere ConfigMap nel namespace `catalog`.

Permessi richiesti:

```text
get
list
watch
```

Vincolo:

```text
non usare ClusterRoleBinding
```

Salva verifica:

```bash
/course/security-real/q2-rbac-cross-namespace.txt
```

---

## Q3 — NetworkPolicy deny-all completa

Nel namespace `payments` esiste una policy deny-all incompleta.

Correggila in modo che neghi:

```text
Ingress
Egress
```

per tutti i Pod.

Salva:

```bash
kubectl -n payments get networkpolicy payments-deny-all -o yaml > /course/security-real/q3-deny-all.yaml
```

---

## Q4 — Egress solo verso Postgres

`payments-api` deve poter parlare solo con `postgres` su porta `5432`.

Correggi la NetworkPolicy `allow-api-to-postgres`.

Salva:

```bash
/course/security-real/q4-egress-postgres.txt
```

---

## Q5 — Gatekeeper Required Labels

Il ConstraintTemplate `k8srequiredlabels` controlla solo i Pod.

Correggi il template per controllare anche i Deployment.

Deployment in `payments` devono avere:

```text
owner
environment
```

Imposta la Constraint `required-labels` in `deny`.

Salva:

```bash
/course/security-real/q5-required-labels.txt
```

---

## Q6 — Gatekeeper CPU limits

Il ConstraintTemplate `k8srequiredcpulimits` usa un path sbagliato sui Deployment.

Correggi:

```text
Deployment -> spec.template.spec.containers
Pod        -> spec.containers
```

Deve bloccare risorse senza `resources.limits.cpu`.

Salva:

```bash
/course/security-real/q6-cpu-limits.txt
```

---

## Q7 — Gatekeeper immagini vietate

Correggi `k8sdisallowedimages` in modo che blocchi:

```text
nginx:latest
immagini senza tag esplicito, es. nginx
docker.io/library/*
```

Deve funzionare su Pod e Deployment.

Salva:

```bash
/course/security-real/q7-disallowed-images.txt
```

---

## Q8 — Remediation payments-api senza modificare policy

Il Deployment `payments-api` iniziale viola:

- label richieste;
- CPU limits;
- immagine latest.

Rendilo conforme.

Puoi patchare il Deployment esistente.

Salva:

```bash
kubectl -n payments get deploy payments-api -o yaml > /course/security-real/q8-payments-api-fixed.yaml
```

---

## Q9 — Kyverno mutate Pod label

La ClusterPolicy `mutate-managed-by` non applica la label.

Correggi la policy affinché tutti i nuovi Pod in `payments` ricevano:

```yaml
managed-by: kyverno
```

Verifica creando un Pod di test.

Salva:

```bash
/course/security-real/q9-kyverno-mutate.txt
```

---

## Q10 — Kyverno generate deny-all su namespace team-*

Correggi `generate-deny-all-ns`.

Obiettivo:

Quando viene creato un namespace con nome:

```text
team-*
```

Kyverno genera automaticamente una NetworkPolicy `deny-all`.

Crea namespace `team-demo` e verifica.

Salva:

```bash
/course/security-real/q10-kyverno-generate.txt
```

---

## Q11 — cert-manager ClusterIssuer

Il ClusterIssuer `security-selfsigned` esiste.

Verifica che sia Ready.

Salva:

```bash
/course/security-real/q11-clusterissuer.txt
```

---

## Q12 — Certificate TLS Secret

Il Certificate `security/payments-tls` punta all’issuer sbagliato.

Correggilo.

Deve generare Secret:

```text
security/payments-tls
```

Salva:

```bash
/course/security-real/q12-certificate.txt
```

---

## Q13 — Tekton scan critical gate

La Pipeline `ci/secure-delivery` esegue scan, sbom, verify, deploy.

Ma `deploy-safe` deploya anche se `critical-count > 0`.

Correggi il Task `deploy-safe`:

- se critical-count è diverso da `0`, fallisce;
- se critical-count è `0`, prosegue.

Esegui PipelineRun con:

```text
image=nginx:latest
```

Deve fallire prima del deploy.

Salva:

```bash
/course/security-real/q13-tekton-critical-gate.txt
```

---

## Q14 — Tekton good image

Esegui una PipelineRun con:

```text
image=nginx:1.27-alpine
```

Deve passare lo scan critical.

Salva:

```bash
/course/security-real/q14-tekton-good-image.txt
```

---

## Q15 — Tekton SBOM artifact/result

Verifica che il task `generate-sbom` produca il result:

```text
sbom-path
```

e che nei log appaia un JSON CycloneDX.

Salva log e describe:

```bash
/course/security-real/q15-sbom.txt
```

---

## Q16 — Tekton cosign verification simulated

La Task `cosign-verify` ritorna `true` solo per immagini con `podinfo`.

Esegui PipelineRun con:

```text
ghcr.io/stefanprodan/podinfo:6.7.1
```

Poi modifica la Pipeline/Task se vuoi imporre che `deploy` dipenda anche da `verify`.

Salva:

```bash
/course/security-real/q16-cosign-sim.txt
```

---

## Q17 — Pipeline dependencies

Correggi la Pipeline `secure-delivery`:

- `deploy` deve partire solo dopo:
  - `scan`
  - `sbom`
  - `verify`
- deve ricevere il `critical-count` dallo scan.

Salva YAML:

```bash
kubectl -n ci get pipeline secure-delivery -o yaml > /course/security-real/q17-pipeline-dependencies.yaml
```

---

## Q18 — Audit report

Genera un report con:

- RBAC rilevante;
- NetworkPolicy in payments;
- Constraint Gatekeeper;
- ClusterPolicy Kyverno;
- Certificate e Secret TLS;
- ultime PipelineRun Tekton.

Salva:

```bash
/course/security-real/q18-audit-report.txt
```

---

## Q19 — End-to-end valid/invalid manifest

Usa:

```bash
/course/security-real/07-test-manifests.yaml
```

Applica solo il Deployment valido e verifica che venga accettato.

Prova ad applicare il Deployment `invalid-latest` e verifica che venga rifiutato.

Salva:

```bash
/course/security-real/q19-valid-invalid.txt
```

---

## Q20 — Final governance report

Crea:

```bash
/course/security-real/final-report.txt
```

Deve contenere:

1. RBAC payments OK;
2. RBAC cross-namespace OK;
3. deny-all payments OK;
4. allow egress postgres OK;
5. Gatekeeper in deny per label/cpu/image;
6. Kyverno mutate OK;
7. Kyverno generate OK su `team-demo`;
8. Certificate `payments-tls` Ready;
9. Pipeline Tekton blocca immagini con critical;
10. Deployment valido accettato;
11. Deployment latest rifiutato.

---

# Comandi utili

```bash
kubectl auth can-i list pods -n payments --as system:serviceaccount:payments:app-reader
kubectl auth can-i list configmaps -n catalog --as system:serviceaccount:payments:app-reader

kubectl -n payments get netpol
kubectl get constrainttemplate
kubectl get K8sRequiredLabels,K8sRequiredCpuLimits,K8sDisallowedImages

kubectl get clusterpolicy
kubectl get updaterequest -A

kubectl get clusterissuer
kubectl -n security get certificate,secret

kubectl -n ci get task,pipeline,pipelinerun,taskrun
kubectl -n ci describe pipelinerun <name>
kubectl -n ci logs <pod> --all-containers
```
