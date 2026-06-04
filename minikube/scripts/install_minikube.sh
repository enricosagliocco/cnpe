#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-cnpe}"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.35.0}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.30.0}"
VAGRANT_HOME="$(getent passwd vagrant | cut -d: -f6)"
VAGRANT_HOME="${VAGRANT_HOME:-$(eval echo ~vagrant)}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Esegui questo script come root"
  exit 1
fi

echo "==> Aggiorno il sistema Rocky Linux 9"
dnf -y update

echo "==> Disabilito firewalld"
systemctl disable --now firewalld || true

echo "==> Disabilito SELinux (runtime + permanente)"
setenforce 0 || true
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || true
sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config || true

echo "==> Installo dipendenze"
dnf -y install dnf-plugins-core curl wget tar conntrack socat iproute iptables git ca-certificates

echo "==> Configuro moduli kernel e sysctl"
cat <<'EOF' >/etc/modules-load.d/minikube.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<'EOF' >/etc/sysctl.d/minikube.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "==> Installo Docker Engine e plugin Compose"
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker vagrant || true

echo "==> Installo kubectl"
cat <<'EOF' >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF
dnf -y install kubectl

echo "==> Installo minikube ${MINIKUBE_VERSION}"
curl -fsSL -o /usr/local/bin/minikube "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64"
chmod 755 /usr/local/bin/minikube

echo "==> Verifico binari"
/usr/local/bin/minikube version
kubectl version --client=true


echo "==> Configuro alias kubectl (globale + utente vagrant)"
cat <<'EOF' >/etc/profile.d/kubectl-alias.sh
# Alias e completion kubectl per shell bash interattive
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
  alias k=kubectl
  source <(kubectl completion bash)
  complete -F __start_kubectl k
fi
EOF
chmod 644 /etc/profile.d/kubectl-alias.sh

if ! grep -q "alias k=kubectl" "${VAGRANT_HOME}/.bashrc"; then
  echo 'alias k=kubectl' >> "${VAGRANT_HOME}/.bashrc"
fi
if ! grep -q "complete -F __start_kubectl k" "${VAGRANT_HOME}/.bashrc"; then
  echo 'source <(kubectl completion bash)' >> "${VAGRANT_HOME}/.bashrc"
  echo 'complete -F __start_kubectl k' >> "${VAGRANT_HOME}/.bashrc"
fi
chown vagrant:vagrant "${VAGRANT_HOME}/.bashrc"

echo "==> Installazione k9s per gestione cluster"
curl -sS https://webinstall.dev/k9s | bash


echo
echo "Installazione completata."
echo "Profilo Minikube: ${MINIKUBE_PROFILE}"
echo "Comandi utili:"
echo "  minikube status -p ${MINIKUBE_PROFILE}"
echo "  kubectl get nodes -o wide"
