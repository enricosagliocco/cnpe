# Crossplane Dedicated Lab

Laboratorio autonomo con 20 esercizi deterministici in stile esame dedicati a
Crossplane v2. Ogni domanda fornisce una XRD e una Composition complete: il
candidato deve applicarle, creare l'XR richiesto e verificare tutte le risorse
composte. Gli scenari sono indipendenti e usano esclusivamente risorse
Kubernetes locali.

## Avvio

Prerequisiti: Linux, `kubectl`, `helm` e un cluster Kubernetes.

```bash
chmod +x setup-crossplane-lab.sh
./setup-crossplane-lab.sh
```

Il materiale viene creato in `~/course-crossplane`. Il setup installa
Crossplane e Function Patch and Transform v0.8.2; l'installazione della
Function può richiedere 1-2 minuti. Ogni directory contiene `xrd.yaml`,
`composition.yaml`, `QUESTION.md` ed `evidence.txt`.

Per la GUI usa Lens/OpenLens importando il kubeconfig corrente; XRD,
Composition, XR, eventi e risorse composte sono visibili in **Custom
Resources**. Crossplane non installa una dashboard web dedicata.
