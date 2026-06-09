# Argo Rollouts Dedicated Lab

Laboratorio autonomo con 20 esercizi dedicati ad Argo Rollouts.

## Avvio con Minikube o cluster esistente

```bash
chmod +x setup-argo-rollouts-lab.sh
./setup-argo-rollouts-lab.sh
```

## Avvio con kind

```bash
chmod +x setup-argo-rollouts-lab-kind.sh
./setup-argo-rollouts-lab-kind.sh
```

Il setup installa Argo Rollouts v1.9.0 e crea gli starter in
`~/course-argo-rollouts`. La versione è sovrascrivibile con
`ARGO_ROLLOUTS_VERSION`.

Per la CLI installa il plugin `kubectl argo rollouts`, oppure usa `kubectl`
per tutti gli esercizi. Per rigenerare usa `LAB_FORCE=true`.
