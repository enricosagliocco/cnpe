#!/usr/bin/env bash
set -euo pipefail

echo "==> Verifico installazione MetalLB"

for i in $(seq 1 40); do
  if sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get deploy controller >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system rollout status deployment/controller --timeout=240s
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system rollout status daemonset/speaker --timeout=240s

echo ""
echo "=========================================="
echo "MetalLB configurato"
echo "=========================================="
echo "Pool IP:"
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get ipaddresspool default-pool -o jsonpath='{.spec.addresses[*]}'
echo ""
echo ""
echo "Risorse MetalLB:"
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get pods
sudo /var/lib/rancher/rke2/bin/kubectl -n metallb-system get ipaddresspool,l2advertisement
echo "=========================================="
