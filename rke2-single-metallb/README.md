# RKE2 Single Instance con MetalLB (senza Traefik)

Questa cartella crea un cluster RKE2 single-node con:

- Traefik disabilitato
- ServiceLB disabilitato
- MetalLB in modalita L2
- Pool IP MetalLB: `192.168.1.23/32`

Configurazione rete:

- IP VM: `192.168.1.22`
- Hostname: `rke2-single-metallb`

## Prerequisiti

- Vagrant
- VMware provider per Vagrant
- Box `rocky9-updated`

## Avvio ambiente

Dalla cartella `rke2-single-metallb`:

```bash
vagrant up --provider=vmware_desktop
```

Accesso al nodo:

```bash
vagrant ssh rke2-single-metallb
```

## Verifiche cluster e MetalLB

Nel nodo:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl get nodes -o wide
sudo /var/lib/rancher/rke2/bin/kubectl get pods -A
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get pods
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get ipaddresspool,l2advertisement
```

Verifica pool:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get ipaddresspool default-pool -o yaml
```

Dovresti vedere `192.168.1.23/32` in `.spec.addresses`.

## Test rapido LoadBalancer

Esempio service `LoadBalancer`:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl create deployment lb-test --image=nginx --port=80
sudo /var/lib/rancher/rke2/bin/kubectl expose deployment lb-test --name lb-test --type LoadBalancer --port 80 --target-port 80
sudo /var/lib/rancher/rke2/bin/kubectl get svc lb-test -w
```

Quando `EXTERNAL-IP` diventa `192.168.1.23`, puoi testare:

```bash
curl http://192.168.1.23/
```

Cleanup:

```bash
sudo /var/lib/rancher/rke2/bin/kubectl delete svc lb-test
sudo /var/lib/rancher/rke2/bin/kubectl delete deployment lb-test
```
