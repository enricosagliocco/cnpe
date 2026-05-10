#!/usr/bin/env bash
set -euo pipefail

RKE2_TOKEN="${RKE2_TOKEN:-rke2-single-secret-token-CambiaMe}"
RKE2_SINGLE_IP="${RKE2_SINGLE_IP:-192.168.1.21}"

echo "==> Installo RKE2 server (single instance)"
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="server" sh -

sudo mkdir -p /etc/rancher/rke2
sudo tee /etc/rancher/rke2/config.yaml >/dev/null <<EOF
write-kubeconfig-mode: "0640"
token: "${RKE2_TOKEN}"
tls-san:
  - "${RKE2_SINGLE_IP}"
  - "rke2-single"
cluster-cidr: "10.244.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"
cni: calico
ingress-controller: traefik
EOF

echo "==> Configuro HelmChartConfig per Traefik Gateway API"
sudo mkdir -p /var/lib/rancher/rke2/server/manifests
sudo tee /var/lib/rancher/rke2/server/manifests/rke2-traefik-config.yaml >/dev/null <<EOF
---
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
EOF

sudo systemctl enable --now rke2-server
sudo systemctl status rke2-server --no-pager || true

echo "==> Configuro kubectl locale"
sudo mkdir -p /root/.kube
sudo cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
sudo chmod 600 /root/.kube/config
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin

echo "==> Attendo API server RKE2"
for _ in $(seq 1 60); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

echo "==> Installo Helm (per uso futuro)"
HELM_VERSION="v3.20.2"
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o /tmp/helm.tgz
tar -xzf /tmp/helm.tgz -C /tmp
sudo install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
sudo /usr/local/bin/helm version --short

echo "==> Nodo single instance configurato"
echo "Comandi utili:"
echo "  sudo journalctl -u rke2-server -f"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get nodes -o wide"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get pods -A"
