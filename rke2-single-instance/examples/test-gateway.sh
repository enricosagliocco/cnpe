#!/usr/bin/env bash
set -euo pipefail

MANIFEST="/vagrant/examples/nginx-gateway-demo.yaml"

echo "==> Applico manifest demo Gateway API"
sudo /var/lib/rancher/rke2/bin/kubectl apply -f "${MANIFEST}"

echo "==> Attendo deployment nginx"
sudo /var/lib/rancher/rke2/bin/kubectl -n demo rollout status deploy/nginx --timeout=180s

echo "==> Attendo assegnazione indirizzo al Gateway"
for _ in $(seq 1 30); do
  GW_ADDR=$(sudo /var/lib/rancher/rke2/bin/kubectl -n demo get gateway web-gw -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
  if [ -n "${GW_ADDR}" ]; then
    break
  fi
  sleep 5
done

echo "==> Verifiche risorse"
sudo /var/lib/rancher/rke2/bin/kubectl get gatewayclass
sudo /var/lib/rancher/rke2/bin/kubectl -n demo get gateway,httproute,svc,pods

echo "==> Test HTTP via porta standard 80"
HTTP_CODE=$(curl -s -o /tmp/gw-body.html -w "%{http_code}" -H 'Host: nginx.example.local' http://127.0.0.1/ || true)

if [ "${HTTP_CODE}" != "200" ]; then
  echo "Test FALLITO: HTTP status ${HTTP_CODE}"
  echo "Body risposta:"
  cat /tmp/gw-body.html || true
  exit 1
fi

if ! grep -q "Demo RKE2 Gateway API" /tmp/gw-body.html; then
  echo "Test FALLITO: contenuto inatteso nella risposta"
  cat /tmp/gw-body.html
  exit 1
fi

echo "Test OK: gateway funzionante (HTTP 200)"
