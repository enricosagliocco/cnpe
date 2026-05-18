#!/usr/bin/env bash
set -euo pipefail

RKE2_HOSTNAME="${RKE2_HOSTNAME:-rke2-single-metallb}"
RKE2_HOST_IP="${RKE2_HOST_IP:-192.168.1.22}"

echo "==> Aggiorno il sistema"
sudo dnf -y update
sudo dnf -y install curl tar git nfs-utils iptables conntrack-tools container-selinux

echo "==> Disabilito swap e firewalld"
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo systemctl disable --now firewalld

echo "==> Configuro moduli kernel e sysctl"
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "==> Disabilito SELinux (runtime + permanente)"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || true
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config || true

echo "==> Configuro /etc/hosts"
if ! grep -q "${RKE2_HOSTNAME}" /etc/hosts; then
  echo "${RKE2_HOST_IP}  ${RKE2_HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null
fi
