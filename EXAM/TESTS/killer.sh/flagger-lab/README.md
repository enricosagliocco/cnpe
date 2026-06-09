# Flagger Dedicated Lab

Laboratorio autonomo con 20 esercizi dedicati a Flagger.

## Avvio con Minikube o cluster esistente

Prerequisiti: `kubectl`, Helm 3 e un cluster Kubernetes raggiungibile. Se il
cluster non è disponibile, lo script prova ad avviare Minikube.

```bash
chmod +x setup-flagger-lab.sh
./setup-flagger-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kubectl`, Helm 3 e `kind`.

```bash
chmod +x setup-flagger-lab-kind.sh
./setup-flagger-lab-kind.sh
```

Il setup installa Flagger 1.43.0 con il provider Kubernetes, il load tester e
crea gli starter in `~/course-flagger`. La versione è sovrascrivibile con
`FLAGGER_VERSION`.

```bash
kubectl -n flagger-system logs deploy/flagger -f
kubectl -n flagger-lab get canaries
```

Per rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-flagger-lab-kind.sh
```

Il provider Kubernetes rende il lab base leggero e ripetibile. Gli esercizi
dedicati a NGINX, Istio e Gateway API richiedono di completare i manifest, ma
non installano automaticamente tutti i provider di routing.
