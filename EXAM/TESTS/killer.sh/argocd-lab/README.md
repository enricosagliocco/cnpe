# Argo CD Dedicated Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio autonomo con 20 esercizi dedicati ad Argo CD.

## Avvio con Minikube o cluster esistente

Prerequisiti: `kubectl`, `curl`, `git` e un cluster Kubernetes raggiungibile.
Se il cluster non è disponibile, lo script prova ad avviare Minikube.

```bash
chmod +x setup-argocd-lab.sh
export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_ORG="${GITEA_ORG:-organization}"
./setup-argocd-lab.sh
```

## Avvio con kind

Prerequisiti: Docker o Podman, `kubectl` e `kind`.

```bash
chmod +x setup-argocd-lab-kind.sh
./setup-argocd-lab-kind.sh
```

Il setup crea nell'organizzazione Gitea i repository pubblici
`argocd-example-apps` e `argocd-extra-apps`, installa Argo CD v3.4.3 e genera
gli starter in `~/course-argocd`. La versione è sovrascrivibile con
`ARGO_CD_VERSION`.

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Apri `https://127.0.0.1:8080` e accedi come `admin`. Per rigenerare:

```bash
LAB_FORCE=true ./setup-argocd-lab-kind.sh
```

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-argocd-lab.sh
```
