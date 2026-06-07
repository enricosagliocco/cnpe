# Crossplane Dedicated Lab

Laboratorio autonomo con 20 esercizi deterministici dedicati a Crossplane v2.
Usa esclusivamente risorse Kubernetes locali per non richiedere account cloud.

## Avvio

Prerequisiti: Linux, `kubectl`, `helm` e un cluster Kubernetes.

```bash
chmod +x setup-crossplane-lab.sh
./setup-crossplane-lab.sh
```

Il materiale viene creato in `~/course-crossplane`. Il setup installa
Crossplane e Function Patch and Transform v0.8.2. Gli esercizi contengono XRD,
Composition e XR incompleti o guasti da applicare e verificare.

Per la GUI usa Lens/OpenLens importando il kubeconfig corrente; XRD,
Composition, XR, eventi e risorse composte sono visibili in **Custom
Resources**. Crossplane non installa una dashboard web dedicata.
