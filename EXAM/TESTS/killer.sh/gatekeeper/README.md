# CNPE Gatekeeper Mini Lab

Mini lab focalizzato su OPA Gatekeeper, in stile CNPE/killer.sh.

## Avvio

```bash
chmod +x setup-gatekeeper-mini.sh
./setup-gatekeeper-mini.sh
```

Variabili opzionali:

```bash
export MINIKUBE_PROFILE=cnpe-gk-mini
export MINIKUBE_CPUS=4
export MINIKUBE_MEMORY=8192
export MINIKUBE_DRIVER=docker
export K8S_VERSION=v1.33.0
```

## Pulizia

```bash
./setup-gatekeeper-mini.sh --cleanup
```

## File nel cluster

Lo script crea:

```text
/course/gatekeeper-mini/00-workloads.yaml
/course/gatekeeper-mini/10-constrainttemplates-broken.yaml
/course/gatekeeper-mini/20-constraints-broken.yaml
/course/gatekeeper-mini/30-test-bad-pod.yaml
```

## Cosa alleni

- `ConstraintTemplate`
- Rego per Pod e Deployment
- `Constraint` con `match.namespaces`
- `enforcementAction: dryrun` vs `deny`
- mutation con `AssignMetadata`
- audit e `status.totalViolations`
- troubleshooting admission webhook
