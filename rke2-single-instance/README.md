# RKE2 Single Instance (senza HAProxy)

Questa cartella crea un cluster RKE2 single-node con Traefik Gateway API abilitato e Service LoadBalancer esposto su porte standard:

- HTTP: `80`
- HTTPS: `443`

## Prerequisiti

- Vagrant
- VMware provider per Vagrant
- Box `rocky9-updated`

## Avvio ambiente

Dalla cartella `single-instance`:

```bash
vagrant up --provider=vmware_desktop
```

Accesso al nodo:

```bash
vagrant ssh rke2-single
```

## Verifiche base cluster

Nel nodo:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl get nodes -o wide
sudo /var/lib/rancher/rke2/bin/kubectl get pods -A
sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system rke2-traefik
sudo /var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l app=svclb-rke2-traefik
```

## Test Gateway API (nginx demo)

Sono inclusi i file demo in `examples/`:

- `nginx-gateway-demo.yaml`: namespace + nginx + Gateway + HTTPRoute
- `test-gateway.sh`: deploy e smoke test HTTP
- `cleanup-gateway.sh`: cleanup risorse demo

### 1) Esegui il test

Dal tuo host (cartella `single-instance`):

```bash
vagrant ssh rke2-single -c "sudo bash /vagrant/examples/test-gateway.sh"
```

Se il test e corretto vedrai: `Test OK: gateway funzionante (HTTP 200)`.

### 2) Test manuale

Sempre dal nodo:

```bash
curl -H 'Host: nginx.example.local' http://127.0.0.1/
```

Oppure dall'host verso l'IP VM:

```bash
curl -H 'Host: nginx.example.local' http://192.168.1.21/
```

Su Windows (Cmder/CMD), usa doppi apici:

```bat
curl -H "Host: nginx.example.local" http://192.168.1.21/
```

Su PowerShell, puoi usare:

```powershell
curl.exe -H "Host: nginx.example.local" "http://192.168.1.21/"
```

### 3) Cleanup demo

```bash
vagrant ssh rke2-single -c "sudo bash /vagrant/examples/cleanup-gateway.sh"
```

## Troubleshooting rapido

- `404 page not found`: di solito l'header `Host` non viene passato correttamente.
	Riprova con i comandi Windows sopra (doppi apici o `curl.exe` in PowerShell).

- Gateway non pronto:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n demo describe gateway web-gw
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get pods | grep traefik
```

- Route non agganciata:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n demo describe httproute nginx-route
```

- Verifica porte standard sul nodo:

```bash
sudo ss -tlnp | grep -E ':80|:443'
```

- `EXTERNAL-IP` di `rke2-traefik` in `pending`:
	verifica che ServiceLB sia attivo (su single-node e necessario per `LoadBalancer`).

```bash
grep -n "enable-servicelb" /etc/rancher/rke2/config.yaml
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get ds | grep -i svclb
```

- `EXTERNAL-IP` di `rke2-traefik` su rete sbagliata (es. `192.168.75.x`):
	imposta `node-ip` e `node-external-ip` in `/etc/rancher/rke2/config.yaml` con l'IP bridged (es. `192.168.1.21`) e riavvia RKE2.

```bash
sudo grep -nE 'node-ip|node-external-ip' /etc/rancher/rke2/config.yaml
sudo systemctl restart rke2-server
sudo /var/lib/rancher/rke2/bin/kubectl get node -o wide
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get svc rke2-traefik -o wide
```

- Pod `rke2-traefik` in `Pending` con errore `didn't have free ports for the requested pod ports`:
	con ServiceLB attivo, evita il conflitto disabilitando `hostPort` di Traefik (nel nostro setup e gia gestito dallo script `install_rke2_single.sh`).

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system describe pod -l app.kubernetes.io/name=rke2-traefik | grep -i "didn't have free ports" || true
sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get pods -o wide | grep -Ei 'rke2-traefik|svclb'
```
