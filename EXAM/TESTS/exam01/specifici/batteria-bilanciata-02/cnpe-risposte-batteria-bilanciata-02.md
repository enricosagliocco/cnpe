# CNPE Specifici - Batteria Bilanciata 02 - Risposte Guida

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
mkdir -p /course/1
rm -rf /course/1/repo-gitops
git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-bilanciata-02-repo-gitops.git" /course/1/repo-gitops
```

## Question 1
```bash
kubectl apply -f /course/1/app-b02.yaml
kubectl -n argocd get app app-b02 > /course/1/b02-q01.txt
```
## Question 2
```bash
kubectl -n argocd describe app app-b02 > /course/2/b02-q02.md
```
## Question 3
```bash
kubectl -n argocd patch app app-b02 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n argocd get app app-b02 > /course/3/b02-q03.txt
```
## Question 4
```bash
kubectl apply -f /course/4/flux-b02.yaml
kubectl -n flux-system get gitrepository,kustomization > /course/4/b02-q04.txt
```
## Question 5
```bash
kubectl -n flux-system get helmrelease > /course/5/b02-q05.txt
```
## Question 6
```bash
kubectl label ns ns-b02-sec pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl -n ns-b02-sec get events --sort-by=.lastTimestamp > /course/6/b02-q06.txt
```
## Question 7
```bash
kubectl -n ns-b02-sec auth can-i list pods --as=system:serviceaccount:ns-b02-sec:team-reader > /course/7/b02-q07.txt
```
## Question 8
```bash
kubectl get cpol > /course/8/b02-q08.txt
```
## Question 9
```bash
kubectl get constrainttemplates > /course/9/b02-q09.txt
```
## Question 10
```bash
kubectl -n ns-b02-team get networkpolicy > /course/10/b02-q10.txt
```
## Question 11
```bash
kubectl get ns team-b02 --show-labels > /course/11/b02-q11.txt
```
## Question 12
```bash
kubectl -n team-b02 get resourcequota,limitrange > /course/12/b02-q12.txt
```
## Question 13
```bash
kubectl apply -f /course/13/b02-q13.yaml
```
## Question 14
```bash
kubectl get crd platformservices.platform.cnpe.io -o yaml > /course/14/b02-q14.txt
```
## Question 15
```bash
{
  kubectl -n argocd get app
  kubectl get cpol
  kubectl get crd | grep -Ei 'platform|service|claim' || true
} > /course/15/b02-q15-report.txt
```
