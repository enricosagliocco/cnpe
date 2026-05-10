#!/usr/bin/env bash
set -euo pipefail

GITEA_VERSION="${GITEA_VERSION:-1.22.1}"
GITEA_DOMAIN="${GITEA_DOMAIN:-gitea.local}"
GITEA_ROOT_URL="${GITEA_ROOT_URL:-http://${GITEA_DOMAIN}:3000/}"
GITEA_SSH_DOMAIN="${GITEA_SSH_DOMAIN:-${GITEA_DOMAIN}}"
GITEA_HTTP_PORT="${GITEA_HTTP_PORT:-3000}"
GITEA_SSH_PORT="${GITEA_SSH_PORT:-2222}"
GITEA_USER="git"
GITEA_HOME="/var/lib/gitea"
GITEA_CONF_DIR="/etc/gitea"
GITEA_CUSTOM_DIR="${GITEA_HOME}/custom"
GITEA_APP_INI="${GITEA_CONF_DIR}/app.ini"
GITEA_BIN="/usr/local/bin/gitea"
GITEA_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64"

echo "==> Aggiorno il sistema Rocky Linux 9"
sudo dnf -y update

sudo systemctl disable --now firewalld

echo "==> Disabilito SELinux (runtime + permanente)"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || true
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config || true

echo "==> Installo dipendenze di sistema"
sudo dnf -y install git curl wget tar policycoreutils-python-utils

echo "==> Creo utente e directory applicative"
if ! id -u "${GITEA_USER}" >/dev/null 2>&1; then
  sudo useradd \
    --system \
    --shell /bin/bash \
    --comment "Gitea Version Control" \
    --create-home \
    --home-dir "${GITEA_HOME}" \
    "${GITEA_USER}"
fi

sudo mkdir -p \
  "${GITEA_CONF_DIR}" \
  "${GITEA_HOME}/data" \
  "${GITEA_HOME}/log" \
  "${GITEA_HOME}/repositories" \
  "${GITEA_CUSTOM_DIR}"

sudo chown -R "${GITEA_USER}:${GITEA_USER}" "${GITEA_HOME}" "${GITEA_CONF_DIR}"
sudo chmod 750 "${GITEA_HOME}" "${GITEA_CONF_DIR}"

echo "==> Scarico Gitea ${GITEA_VERSION}"
sudo curl -L "${GITEA_URL}" -o "${GITEA_BIN}"
sudo chmod 755 "${GITEA_BIN}"

echo "==> Scrivo configurazione iniziale"
sudo tee "${GITEA_APP_INI}" >/dev/null <<EOF
[server]
APP_DATA_PATH = ${GITEA_HOME}/data
DOMAIN = ${GITEA_DOMAIN}
SSH_DOMAIN = ${GITEA_SSH_DOMAIN}
HTTP_PORT = ${GITEA_HTTP_PORT}
ROOT_URL = ${GITEA_ROOT_URL}
DISABLE_SSH = false
SSH_PORT = ${GITEA_SSH_PORT}
OFFLINE_MODE = false

[database]
DB_TYPE = sqlite3
PATH = ${GITEA_HOME}/data/gitea.db

[repository]
ROOT = ${GITEA_HOME}/repositories

[security]
INSTALL_LOCK = false
SECRET_KEY = 
INTERNAL_TOKEN = 

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false

[log]
ROOT_PATH = ${GITEA_HOME}/log
MODE = console, file
LEVEL = Info
EOF

sudo chown "${GITEA_USER}:${GITEA_USER}" "${GITEA_APP_INI}"
sudo chmod 640 "${GITEA_APP_INI}"

echo "==> Registro servizio systemd"
sudo tee /etc/systemd/system/gitea.service >/dev/null <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
RestartSec=2s
Type=simple
User=${GITEA_USER}
Group=${GITEA_USER}
WorkingDirectory=${GITEA_HOME}
ExecStart=${GITEA_BIN} web --config ${GITEA_APP_INI}
Restart=always
Environment=USER=${GITEA_USER} HOME=${GITEA_HOME} GITEA_WORK_DIR=${GITEA_HOME}
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "==> Abilito e avvio Gitea"
sudo systemctl daemon-reload
sudo systemctl enable --now gitea

echo "==> Verifica stato servizio"
sudo systemctl --no-pager --full status gitea || true

echo
echo "Installazione completata."
echo "Apri ${GITEA_ROOT_URL} dal browser e completa il setup iniziale."
echo "Per verificare i log: sudo journalctl -u gitea -f"