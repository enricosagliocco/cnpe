# Argo Workflows Dedicated Lab

Laboratorio autonomo con 20 esercizi dedicati ad Argo Workflows.

## Avvio con Minikube o cluster esistente

```bash
chmod +x setup-argo-workflows-lab.sh
./setup-argo-workflows-lab.sh
```

## Avvio con kind

```bash
chmod +x setup-argo-workflows-lab-kind.sh
./setup-argo-workflows-lab-kind.sh
```

Il setup installa Argo Workflows v4.0.5 e crea gli starter in
`~/course-argo-workflows`. La versione è sovrascrivibile con
`ARGO_WORKFLOWS_VERSION`.

```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
```

Apri `https://127.0.0.1:2746`. Per rigenerare usa `LAB_FORCE=true`.
