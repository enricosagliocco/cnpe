# Flux CD Dedicated Lab

Laboratorio autonomo con 20 esercizi exam-style dedicati a:

- Source Controller e `GitRepository`;
- Kustomize Controller e `Kustomization`;
- repository Gitea contenenti YAML e overlay Kustomize;
- repository Helm ufficiali e tool standalone tramite `HelmRelease`.

Il setup crea e popola `flux-platform` nell'organizzazione Gitea con manifest
YAML, base e overlay Kustomize. Gli esercizi Helm usano i repository ufficiali
di Headlamp, Metrics Server e Prometheus Community.

## Avvio con Minikube o cluster esistente

Prerequisiti: `kubectl`, `curl`, `git` e un cluster Kubernetes raggiungibile.
Se il cluster non è disponibile, lo script prova ad avviare Minikube.

```bash
chmod +x setup-fluxcd-lab.sh
export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_ORG="${GITEA_ORG:-organization}"
./setup-fluxcd-lab.sh
```

## Avvio con kind

```bash
chmod +x setup-fluxcd-lab-kind.sh
./setup-fluxcd-lab-kind.sh
```

Il setup installa Flux CD `v2.8.8` e genera gli starter in
`~/course-fluxcd`. La versione è sovrascrivibile con `FLUX_VERSION`.

Per rigenerare:

```bash
LAB_FORCE=true ./setup-fluxcd-lab-kind.sh
```

Comandi utili:

```bash
kubectl -n flux-system get gitrepositories,helmrepositories
kubectl -n flux-system get kustomizations,helmreleases
kubectl get events -A --sort-by=.lastTimestamp
```
