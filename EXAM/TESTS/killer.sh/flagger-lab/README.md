# Flagger Dedicated Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

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

Il setup installa Flagger 1.43.0 con provider Kubernetes, il Prometheus
integrato nel chart, il load tester e un receiver HTTP locale per webhook e
alert. Gli starter vengono creati in `~/course-flagger`. Le versioni sono
sovrascrivibili con `FLAGGER_VERSION` e `LOADTESTER_VERSION`.

```bash
kubectl -n flagger-system logs deploy/flagger -f
kubectl -n flagger-system logs deploy/flagger-receiver -f
kubectl -n flagger-lab get canaries
```

Per rigenerare lo scenario:

```bash
LAB_FORCE=true ./setup-flagger-lab-kind.sh
```

Il provider Kubernetes rende il lab base leggero e ripetibile. Gli esercizi
dedicati a NGINX e Gateway API includono gli starter da validare, ma non
installano automaticamente ingress controller, Gateway API CRD o relativi
controller.

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-flagger-lab.sh
```
