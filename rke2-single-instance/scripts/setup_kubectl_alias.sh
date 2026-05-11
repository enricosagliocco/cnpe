#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuro alias kubectl per root user"

sudo touch /root/.bashrc

if ! sudo grep -q "alias kubectl=" /root/.bashrc; then
    echo "Aggiungo alias kubectl a /root/.bashrc"
    sudo tee -a /root/.bashrc >/dev/null <<'EOF'

# Kubectl alias for RKE2
alias kubectl='/var/lib/rancher/rke2/bin/kubectl'
alias k='kubectl'
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin
EOF
else
    echo "Alias kubectl gia presente in /root/.bashrc"
fi

if [ ! -L /usr/local/bin/kubectl ]; then
    echo "Creo symlink /usr/local/bin/kubectl"
    sudo ln -sf /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
else
    echo "Symlink /usr/local/bin/kubectl gia esistente"
fi

sudo mkdir -p /root/.kube
if [ ! -f /root/.kube/config ]; then
    echo "Copio kubeconfig per root"
    sudo cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
    sudo chmod 600 /root/.kube/config
fi

echo "Alias kubectl configurato per root user"
echo "Per usare subito: source /root/.bashrc oppure esegui logout/login"
