# CNPE Specifici - Batteria Bilanciata 03 - Risposte Guida

## Question 1
```bash
kubectl apply -f /course/1/app-b03.yaml
kubectl -n argocd get app app-b03 > /course/1/b03-q01.txt
```
## Question 2
```bash
kubectl -n argocd patch app app-b03 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n argocd get app app-b03 > /course/2/b03-q02.txt
```
## Question 3
```bash
kubectl -n rollouts-lab get rollout > /course/3/b03-q03.txt
```
## Question 4
```bash
kubectl -n flux-system get gitrepository,kustomization > /course/4/b03-q04.txt
```
## Question 5
```bash
cd /course/5/repo-gitops && git log --oneline -n 10 > /course/5/b03-q05.txt
```
## Question 6
```bash
kubectl -n ns-b03-sec get events --sort-by=.lastTimestamp > /course/6/b03-q06.txt
```
## Question 7
```bash
kubectl -n ns-b03-sec auth can-i create deployments --as=system:serviceaccount:ns-b03-sec:team-sa > /course/7/b03-q07.txt
```
## Question 8
```bash
kubectl get cpol > /course/8/b03-q08.txt
```
## Question 9
```bash
kubectl get constrainttemplates,constraints -A > /course/9/b03-q09.txt
```
## Question 10
```bash
kubectl -n ns-b03-team get networkpolicy > /course/10/b03-q10.txt
```
## Question 11
```bash
kubectl get ns team-b03 --show-labels > /course/11/b03-q11.txt
```
## Question 12
```bash
kubectl -n team-b03 get resourcequota,limitrange > /course/12/b03-q12.txt
```
## Question 13
```bash
kubectl apply -f /course/13/b03-q13.yaml
```
## Question 14
```bash
kubectl get xrd,composition 2>/dev/null > /course/14/b03-q14.md || true
```
## Question 15
```bash
{
  kubectl -n argocd get app
  kubectl get cpol
  kubectl get crd | grep -Ei 'teamrequest|platform|claim|composition' || true
} > /course/15/b03-q15-report.txt
```
