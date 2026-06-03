# Minikube — Installazione su VM Rocky Linux 9

Questa cartella crea una VM Rocky Linux 9 (box `rocky9-updated`) e installa automaticamente:

- Docker Engine
- kubectl
- Minikube
- cluster Kubernetes locale con profilo `cnpe`

## Struttura

```text
minikube/
├── README.md
├── Vagrantfile
└── scripts/
    └── install_minikube.sh
```

## Avvio

Dalla cartella `minikube/`:

```bash
vagrant up --provider=vmware_desktop
```

Per entrare nella VM:

```bash
vagrant ssh
```

## Configurazione prevista

- Hostname VM: `minikube-rocky9`
- IP bridged: `192.168.1.58`
- Profilo Minikube: `cnpe`
- Versione Minikube: `v1.35.0`
- Versione Kubernetes: `v1.30.0`

## Verifiche rapide

```bash
minikube status -p cnpe
kubectl get nodes -o wide
kubectl get pods -A
```

## Comandi utili

Dashboard URL:

```bash
minikube dashboard -p cnpe --url
```

Stop cluster:

```bash
minikube stop -p cnpe
```

Delete cluster:

```bash
minikube delete -p cnpe
```
