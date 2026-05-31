FROM accetto/ubuntu-vnc-xfce-firefox-g3:24.04

USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    openssh-client \
    git \
    jq \
    vim \
    nano \
    xterm \
 && mkdir -p /usr/share/keyrings \
 && wget -qO- https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg \
 && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' \
    > /etc/apt/sources.list.d/vscodium.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends codium \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Wrapper codium: evita errore --no-sandbox quando si avvia come root
RUN printf '#!/bin/bash\nexec /usr/bin/codium --no-sandbox --user-data-dir=/home/headless/.codium "$@"\n' \
    > /usr/local/bin/codium \
 && chmod +x /usr/local/bin/codium

# Crea la workspace con i permessi corretti per l'utente headless
RUN mkdir -p /home/headless/workspace \
 && chown headless:headless /home/headless/workspace

COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENV SSH_MOUNT_PATH=/tmp/host-ssh \
    VNC_RESOLUTION=1920x1080 \
    VNC_COL_DEPTH=24

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["/dockerstartup/startup.sh"]
