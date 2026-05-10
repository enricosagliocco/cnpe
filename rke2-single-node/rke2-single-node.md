# RKE2 Single Node con Traefik Gateway API (80/443)

Questa guida descrive come avviare un ambiente **RKE2 single-node** (control-plane + worker sullo stesso nodo) con **Traefik Gateway API** esposto su **porta 80 e 443**.

## Prerequisiti

- Vagrant installato
- VMware provider per Vagrant configurato
- Box Vagrant `rocky9-updated` disponibile
- Rete bridge `WLAN` disponibile (come da Vagrantfile)

## Struttura

- Vagrantfile: provisioning VM single-node
- scripts/common_os_prep.sh: preparazione OS
- scripts/install_rke2_single.sh: installazione RKE2 e configurazione ruolo worker
- scripts/setup_traefik_gateway.sh: Service Traefik su 80/443
- scripts/setup_kubectl_alias.sh: alias kubectl per root
- examples/nginx-gateway-demo.yaml: demo Gateway API

## Avvio ambiente

Dalla cartella `rancher/rke2-single-node`:

```bash
vagrant up --provider=vmware_desktop
```

Accesso alla VM:

```bash
vagrant ssh rke2-single
```

## Verifiche cluster

Nel nodo VM:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl get nodes -o wide
sudo /var/lib/rancher/rke2/bin/kubectl get pods -A
```

Verifica Traefik e GatewayClass:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl get gatewayclass
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get svc traefik-gateway-nodeport
```

Output atteso per il service Traefik:

- `TYPE`: `NodePort`
- porte esposte: `80` e `443`

## Deploy demo Gateway API

Applica la demo:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl apply -f /vagrant/examples/nginx-gateway-demo.yaml
```

Verifiche demo:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n demo get gateway
sudo /var/lib/rancher/rke2/bin/kubectl -n demo get httproute
sudo /var/lib/rancher/rke2/bin/kubectl -n demo get pods,svc
```

## Test traffico HTTP dal tuo host

Test con host header (obbligatorio per la route):

```bash
curl -H "Host: nginx.example.local" http://192.168.1.21/
```

Test HTTPS (se non hai ancora certificati validi lato route):

```bash
curl -k -H "Host: nginx.example.local" https://192.168.1.21/
```

## Comandi utili troubleshooting

Log RKE2:

```bash
sudo journalctl -u rke2-server -f
```

Stato Traefik:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get pods -l app.kubernetes.io/name=rke2-traefik -o wide
```

Descrizione service Traefik:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system describe svc traefik-gateway-nodeport
```

## Spegnimento e cleanup

Dalla cartella `rancher/rke2-single-node`:

```bash
vagrant halt
```

Distruzione completa VM:

```bash
vagrant destroy -f
```
