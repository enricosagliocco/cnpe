# CNPE Specifici - Batteria Dedicata FluxCD - Risposte Guida
> Guida operativa sintetica e verificabile

---

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/2 /course/6
rm -rf /course/2/repo-fluxcd-app /course/6/repo-fluxcd-infra
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-app.git" /course/2/repo-fluxcd-app
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-infra.git" /course/6/repo-fluxcd-infra
```

## Question 1

```bash
{
  kubectl -n flux-system get deploy,pods
  kubectl get crd | grep -E 'source.toolkit.fluxcd.io|kustomize.toolkit.fluxcd.io'
} > /course/1/flux-install-check.txt
```

## Question 2

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

cat > /course/2/flux-app-source.yaml <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-app
  namespace: flux-system
spec:
  interval: 1m
  url: __REPLACE_REPO_URL__
  ref:
    branch: main
YAML
sed -i "s#__REPLACE_REPO_URL__#${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-app.git#g" /course/2/flux-app-source.yaml
kubectl apply -f /course/2/flux-app-source.yaml
```

## Question 3

```bash
cat > /course/3/flux-app-kustomization.yaml <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-app-dev
  namespace: flux-system
spec:
  interval: 1m
  path: ./clusters/dev
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-app
  targetNamespace: flux-lab
YAML
kubectl apply -f /course/3/flux-app-kustomization.yaml
kubectl -n flux-system get gitrepository flux-app
kubectl -n flux-system get kustomization flux-app-dev
```

## Question 4

```bash
kubectl -n flux-lab scale deploy web --replicas=4
kubectl -n flux-system annotate gitrepository flux-app reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n flux-system annotate kustomization flux-app-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
{
  kubectl -n flux-lab get deploy web
  kubectl -n flux-system get kustomization flux-app-dev
} > /course/4/flux-reconcile-drift.txt
```

## Question 5

```bash
kubectl -n flux-system patch kustomization flux-app-dev --type=merge -p '{"spec":{"suspend":true}}'
cd /course/2/repo-fluxcd-app
sed -i 's/replicas: 1/replicas: 2/' apps/web/base/deploy.yaml
git add . && git commit -m "set replicas to 2" && git push
{
  kubectl -n flux-system get kustomization flux-app-dev -o yaml | grep -n suspend
  kubectl -n flux-lab get deploy web
} > /course/5/flux-suspend-resume.txt
kubectl -n flux-system patch kustomization flux-app-dev --type=merge -p '{"spec":{"suspend":false}}'
kubectl -n flux-system annotate kustomization flux-app-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n flux-lab get deploy web >> /course/5/flux-suspend-resume.txt
```

## Question 6

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

cat > /course/6/flux-infra-source.yaml <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-infra
  namespace: flux-system
spec:
  interval: 1m
  url: __REPLACE_REPO_URL__
  ref:
    branch: main
YAML
sed -i "s#__REPLACE_REPO_URL__#${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-infra.git#g" /course/6/flux-infra-source.yaml
kubectl apply -f /course/6/flux-infra-source.yaml
```

## Question 7

```bash
cat > /tmp/flux-infra-dev.yaml <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-infra-dev
  namespace: flux-system
spec:
  interval: 1m
  path: ./tenants/dev
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-infra
YAML
kubectl apply -f /tmp/flux-infra-dev.yaml
kubectl -n flux-system patch kustomization flux-app-dev --type=merge -p '{"spec":{"dependsOn":[{"name":"flux-infra-dev"}]}}'
{
  kubectl -n flux-system get kustomization flux-infra-dev flux-app-dev
  kubectl -n flux-system get kustomization flux-app-dev -o yaml | grep -n dependsOn
} > /course/7/flux-dependson.txt
```

## Question 8

```bash
cd /course/6/repo-fluxcd-infra
git rm -f tenants/dev/namespace.yaml
git add . && git commit -m "remove namespace for prune test" && git push
kubectl -n flux-system annotate kustomization flux-infra-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
{
  kubectl -n flux-system get kustomization flux-infra-dev
  kubectl get ns tenant-dev || true
} > /course/8/flux-prune.txt
```

## Question 9

```bash
kubectl -n flux-system patch kustomization flux-app-dev --type=merge -p '{"spec":{"wait":true,"timeout":"2m"}}'
{
  kubectl -n flux-system describe kustomization flux-app-dev
} > /course/9/flux-health-timeout.txt
```

## Question 10

```bash
cd /course/2/repo-fluxcd-app
git checkout -b stage
git push -u origin stage

GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

cat > /tmp/flux-app-stage-source.yaml <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-app-stage
  namespace: flux-system
spec:
  interval: 1m
  url: __REPLACE_REPO_URL__
  ref:
    branch: stage
YAML
sed -i "s#__REPLACE_REPO_URL__#${GITEA_URL%/}/${GITEA_OWNER}/cnpe-specific-fluxcd-app.git#g" /tmp/flux-app-stage-source.yaml
kubectl apply -f /tmp/flux-app-stage-source.yaml

cat > /tmp/flux-app-stage-kustomization.yaml <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-app-stage
  namespace: flux-system
spec:
  interval: 1m
  path: ./clusters/dev
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-app-stage
  targetNamespace: flux-lab
YAML
kubectl apply -f /tmp/flux-app-stage-kustomization.yaml
kubectl -n flux-system get gitrepository,kustomization > /course/10/flux-multibranch.txt
```

## Question 11

```bash
cd /course/2/repo-fluxcd-app
git checkout main
printf 'apiVersion: v1\nkind: Service\nmetadata:\n  name:\n' > clusters/dev/broken.yaml
echo '- broken.yaml' >> clusters/dev/kustomization.yaml
git add . && git commit -m "introduce invalid manifest" && git push
kubectl -n flux-system annotate kustomization flux-app-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

{
  kubectl -n flux-system get kustomization flux-app-dev
  kubectl -n flux-system describe kustomization flux-app-dev
} > /course/11/flux-failure-recovery.txt

git reset --hard HEAD~1
git push --force
kubectl -n flux-system annotate kustomization flux-app-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n flux-system get kustomization flux-app-dev >> /course/11/flux-failure-recovery.txt
```

## Question 12

```bash
{
  kubectl -n flux-system get gitrepository
  kubectl -n flux-system get kustomization
  kubectl -n flux-lab get all
} > /course/12/flux-final-report.txt
```
