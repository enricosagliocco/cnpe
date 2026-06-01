#!/usr/bin/env bash
set -euo pipefail

LOCALSTACK_URL="${LOCALSTACK_URL:-http://localhost:4566}"
LOCALSTACK_VERSION="${LOCALSTACK_VERSION:-3.5.0}"
VAGRANT_HOME="$(getent passwd vagrant | cut -d: -f6)"
VAGRANT_HOME="${VAGRANT_HOME:-$(eval echo ~vagrant)}"

echo "==> Aggiorno il sistema Rocky Linux 9"
sudo dnf -y update

sudo systemctl disable --now firewalld

echo "==> Disabilito SELinux (runtime + permanente)"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || true
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config || true

echo "==> Installo dipendenze base"
sudo dnf -y install dnf-plugins-core curl tar gzip python3-pip

echo "==> Installo Docker Engine e plugin Compose"
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Abilito e avvio Docker"
sudo systemctl enable --now docker

echo "==> Installo AWS CLI"
sudo pip3 install --upgrade awscli

echo "==> Preparo credenziali demo per la VM"
sudo -u vagrant mkdir -p "${VAGRANT_HOME}/.aws"
sudo -u vagrant tee "${VAGRANT_HOME}/.aws/config" >/dev/null <<'EOF'
[default]
region = eu-west-1
output = json
EOF
sudo -u vagrant tee "${VAGRANT_HOME}/.aws/credentials" >/dev/null <<'EOF'
[default]
aws_access_key_id = test
aws_secret_access_key = test
EOF

echo "==> Preparo cartelle LocalStack"
sudo mkdir -p /opt/localstack/data
sudo mkdir -p /opt/localstack

if [ ! -f "/opt/localstack/.installed-v${LOCALSTACK_VERSION}" ]; then
  echo "==> Copio docker-compose.yml di LocalStack"
  sudo cp /vagrant/docker-compose.yml /opt/localstack/docker-compose.yml

  echo "==> Avvio LocalStack con Docker Compose"
  cd /opt/localstack
  sudo docker compose pull
  sudo docker compose up -d

  sudo touch "/opt/localstack/.installed-v${LOCALSTACK_VERSION}"
else
  echo "==> LocalStack v${LOCALSTACK_VERSION} gia installato, aggiorno i container"
  sudo cp /vagrant/docker-compose.yml /opt/localstack/docker-compose.yml
  cd /opt/localstack
  sudo docker compose pull
  sudo docker compose up -d
fi

echo "==> Stato servizi LocalStack"
sudo docker compose -f /opt/localstack/docker-compose.yml ps || true

echo
echo "Installazione completata."
echo "Endpoint principale LocalStack: ${LOCALSTACK_URL}"
echo "Verifica rapida:"
echo "  curl -s ${LOCALSTACK_URL}/_localstack/health"
echo "Log LocalStack:"
echo "  sudo docker compose -f /opt/localstack/docker-compose.yml logs -f localstack"
