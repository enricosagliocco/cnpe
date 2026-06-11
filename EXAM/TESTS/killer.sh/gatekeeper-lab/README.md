# Gatekeeper Dedicated Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio autonomo con 20 esercizi dedicati a OPA Gatekeeper.

Ogni esercizio indica file starter, nomi delle risorse, parametri obbligatori
e risultato atteso dei test. Le risorse sono predisposte per evitare che le
policy delle domande precedenti nascondano il comportamento da verificare.

## Avvio

Prerequisiti:

- Linux
- `kubectl`
- accesso a un cluster Kubernetes, oppure Minikube installato
- accesso Internet durante il setup

```bash
chmod +x setup-gatekeeper-lab.sh
./setup-gatekeeper-lab.sh
```

Il materiale viene creato in `~/course-gatekeeper`. Per usare un percorso diverso:

```bash
COURSE_DIR=/path/del/lab ./setup-gatekeeper-lab.sh
```

Lo script protegge un lab gia inizializzato. Per rigenerare e sovrascrivere gli
starter file:

```bash
LAB_FORCE=true ./setup-gatekeeper-lab.sh
```

## Struttura

- `setup-gatekeeper-lab.sh`: installa Gatekeeper e prepara lo scenario.
- `domande.md`: contiene le 20 domande.
- `~/course-gatekeeper/01` ... `~/course-gatekeeper/20`: starter file e manifest di test.

## Verifica iniziale

```bash
kubectl -n gatekeeper-system get pods
kubectl get constrainttemplates
kubectl get constraints
```

Gatekeeper puo richiedere 1-2 minuti per diventare operativo.

## Reset

Per ricominciare completamente:

```bash
kubectl delete ns apps dev staging prod exempt legacy team-a team-b --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.22.2/deploy/gatekeeper.yaml
rm -rf ~/course-gatekeeper
```

## Accesso GUI

Apri il cluster in Lens/OpenLens usando il kubeconfig corrente. I
ConstraintTemplate e i Constraint sono disponibili in **Custom Resources**;
eventi e log di audit sono visibili dai workload in `gatekeeper-system`.
Gatekeeper non espone una dashboard web propria.
