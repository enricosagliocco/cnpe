# CNPE Specifici - Lacune Mirate - Security e Policy Enforcement - Risposte Guida

---

## Question 1

```bash
kubectl label ns ns-sp01 pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl label ns ns-sp01 pod-security.kubernetes.io/enforce-version=latest --overwrite
{
  kubectl get ns ns-sp01 --show-labels
  kubectl -n ns-sp01 run bad --image=nginx --privileged --dry-run=server
} > /course/1/sp01-pss.txt 2>&1 || true
```

## Question 2

```bash
kubectl -n ns-sp02 create sa auditor
kubectl -n ns-sp02 create role pod-reader --verb=get,list --resource=pods
kubectl -n ns-sp02 create rolebinding pod-reader-auditor --role=pod-reader --serviceaccount=ns-sp02:auditor
{
  kubectl -n ns-sp02 auth can-i list pods --as=system:serviceaccount:ns-sp02:auditor
  kubectl -n ns-sp02 auth can-i delete pods --as=system:serviceaccount:ns-sp02:auditor
} > /course/2/sp02-rbac.txt
```

## Question 3

```bash
kubectl -n ns-sp03 create sa runner
kubectl -n ns-sp03 patch sa runner --type='merge' -p '{"automountServiceAccountToken":false}'
# associa SA a deployment
kubectl -n ns-sp03 get sa runner -o yaml > /course/3/sp03-sa-hardening.txt
```

## Question 4

```bash
# crea ClusterPolicy require labels
kubectl get cpol > /course/4/sp04-kyverno-labels.txt
# test pod non conforme + conforme e append output
```

## Question 5

```bash
# crea policy deny latest
{
  kubectl get cpol
  kubectl -n ns-sp05 apply -f /course/5/deploy-latest.yaml
  kubectl -n ns-sp05 apply -f /course/5/deploy-pinned.yaml
} > /course/5/sp05-deny-latest.txt 2>&1 || true
```

## Question 6

```bash
# applica ConstraintTemplate + Constraint
{
  kubectl get constrainttemplates
  kubectl get constraints -A
} > /course/6/sp06-gatekeeper.txt
```

## Question 7

```bash
kubectl -n ns-sp07 apply -f /course/7/default-deny.yaml
kubectl -n ns-sp07 apply -f /course/7/allow-intra-ns-80.yaml
kubectl -n ns-sp07 get networkpolicy > /course/7/sp07-networkpolicy.txt
```

## Question 8

```bash
kubectl -n ns-sp08 create secret generic app-credentials --from-literal=username=app --from-literal=password=oldpass
# mount secret + rotate
kubectl -n ns-sp08 get secret app-credentials -o yaml > /course/8/sp08-secret-rotation.txt
```

## Question 9

```bash
{
  kubectl get cpol | grep -Ei 'verify|image|cosign' || true
  kubectl -n ns-sp09 get events --sort-by=.lastTimestamp | tail -n 40
} > /course/9/sp09-provenance.txt
```

## Question 10

```bash
# crea eccezione minimizzata e verifica
{
  kubectl get cpol -A
  kubectl get policyexception -A 2>/dev/null || true
} > /course/10/sp10-exception.txt
```

## Question 11

```bash
kubectl -n ns-sp11 describe deploy app-sp11
kubectl -n ns-sp11 get events --sort-by=.lastTimestamp | tail -n 40
# fix minimo
kubectl -n ns-sp11 get pods > /course/11/sp11-troubleshooting.md
```

## Question 12

```bash
{
  kubectl get cpol
  kubectl get constrainttemplates
  kubectl get constraints -A
  kubectl get deploy -A | grep ns-sp || true
} > /course/12/sp12-compliance-report.txt
```
