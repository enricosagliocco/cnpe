# CNPE Specifici - Batteria Bilanciata 01 - Risposte Guida

## Question 1
```bash
kubectl apply -f /course/1/app-b01.yaml
kubectl -n argocd get app app-b01 > /course/1/b01-q01.txt
```

## Question 2
```bash
kubectl -n ns-b01-app scale deploy app-b01 --replicas=5
kubectl -n argocd patch app app-b01 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}'
kubectl -n ns-b01-app get deploy app-b01 > /course/2/b01-q02.txt
```

## Question 3
```bash
kubectl -n argocd patch app app-b01 --type='merge' -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n ns-b01-app get all > /course/3/b01-q03.txt
```

## Question 4
```bash
kubectl apply -f /course/4/flux-b01.yaml
kubectl -n flux-system get gitrepository,kustomization > /course/4/b01-q04.txt
```

## Question 5
```bash
cd /course/5/repo-gitops && git log --oneline -n 10 > /course/5/b01-q05.txt
kubectl -n argocd get app >> /course/5/b01-q05.txt
```

## Question 6
```bash
kubectl label ns ns-b01-sec pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl label ns ns-b01-sec pod-security.kubernetes.io/enforce-version=latest --overwrite
kubectl -n ns-b01-sec get events --sort-by=.lastTimestamp > /course/6/b01-q06.txt
```

## Question 7
```bash
kubectl -n ns-b01-sec create sa auditor
kubectl -n ns-b01-sec create role pod-reader --verb=get,list --resource=pods
kubectl -n ns-b01-sec create rolebinding pod-reader-auditor --role=pod-reader --serviceaccount=ns-b01-sec:auditor
kubectl -n ns-b01-sec auth can-i delete pods --as=system:serviceaccount:ns-b01-sec:auditor > /course/7/b01-q07.txt
```

## Question 8
```bash
kubectl get cpol > /course/8/b01-q08.txt
```

## Question 9
```bash
kubectl get constrainttemplates > /course/9/b01-q09.txt
kubectl get constraints -A >> /course/9/b01-q09.txt
```

## Question 10
```bash
kubectl -n ns-b01-team get networkpolicy > /course/10/b01-q10.txt
```

## Question 11
```bash
kubectl get ns team-b01 --show-labels > /course/11/b01-q11.txt
```

## Question 12
```bash
kubectl -n team-b01 get resourcequota,limitrange > /course/12/b01-q12.txt
```

## Question 13
```bash
kubectl apply -f /course/13/b01-q13.yaml
```

## Question 14
```bash
kubectl get xrd,composition 2>/dev/null > /course/14/b01-q14.txt || true
```

## Question 15
```bash
{
  kubectl -n argocd get app
  kubectl get cpol
  kubectl get crd | grep -Ei 'platform|teamdatabase|claim|composite' || true
} > /course/15/b01-q15-report.txt
```
