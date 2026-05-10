#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuro Traefik Gateway API con NodePort"

echo "Attendo Traefik..."
for i in $(seq 1 30); do
  if sudo /var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-traefik -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
    break
  fi
  sleep 5
done

echo "Verifico disponibilita porte NodePort..."
PORT_30080_IN_USE=$(sudo ss -tlnp 2>/dev/null | grep ':30080' || true)
PORT_30443_IN_USE=$(sudo ss -tlnp 2>/dev/null | grep ':30443' || true)

if [ -n "$PORT_30080_IN_USE" ] || [ -n "$PORT_30443_IN_USE" ]; then
  echo "ATTENZIONE: Porte 30080/30443 gia in uso."
  echo "Riprova dopo averle liberate oppure cambia le porte nel file scripts/setup_traefik_gateway.sh"
  exit 1
else
  NODEPORT_HTTP=30080
  NODEPORT_HTTPS=30443
  echo "Porte 30080 e 30443 disponibili"
fi

echo "Creo Service NodePort traefik-gateway-nodeport..."
sudo tee /tmp/traefik-nodeport.yaml >/dev/null <<EOF
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
    nodePort: ${NODEPORT_HTTP}
    protocol: TCP
  - name: websecure
    port: 443
    targetPort: websecure
    nodePort: ${NODEPORT_HTTPS}
    protocol: TCP
EOF

sudo /var/lib/rancher/rke2/bin/kubectl apply -f /tmp/traefik-nodeport.yaml

echo ""
echo "=========================================="
echo "Traefik Gateway API configurato con NodePort"
echo "=========================================="
echo "Porta HTTP:  ${NODEPORT_HTTP}"
echo "Porta HTTPS: ${NODEPORT_HTTPS}"
echo ""
echo "Verifica:"
echo "  sudo /var/lib/rancher/rke2/bin/kubectl get svc -n kube-system | grep nodeport"
echo ""
echo "Test:"
echo "  curl -H 'Host: nginx.example.local' http://<NODE_IP>:${NODEPORT_HTTP}/"
echo "=========================================="
