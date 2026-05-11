#!/usr/bin/env bash
set -euo pipefail

echo "==> Verifico Traefik Gateway API con Service LoadBalancer (porte standard 80/443)"

echo "Attendo Traefik..."
for i in $(seq 1 30); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-traefik -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
    break
  fi
  sleep 5
done

echo "Attendo Service rke2-traefik..."
for i in $(seq 1 30); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system rke2-traefik >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

if ! sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system rke2-traefik >/dev/null 2>&1; then
  echo "ERRORE: service kube-system/rke2-traefik non trovato"
  exit 1
fi

SVC_TYPE=$(sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system rke2-traefik -o jsonpath='{.spec.type}')
if [ "$SVC_TYPE" != "LoadBalancer" ]; then
  echo "ERRORE: kube-system/rke2-traefik non e di tipo LoadBalancer (trovato: ${SVC_TYPE})"
  echo "Controlla il file scripts/install_rke2_single.sh (HelmChartConfig rke2-traefik)"
  exit 1
fi

echo ""
echo "=========================================="
echo "Traefik Gateway API configurato con LoadBalancer"
echo "=========================================="
echo "Porta HTTP:  80"
echo "Porta HTTPS: 443"
echo ""
echo "Verifica:"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system rke2-traefik"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l app=svclb-rke2-traefik"
echo ""
echo "Test:"
echo "  curl -H 'Host: nginx.example.local' http://<NODE_IP>/"
echo "=========================================="
