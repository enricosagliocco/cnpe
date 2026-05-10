#!/usr/bin/env bash
set -euo pipefail

echo "==> Rimuovo risorse demo Gateway API"
sudo /var/lib/rancher/rke2/bin/kubectl delete -f /vagrant/examples/nginx-gateway-demo.yaml --ignore-not-found=true

echo "Cleanup completato"
