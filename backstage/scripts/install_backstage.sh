#!/usr/bin/env bash

# Installazione nativa di Backstage su Rocky Linux 9

set -euo pipefail

BACKSTAGE_HOST=${BACKSTAGE_HOST:-192.168.1.60}
BACKSTAGE_PORT=${BACKSTAGE_PORT:-3000}
VAGRANT_HOME="$(getent passwd vagrant | cut -d: -f6)"
VAGRANT_HOME="${VAGRANT_HOME:-$(eval echo ~vagrant)}"
APP_DIR="${VAGRANT_HOME}/my-backstage"

echo "=== Backstage Native Installation (Rocky 9) ==="
echo "Host: ${BACKSTAGE_HOST}"
echo "Port: ${BACKSTAGE_PORT}"

echo "=== 0) Fix udev persistent net rules path ==="
if [ -d /etc/udev/rules.d/70-persistent-net.rules ]; then
	rm -rf /etc/udev/rules.d/70-persistent-net.rules
fi
if [ ! -e /etc/udev/rules.d/70-persistent-net.rules ]; then
	touch /etc/udev/rules.d/70-persistent-net.rules
fi

echo "=== 1) Aggiornamento sistema e prerequisiti ==="
dnf -y update
dnf -y install \
	curl \
	git \
	make \
	gcc \
	gcc-c++ \
	python3 \
	python3-pip

echo "=== 2) Installazione nvm + Node LTS per utente vagrant ==="
if [ ! -s "${VAGRANT_HOME}/.nvm/nvm.sh" ]; then
	runuser -l vagrant -c 'bash -lc "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"'
fi

runuser -l vagrant -c 'bash -lc "
	export NVM_DIR=\"$HOME/.nvm\"
	. \"$NVM_DIR/nvm.sh\"
	nvm install --lts
	nvm use --lts
	corepack enable
"'

echo "=== 3) Creazione progetto Backstage ==="
if [ ! -d "${APP_DIR}" ]; then
	runuser -l vagrant -c 'bash -lc "
		export NVM_DIR=\"$HOME/.nvm\"
		. \"$NVM_DIR/nvm.sh\"
		nvm use --lts
		cd \"$HOME\"
		printf \"my-backstage\\n\" | npx @backstage/create-app@latest
	"'
fi

echo "=== 4) Configurazione Yarn 4.4.1 ==="
runuser -l vagrant -c 'bash -lc "
	export NVM_DIR=\"$HOME/.nvm\"
	. \"$NVM_DIR/nvm.sh\"
	nvm use --lts
	cd \"$HOME/my-backstage\"
	corepack enable
	yarn set version 4.4.1
	yarn --version
"'

echo "=== 5) Configurazione app-config.yaml ==="
runuser -l vagrant -c 'bash -lc "
	cd \"$HOME/my-backstage\"
	sed -i \"s|baseUrl: http://localhost:3000|baseUrl: http://'"${BACKSTAGE_HOST}"':3000|g\" app-config.yaml
	sed -i \"s|baseUrl: http://localhost:7007|baseUrl: http://'"${BACKSTAGE_HOST}"':7007|g\" app-config.yaml
	sed -i \"s|origin: http://localhost:3000|origin: http://'"${BACKSTAGE_HOST}"':3000|g\" app-config.yaml
	sed -i \"s|# host: 127.0.0.1|host: 0.0.0.0|g\" app-config.yaml
"'

echo "=== 6) Apertura porte firewall (se attivo) ==="
if systemctl is-active --quiet firewalld; then
	firewall-cmd --permanent --add-port=3000/tcp || true
	firewall-cmd --permanent --add-port=7007/tcp || true
	firewall-cmd --reload || true
fi

echo "=== 7) Service systemd Backstage ==="
cat >/etc/systemd/system/backstage.service <<EOF
[Unit]
Description=Backstage Development Service
After=network.target

[Service]
Type=simple
User=vagrant
WorkingDirectory=${APP_DIR}
Environment=HOME=${VAGRANT_HOME}
ExecStart=/bin/bash -lc 'export NVM_DIR=${VAGRANT_HOME}/.nvm; source ${VAGRANT_HOME}/.nvm/nvm.sh; nvm use --lts >/dev/null; yarn start'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now backstage

echo "=== 8) Verifica servizio ==="
sleep 15
curl -fsS "http://localhost:7007/api/health" >/dev/null || true

echo ""
echo "Backstage installato."
echo "Frontend: http://${BACKSTAGE_HOST}:3000"
echo "Backend:  http://${BACKSTAGE_HOST}:7007"
