# RKE2 Single Instance (senza HAProxy)

Questa cartella crea un cluster RKE2 single-node con Traefik Gateway API abilitato e NodePort esposti su:

- HTTP: `30080`
- HTTPS: `30443`

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
sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system | grep traefik-gateway-nodeport
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
curl -H 'Host: nginx.example.local' http://127.0.0.1:30080/
```

Oppure dall'host verso l'IP VM:

```bash
curl -H 'Host: nginx.example.local' http://192.168.1.21:30080/
```

Su Windows (Cmder/CMD), usa doppi apici:

```bat
curl -H "Host: nginx.example.local" http://192.168.1.21:30080/
```

Su PowerShell, puoi usare:

```powershell
curl.exe -H "Host: nginx.example.local" "http://192.168.1.21:30080/"
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

- Verifica porte NodePort sul nodo:

```bash
sudo ss -tlnp | grep -E '30080|30443'
```
