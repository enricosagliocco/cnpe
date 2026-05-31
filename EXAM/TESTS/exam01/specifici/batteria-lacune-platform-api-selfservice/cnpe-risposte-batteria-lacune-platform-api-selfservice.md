# CNPE Specifici - Lacune Mirate - Platform APIs e Self-Service - Risposte Guida

---

## Question 1

```bash
cat > /course/1/team-a-ns.yaml <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    owner: team-a
  annotations:
    purpose: self-service
YAML
kubectl apply -f /course/1/team-a-ns.yaml
kubectl get ns team-a --show-labels > /course/1/pa01-namespace.txt
```

## Question 2

```bash
kubectl -n team-a create quota team-a-quota --hard=requests.cpu=2,requests.memory=4Gi,pods=20
kubectl -n team-a apply -f - <<'YAML'
apiVersion: v1
kind: LimitRange
metadata:
  name: team-a-defaults
spec:
  limits:
  - default:
      cpu: 250m
      memory: 256Mi
    defaultRequest:
      cpu: 250m
      memory: 256Mi
    type: Container
YAML
{
  kubectl -n team-a get resourcequota
  kubectl -n team-a get limitrange
} > /course/2/pa02-quota-limits.txt
```

## Question 3

```bash
kubectl -n team-a create sa dev-user
kubectl -n team-a create role dev-bundle --verb=create,get,list,watch --resource=deployments,services,configmaps
kubectl -n team-a create rolebinding dev-bundle-rb --role=dev-bundle --serviceaccount=team-a:dev-user
{
  kubectl -n team-a auth can-i create deployments --as=system:serviceaccount:team-a:dev-user
  kubectl -n team-a auth can-i create rolebindings --as=system:serviceaccount:team-a:dev-user
} > /course/3/pa03-rbac.txt
```

## Question 4

```bash
cat > /course/4/pa04-platformservice.yaml <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformservices.platform.cnpe.io
spec:
  group: platform.cnpe.io
  names:
    kind: PlatformService
    plural: platformservices
    singular: platformservice
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              tier: {type: string}
              owner: {type: string}
              runtime: {type: string}
---
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: orders-api
  namespace: team-a
spec:
  tier: gold
  owner: team-a
  runtime: container
YAML
kubectl apply -f /course/4/pa04-platformservice.yaml
```

## Question 5

```bash
# Se presente Crossplane, crea claim dal tipo disponibile nel lab
{
  kubectl get crd | grep -Ei 'claim|database|xrd' || true
  kubectl -n team-a get all
} > /course/5/pa05-dbclaim.txt
```

## Question 6

```bash
# Crea XRD + Composition minimale (placeholder)
kubectl get xrd,composition 2>/dev/null > /course/6/pa06-composition.yaml || true
```

## Question 7

```bash
kubectl -n team-a apply -f /course/7/default-deny-team-a.yaml
kubectl -n team-a get networkpolicy > /course/7/pa07-isolation.txt
```

## Question 8

```bash
kubectl kustomize /course/8/golden-path/payments > /course/8/pa08-golden-path.yaml
kubectl apply -f /course/8/pa08-golden-path.yaml
```

## Question 9

```bash
# Crea CRD TeamRequest e risorsa
kubectl get crd | grep -i teamrequest || true
kubectl -n team-a get teamrequest 2>/dev/null > /course/9/pa09-teamrequest.txt || true
```

## Question 10

```bash
# Aggiorna CRD con v1beta1 storage
kubectl get crd platformservices.platform.cnpe.io -o yaml > /course/10/pa10-versioning.txt
```

## Question 11

```bash
kubectl -n team-a get events --sort-by=.lastTimestamp | tail -n 40
# fix minimo su claim/composition
kubectl -n team-a get all > /course/11/pa11-troubleshooting.md
```

## Question 12

```bash
{
  kubectl get crd | grep -Ei 'platform|teamrequest|claim|composite|crossplane' || true
  kubectl get ns | grep team || true
  kubectl -n team-a get all
} > /course/12/pa12-platform-report.txt
```
