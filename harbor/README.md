# Harbor su Vagrant (equivalente setup Nexus)

Questa cartella contiene un setup Harbor su Rocky Linux 9 con provisioning automatico via Vagrant.

File principali:
- Vagrantfile
- install_harbor.sh

## Prerequisiti

- Vagrant
- VMware Desktop provider per Vagrant
- Accesso rete locale con bridge WLAN (come da Vagrantfile)
- Docker installato sulla macchina client da cui vuoi fare push/pull

## Parametri attuali

Nel Vagrantfile sono configurati questi valori:
- IP VM Harbor: 192.168.1.57
- URL Harbor: http://192.168.1.57
- Versione Harbor: 2.11.0
- Utente admin: admin
- Password admin: Harbor12345

## Avvio ambiente

Dalla cartella harbor:

```bash
vagrant up --provider=vmware_desktop
```

Accesso VM:

```bash
vagrant ssh
```

Verifica servizi Harbor in VM:

```bash
sudo docker compose -f /opt/harbor/harbor/docker-compose.yml ps
```

Log servizio core Harbor:

```bash
sudo docker compose -f /opt/harbor/harbor/docker-compose.yml logs -f core
```

## Accesso UI Harbor

Apri dal browser:
- http://192.168.1.57

Login iniziale:
- Username: admin
- Password: Harbor12345

## Creazione progetto (repo namespace)

In Harbor la repository viene materializzata al primo push dentro un progetto.

Passi da UI:
1. Vai su Projects.
2. Clicca New Project.
3. Nome esempio: demo.
4. Visibility: Private (consigliato).
5. Conferma Create.

A questo punto puoi pushare immagini nel path (la porta `:80` è obbligatoria):
- 192.168.1.57:80/demo/<nome-repository>:<tag>

Esempio:
- 192.168.1.57:80/demo/nginx-test:1.0

## Configurazione Docker client per Harbor HTTP (senza TLS)

Questo setup usa HTTP sulla porta 80. Il Docker client, in assenza di TLS, tenta di default la porta 443 e fallisce. **È quindi obbligatorio specificare sempre la porta `:80`** sia negli insecure-registries che in tutti i comandi `docker login`, `docker tag`, `docker push` e `docker pull`.

### Linux client

Modifica o crea /etc/docker/daemon.json:

```json
{
  "insecure-registries": ["192.168.1.57:80"]
}
```

Riavvia Docker:

```bash
sudo systemctl restart docker
```

### Docker Desktop (Windows/Mac)

Aggiungi `192.168.1.57:80` (con la porta) tra gli insecure registries nella configurazione del daemon Docker Desktop e riavvia Docker Desktop.

## Push immagine test (validazione end-to-end)

Esegui dal client Docker:

1. Login Harbor

```bash
docker login 192.168.1.57:80
```

Inserisci:
- Username: admin
- Password: Harbor12345

2. Pull immagine pubblica di test

```bash
docker pull nginx:alpine
```

3. Tag verso Harbor

```bash
docker tag nginx:alpine 192.168.1.57:80/demo/nginx-test:1.0
```

4. Push su Harbor

```bash
docker push 192.168.1.57:80/demo/nginx-test:1.0
```

5. Verifica su UI

- Project demo -> Repositories
- Dovresti vedere nginx-test con tag 1.0

## Test pull di validazione

Da un altro host (o dopo docker image rm locale):

```bash
docker pull 192.168.1.57:80/demo/nginx-test:1.0
```

Se il pull funziona, Harbor e pipeline base push/pull sono validati.

## Troubleshooting rapido

- Errore HTTP/HTTPS mismatch durante login o push:
  - Verifica che il client Docker abbia `192.168.1.57:80` (con la porta) negli insecure-registries.
  - Ricorda che la porta `:80` deve essere specificata esplicitamente in ogni comando docker, altrimenti Docker tenta la connessione HTTPS sulla porta 443.

- Push denied:
  - Verifica di aver creato il project demo.
  - Verifica credenziali admin o permessi utente.

- Harbor non raggiungibile:
  - Verifica IP bridged nel Vagrantfile.
  - Verifica stato servizi in VM con docker compose ps.
