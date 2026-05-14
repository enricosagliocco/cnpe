#!/usr/bin/env bash
set -euo pipefail

HARBOR_URL="${HARBOR_URL:-http://localhost}"
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-localhost}"
HARBOR_VERSION="${HARBOR_VERSION:-2.11.0}"
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"

echo "==> Aggiorno il sistema Rocky Linux 9"
sudo dnf -y update

sudo systemctl disable --now firewalld

echo "==> Disabilito SELinux (runtime + permanente)"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || true
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config || true

echo "==> Installo dipendenze base"
sudo dnf -y install dnf-plugins-core curl tar gzip

echo "==> Installo Docker Engine e plugin Compose"
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Abilito e avvio Docker"
sudo systemctl enable --now docker

echo "==> Creo cartella di lavoro Harbor"
sudo mkdir -p /opt/harbor
cd /opt/harbor

if [ ! -f "/opt/harbor/.installed-v${HARBOR_VERSION}" ]; then
  echo "==> Scarico Harbor online installer v${HARBOR_VERSION}"
  sudo rm -rf /opt/harbor/harbor /opt/harbor/harbor-online-installer.tgz
  sudo curl -fsSL -o /opt/harbor/harbor-online-installer.tgz "https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-online-installer-v${HARBOR_VERSION}.tgz"

  echo "==> Estraggo installer Harbor"
  sudo tar -xzf /opt/harbor/harbor-online-installer.tgz -C /opt/harbor

  echo "==> Genero configurazione Harbor (HTTP, no TLS)"
  sudo tee /opt/harbor/harbor/harbor.yml >/dev/null <<EOF
hostname: ${HARBOR_HOSTNAME}

http:
  port: 80

harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900

data_volume: /data

trivy:
  ignore_unfixed: false
  skip_update: false

jobservice:
  max_job_workers: 10
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1

notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3

chart:
  absolute_url: disabled

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

_version: ${HARBOR_VERSION}
EOF

  echo "==> Eseguo installazione Harbor"
  cd /opt/harbor/harbor
  sudo ./install.sh

  sudo touch "/opt/harbor/.installed-v${HARBOR_VERSION}"
else
  echo "==> Harbor v${HARBOR_VERSION} gia installato, skip installazione"
fi

echo "==> Configuro avvio automatico Harbor con pulizia container falliti"
sudo tee /usr/local/sbin/harbor-startup.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="/opt/harbor/harbor/docker-compose.yml"
PROJECT_LABEL="com.docker.compose.project=harbor"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Compose file non trovato: ${COMPOSE_FILE}"
  exit 0
fi

# Rimuove solo i container Harbor usciti con errore.
for cid in $(docker ps -aq --filter "label=${PROJECT_LABEL}" --filter "status=exited"); do
  exit_code="$(docker inspect --format '{{.State.ExitCode}}' "${cid}" 2>/dev/null || echo 0)"
  if [ "${exit_code}" != "0" ]; then
    docker rm -f "${cid}" >/dev/null 2>&1 || true
  fi
done

docker compose -f "${COMPOSE_FILE}" up -d
EOF
sudo chmod 755 /usr/local/sbin/harbor-startup.sh

sudo tee /etc/systemd/system/harbor-startup.service >/dev/null <<'EOF'
[Unit]
Description=Harbor cleanup failed containers and start services
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/harbor-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now harbor-startup.service

echo "==> Verifica stato servizi Harbor"
sudo docker compose -f /opt/harbor/harbor/docker-compose.yml ps || true

echo
echo "Installazione completata."
echo "Apri ${HARBOR_URL} dal browser."
echo "Credenziali iniziali:"
echo "  user: admin"
echo "  password: ${HARBOR_ADMIN_PASSWORD}"
echo
echo "Verifica readiness con:"
echo "  sudo docker compose -f /opt/harbor/harbor/docker-compose.yml logs -f core"