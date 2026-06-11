# Kyverno Dedicated Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio autonomo con 20 scenari pratici Kyverno basati sulle API CEL
`policies.kyverno.io/v1`.

## Avvio

Prerequisiti: Linux, `kubectl`, `helm`, `curl` e un cluster Kubernetes.

```bash
chmod +x setup-kyverno-lab.sh
./setup-kyverno-lab.sh
```

Il setup installa Kyverno, rende disponibile la CLI `kyverno` e crea gli
starter in `~/course-kyverno`. Ogni directory contiene una policy incompleta
o guasta e risorse positive/negative per verifica locale e admission.

Per rigenerare:

```bash
LAB_FORCE=true ./setup-kyverno-lab.sh
```

## GUI

Usa Lens/OpenLens con il kubeconfig corrente. Le policy sono visibili in
**Custom Resources**; eventi e log sono nei workload del Namespace `kyverno`.

