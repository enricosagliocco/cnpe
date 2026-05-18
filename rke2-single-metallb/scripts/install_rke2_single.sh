#!/usr/bin/env bash
set -euo pipefail

RKE2_TOKEN="${RKE2_TOKEN:-rke2-single-secret-token-CambiaMe}"
RKE2_SINGLE_IP="${RKE2_SINGLE_IP:-192.168.1.22}"
METALLB_VERSION="${METALLB_VERSION:-v0.14.9}"
METALLB_POOL_CIDR="${METALLB_POOL_CIDR:-192.168.1.23/32}"
LOCAL_PATH_MANIFEST_URL="${LOCAL_PATH_MANIFEST_URL:-https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml}"
HELM_VERSION="${HELM_VERSION:-v3.20.2}"
K9S_VERSION="${K9S_VERSION:-v0.40.10}"

echo "==> Installo RKE2 server (single instance)"
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="server" sh -

sudo mkdir -p /etc/rancher/rke2
sudo tee /etc/rancher/rke2/config.yaml >/dev/null <<EOF
write-kubeconfig-mode: "0640"
token: "${RKE2_TOKEN}"
tls-san:
  - "${RKE2_SINGLE_IP}"
  - "rke2-single-metallb"
node-ip: "${RKE2_SINGLE_IP}"
node-external-ip: "${RKE2_SINGLE_IP}"
cluster-cidr: "10.244.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"
cni: calico
ingress-controller: none
enable-servicelb: false
EOF

sudo systemctl enable --now rke2-server
sudo systemctl status rke2-server --no-pager || true

echo "==> Configuro kubectl locale"
sudo mkdir -p /root/.kube
sudo cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
sudo chmod 600 /root/.kube/config

if id -u vagrant >/dev/null 2>&1; then
  sudo mkdir -p /home/vagrant/.kube
  sudo cp /etc/rancher/rke2/rke2.yaml /home/vagrant/.kube/config
  sudo chown -R vagrant:vagrant /home/vagrant/.kube
  sudo chmod 600 /home/vagrant/.kube/config
fi

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin

echo "==> Attendo API server RKE2"
for _ in $(seq 1 60); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

echo "==> Installo MetalLB ${METALLB_VERSION}"
sudo /var/lib/rancher/rke2/bin/kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"

echo "==> Attendo deploy MetalLB"
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system rollout status deployment/controller --timeout=240s
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system rollout status daemonset/speaker --timeout=240s

echo "==> Configuro pool IP MetalLB: ${METALLB_POOL_CIDR}"
sudo tee /tmp/metallb-config.yaml >/dev/null <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - ${METALLB_POOL_CIDR}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
sudo /var/lib/rancher/rke2/bin/kubectl apply -f /tmp/metallb-config.yaml

echo "==> Installo Helm (per uso futuro)"
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o /tmp/helm.tgz
tar -xzf /tmp/helm.tgz -C /tmp
sudo install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
echo "==> Verifico Helm per root e vagrant"
sudo /usr/local/bin/helm version --short
if id -u vagrant >/dev/null 2>&1; then
  sudo -u vagrant /usr/local/bin/helm version --short
fi

echo "==> Installo k9s"
curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o /tmp/k9s.tgz
tar -xzf /tmp/k9s.tgz -C /tmp k9s
sudo install -m 0755 /tmp/k9s /usr/local/bin/k9s
echo "==> Verifico k9s per root e vagrant"
sudo /usr/local/bin/k9s version
if id -u vagrant >/dev/null 2>&1; then
  sudo -u vagrant /usr/local/bin/k9s version
fi

echo "==> Installo StorageClass local-path"
sudo /var/lib/rancher/rke2/bin/kubectl apply -f "${LOCAL_PATH_MANIFEST_URL}"
sudo /var/lib/rancher/rke2/bin/kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=180s

if sudo /var/lib/rancher/rke2/bin/kubectl get storageclass local-path >/dev/null 2>&1; then
  echo "==> Imposto local-path come StorageClass di default"
  for sc in $(sudo /var/lib/rancher/rke2/bin/kubectl get storageclass -o name); do
    sudo /var/lib/rancher/rke2/bin/kubectl annotate "${sc}" storageclass.kubernetes.io/is-default-class- --overwrite >/dev/null 2>&1 || true
  done
  sudo /var/lib/rancher/rke2/bin/kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite
fi

echo "==> Nodo single instance configurato (Traefik disabilitato + MetalLB attivo)"
echo "Comandi utili:"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get nodes -o wide"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get pods -A"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get ipaddresspool,l2advertisement -n metallb-system"
