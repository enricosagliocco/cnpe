# Tekton Dedicated Lab

Laboratorio autonomo con 20 esercizi deterministici dedicati a Tekton
Pipelines.

## Avvio con Minikube

Prerequisiti: Linux, `kubectl`, `curl` e Minikube.

```bash
chmod +x setup-tekton-lab.sh
./setup-tekton-lab.sh
```

## Avvio con kind

Prerequisiti: Linux, Docker o Podman, `kubectl`, `curl` e `kind`.

```bash
chmod +x setup-tekton-lab-kind.sh
./setup-tekton-lab-kind.sh
```

Il cluster viene creato con il nome `tekton-lab`. Puoi cambiarlo impostando
`KIND_CLUSTER_NAME`, per esempio:

```bash
KIND_CLUSTER_NAME=cnpe ./setup-tekton-lab-kind.sh
```

La variante kind installa anche il local-path provisioner e lo configura come
StorageClass predefinita, necessario per gli esercizi che creano PVC.

Il setup installa Tekton Pipelines v1.9.0 LTS, Tekton Dashboard e crea gli
starter in `~/course-tekton`. Ogni directory contiene una risorsa incompleta o
guasta e un Run con cui verificare la correzione. Per aprire la GUI:

```bash
kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 30120:9097
```

Apri `http://127.0.0.1:30120`. Per rigenerare:
`LAB_FORCE=true ./setup-tekton-lab-kind.sh` (oppure lo script Minikube).
