# RKE2 Single Instance (senza HAProxy)

Questa cartella crea un cluster RKE2 single-node con Traefik usato come controller Gateway API, non come controller Ingress. Il Service LoadBalancer di Traefik espone le porte standard:

- HTTP: `80`
- HTTPS: `443`

## Prerequisiti

- Vagrant
- VMware provider per Vagrant
- Box `rocky9-updated`

## Come viene sostituito Ingress con Gateway API

Nel setup nuovo la sostituzione avviene gia in `scripts/install_rke2_single.sh`:

```yaml
ingress-controller: traefik
```

RKE2 installa comunque il chart packaged `rke2-traefik`, ma il relativo `HelmChartConfig` cambia i provider usati da Traefik:

```yaml
providers:
  kubernetesGateway:
    enabled: true
  kubernetesIngress:
    enabled: false
  kubernetesCRD:
    enabled: false
```

Quindi Traefik resta il dataplane che riceve traffico su 80/443, ma non legge piu risorse `networking.k8s.io/v1/Ingress`. Le regole applicative passano a:

- `Gateway`: dichiara il punto di ingresso gestito dalla `GatewayClass` `traefik`
- `HTTPRoute`: sostituisce le regole host/path dell'Ingress e punta ai Service applicativi

Nel manifest demo il `Gateway` usa `port: 8000` perche il chart Traefik espone l'entrypoint interno `web` su 8000; il Service `rke2-traefik` lo pubblica comunque verso l'esterno su `80`. Per questo il test utente resta:

```bash
curl -H 'Host: nginx.example.local' http://192.168.1.21/
```

La stessa logica vale per HTTPS: entrypoint interno `8443`, porta esposta `443`.

## Avvio ambiente

Dalla cartella `rke2-single-instance`:

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

Dal tuo host (cartella `rke2-single-instance`):

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

## Migrazione manuale da Traefik Ingress a Gateway API

Questa procedura serve quando lavori su un cluster RKE2 gia esistente dove Traefik Ingress sta gia occupando le porte standard `80/443` (se hai scritto `440`, intendo quasi certamente `443`). E una variante della migrazione RKE2 ufficiale: https://docs.rke2.io/reference/ingress_migration

La guida RKE2 descrive il passaggio da Ingress NGINX a Traefik: prima affianca i controller su porte temporanee, poi duplica e valida gli Ingress, infine rimuove NGINX e assegna a Traefik le porte standard. Qui invece Traefik c'e gia; quindi non serve installare un secondo controller. La migrazione consiste nel tenere Traefik acceso su 80/443, abilitare il provider Gateway API, convertire gli `Ingress` in `Gateway`/`HTTPRoute`, e solo alla fine spegnere il provider Ingress.

### 1) Verifica stato attuale

```bash
kubectl -n kube-system get helmchart,helmchartconfig | grep traefik
kubectl get ingressclass
kubectl get ingress -A
kubectl get gatewayclass,gateway,httproute -A
```

Controlla anche il Service Traefik:

```bash
kubectl -n kube-system get svc rke2-traefik -o wide
```

### 2) Abilita Gateway API senza spegnere subito Ingress

Crea o aggiorna `/var/lib/rancher/rke2/server/manifests/rke2-traefik-config.yaml` lasciando temporaneamente acceso anche il provider Ingress. In questo modo le app esistenti continuano a funzionare mentre prepari le `HTTPRoute`.

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesGateway:
        enabled: true
      kubernetesIngress:
        enabled: true
```

Poi riavvia RKE2 sul nodo server:

```bash
sudo systemctl restart rke2-server
kubectl -n kube-system rollout status deployment/rke2-traefik --timeout=180s || true
kubectl -n kube-system rollout status daemonset/rke2-traefik --timeout=180s || true
kubectl get gatewayclass
```

### 3) Converti ogni Ingress in Gateway + HTTPRoute

Per ogni Ingress esistente:

- crea un `Gateway` con `gatewayClassName: traefik`
- crea una `HTTPRoute` con gli stessi host/path dell'Ingress
- punta i `backendRefs` agli stessi Service usati dall'Ingress

Esempio HTTP minimale:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gw
  namespace: demo
spec:
  gatewayClassName: traefik
  listeners:
  - name: web
    protocol: HTTP
    port: 8000
    hostname: app.example.local
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: demo
spec:
  parentRefs:
  - name: web-gw
    sectionName: web
  hostnames:
  - app.example.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-service
      port: 80
```

Testa dalla stessa porta esterna gia pubblicata da Traefik:

```bash
curl -H 'Host: app.example.local' http://<NODE_IP>/
kubectl -n demo describe gateway web-gw
kubectl -n demo describe httproute app-route
```

Nota importante: nella Gateway API non tutte le annotazioni Ingress hanno un equivalente automatico. Se l'Ingress usava annotazioni Traefik o NGINX per redirect, timeout, middleware o TLS, trasformale in campi Gateway API quando disponibili oppure in risorse Traefik dedicate solo se vuoi mantenere estensioni specifiche del controller.

### 4) Spegni il provider Ingress solo dopo i test

Quando tutte le route sono state replicate e testate, aggiorna il `HelmChartConfig`:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ingressClass:
      enabled: false
    providers:
      kubernetesGateway:
        enabled: true
      kubernetesIngress:
        enabled: false
      kubernetesCRD:
        enabled: false
    ports:
      web:
        hostPort: null
      websecure:
        hostPort: null
    service:
      spec:
        type: LoadBalancer
```

Riavvia RKE2:

```bash
sudo systemctl restart rke2-server
kubectl -n kube-system get pods,svc | grep traefik
kubectl get gatewayclass,gateway,httproute -A
```

### 5) Pulisci gli Ingress legacy

Dopo la validazione finale, rimuovi gli oggetti `Ingress` rimasti:

```bash
kubectl get ingress -A
kubectl delete ingress -n <namespace> <name>
```

Non eliminare gli Ingress prima di aver verificato che le `HTTPRoute` rispondano correttamente su `80/443`.

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
