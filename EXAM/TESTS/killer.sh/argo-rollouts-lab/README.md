# Argo Rollouts Dedicated Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

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

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-argo-rollouts-lab.sh
```
