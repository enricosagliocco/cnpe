#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuro Traefik Gateway API su porte 80 e 443"

# Attendi che Traefik sia pronto
echo "Attendo Traefik..."
for _ in $(seq 1 40); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-traefik -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
    break
  fi
  sleep 5
done

# Verifica gateway class
sudo /var/lib/rancher/rke2/bin/kubectl get gatewayclass >/dev/null

# Service NodePort con porte basse (range abilitato in install_rke2_single.sh)
echo "Creo Service NodePort traefik-gateway-nodeport (80/443)..."
sudo tee /tmp/traefik-nodeport-80-443.yaml >/dev/null <<'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: traefik-gateway-nodeport
  namespace: kube-system
spec:
  type: NodePort
  selector:
    app.kubernetes.io/instance: rke2-traefik-kube-system
    app.kubernetes.io/name: rke2-traefik
  ports:
  - name: web
    port: 80
    targetPort: web
    nodePort: 80
    protocol: TCP
  - name: websecure
    port: 443
    targetPort: websecure
    nodePort: 443
    protocol: TCP
EOF

sudo /var/lib/rancher/rke2/bin/kubectl apply -f /tmp/traefik-nodeport-80-443.yaml

echo
echo "=========================================="
echo "Traefik Gateway API configurato"
echo "=========================================="
echo "HTTP:  http://<NODE_IP>/"
echo "HTTPS: https://<NODE_IP>/"
echo
echo "Verifica:"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl -n kube-system get svc traefik-gateway-nodeport"
echo "=========================================="
