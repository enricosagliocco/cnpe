# CNPE Specifici - Lacune Mirate - GitOps e Continuous Delivery - Risposte Guida
> Guida operativa sintetica e verificabile

---

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/2 /course/5 /course/8
rm -rf /course/2/repo-gitops /course/5/repo-flux /course/8/repo-gitops
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-lacune-gitops-repo-gitops.git" /course/2/repo-gitops
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-lacune-gitops-repo-flux.git" /course/5/repo-flux
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-lacune-gitops-repo-gitops.git" /course/8/repo-gitops
```

## Question 1

```bash
{
  kubectl -n argocd get deploy argocd-application-controller argocd-server
  kubectl -n argocd get sa argocd-application-controller
  kubectl -n argocd get pods
} > /course/1/gc01-argocd-check.txt
```

## Question 2

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

cat > /course/2/app-gc02.yaml <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-gc02
  namespace: argocd
spec:
  project: default
  source:
    repoURL: __REPLACE_REPO_URL__
    targetRevision: main
    path: manifests/base
  destination:
    server: https://kubernetes.default.svc
    namespace: ns-gc-app
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
YAML
sed -i "s#__REPLACE_REPO_URL__#${GITEA_URL%/}/${GITEA_OWNER}/cnpe-lacune-gitops-repo-gitops.git#g" /course/2/app-gc02.yaml
kubectl apply -f /course/2/app-gc02.yaml
kubectl -n argocd get app app-gc02
```

## Question 3

```bash
kubectl -n ns-gc-app scale deploy app-gc02 --replicas=5
kubectl -n argocd patch app app-gc02 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}'
{
  kubectl -n ns-gc-app get deploy app-gc02 -o wide
  kubectl -n argocd get app app-gc02
} > /course/3/gc03-selfheal.txt
```

## Question 4

```bash
kubectl -n argocd patch app app-gc02 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true,"allowEmpty":true}}}}'
# Rimuovi risorsa da repo e fai commit
{
  kubectl -n argocd get app app-gc02
  kubectl -n ns-gc-app get all
} > /course/4/gc04-prune.txt
```

## Question 5

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"

cat > /course/5/gc05-flux.yaml <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gc05-repo
  namespace: flux-system
spec:
  interval: 1m
  url: __REPLACE_REPO_URL__
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: gc05-app
  namespace: flux-system
spec:
  interval: 1m
  path: ./overlays/dev
  prune: true
  sourceRef:
    kind: GitRepository
    name: gc05-repo
YAML
sed -i "s#__REPLACE_REPO_URL__#${GITEA_URL%/}/${GITEA_OWNER}/cnpe-lacune-gitops-repo-flux.git#g" /course/5/gc05-flux.yaml
kubectl apply -f /course/5/gc05-flux.yaml
kubectl -n flux-system get gitrepository,kustomization > /course/5/gc05-flux-ready.txt
```

## Question 6

```bash
# Crea HelmRepository + HelmRelease
kubectl -n flux-system get helmrepository,helmrelease > /course/6/gc06-helmrelease.txt
# Dopo fix/rollback aggiungi nuovo stato
kubectl -n flux-system get helmrepository,helmrelease >> /course/6/gc06-helmrelease.txt
```

## Question 7

```bash
kubectl kustomize /course/7/repo-kustomize/overlays/dev > /tmp/gc07-dev.yaml
kubectl kustomize /course/7/repo-kustomize/overlays/stage > /course/7/gc07-render-stage.yaml
kubectl apply -f /course/7/gc07-render-stage.yaml
```

## Question 8

```bash
cd /course/8/repo-gitops
git checkout dev
# update image v2
git add . && git commit -m "promote candidate v2 in dev"
git checkout stage
git cherry-pick dev
{
  git log --oneline -n 5
  kubectl -n argocd get app
} > /course/8/gc08-promotion.txt
```

## Question 9

```bash
# Usa annotation argocd.argoproj.io/sync-wave
kubectl -n argocd get app app-gc09
kubectl -n ns-gc09 get events --sort-by=.lastTimestamp > /course/9/gc09-sync-wave.txt
```

## Question 10

```bash
# Commit update immagine nel repo GitOps del rollout
kubectl -n rollouts-lab get rollout payments > /course/10/gc10-rollout-gitops.txt
kubectl -n rollouts-lab get rs >> /course/10/gc10-rollout-gitops.txt
```

## Question 11

```bash
kubectl -n argocd get app app-gc11
kubectl -n argocd describe app app-gc11
# Fix in Git e nuovo sync
kubectl -n argocd get app app-gc11 > /course/11/gc11-troubleshooting.md
```

## Question 12

```bash
{
  kubectl -n argocd get app
  kubectl -n flux-system get gitrepository,kustomization,helmrelease
  kubectl get deploy -A
} > /course/12/gc12-final-report.txt
```
