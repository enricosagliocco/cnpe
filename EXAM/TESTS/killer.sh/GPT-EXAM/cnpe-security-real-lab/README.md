# CNPE Security Real Lab

Lab reale per la sezione **Security and Policy Enforcement 15%**.

## Avvio

```bash
chmod +x setup-security-real.sh
./setup-security-real.sh
```

## Cleanup

```bash
./setup-security-real.sh --cleanup
```

## Installa automaticamente

- Gatekeeper via Helm
- Kyverno via Helm
- cert-manager
- Tekton Pipelines

## Namespace

```text
payments
catalog
security
ci
```

## File nel cluster

```text
/course/security-real/00-apps.yaml
/course/security-real/01-rbac-broken.yaml
/course/security-real/02-networkpolicy-broken.yaml
/course/security-real/03-gatekeeper-broken.yaml
/course/security-real/04-kyverno-broken.yaml
/course/security-real/05-certmanager-broken.yaml
/course/security-real/06-tekton-security-broken.yaml
/course/security-real/07-test-manifests.yaml
/course/security-real/README.txt
```

## Focus

- Configuring secure service-to-service communication
- RBAC and security controls
- Audit trails and compliance reports
- Gatekeeper admission governance
- Kyverno mutate/generate
- cert-manager TLS
- Tekton security gates
- SBOM/Cosign/Trivy simulated checks
