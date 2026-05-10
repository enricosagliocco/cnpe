# Backstage Installation Guide

Guida completa per l'installazione di Backstage su Rocky Linux 9 con accesso all'indirizzo `192.168.1.48`.

## Utilizzo di Vagrant (metodo consigliato)

### Primo collegamento:

```bash
# 1) Avvio VM:
vagrant up --provider=vmware_desktop

# 2) Accesso SSH alla VM:
vagrant ssh

# 3) Verifica stato Backstage:
curl -s http://192.168.1.48:7007/api/health

# 4) Accesso frontend:
http://192.168.1.48:3000

# 5) Accesso backend:
http://192.168.1.48:7007
```

---

## 1. Prerequisiti di sistema

Parti da un sistema aggiornato e installa gli strumenti di build essenziali (su Rocky Linux):

```bash
sudo dnf update -y
sudo dnf install -y curl git make gcc gcc-c++ python3 python3-pip
```

---

## 2. Installare Node.js (tramite nvm — metodo consigliato)

Nvm è il metodo raccomandato per installare Node.js.

```bash
# Installa nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Ricarica il profilo
source ~/.bashrc

# Installa Node.js LTS (versione 20 o superiore)
nvm install --lts
nvm use --lts

# Verifica
node --version
npm --version
```

---

## 3. Abilitare Corepack e installare Yarn

Backstage usa attualmente Yarn 4.4.1: dopo aver eseguito `corepack enable`, bisogna poi eseguire `yarn set version 4.4.1`.

```bash
corepack enable
yarn set version 4.4.1
yarn --version
```

---

## 4. Creare il progetto Backstage

```bash
# Spostati nella directory dove vuoi creare il progetto
cd ~

# Crea l'app (ti verrà chiesto un nome)
npx @backstage/create-app@latest
```

Quando richiesto, inserisci il nome dell'applicazione (es. `my-backstage`). L'installazione può richiedere qualche minuto.

---

## 5. Avviare Backstage in modalità sviluppo

```bash
cd my-backstage
yarn start
```

Questo comando avvia il frontend e il backend come processi separati nella stessa finestra. Backstage si avvierà per la prima volta con dei componenti di esempio.

Una volta avviato, accedi da browser all'indirizzo:

- **Frontend:** `http://192.168.1.48:3000`
- **Backend:** `http://192.168.1.48:7007`

---

## 6. Configurazione di rete (per accesso remoto)

Per rendere Backstage accessibile da remoto all'indirizzo `192.168.1.48`, assicurati che il server sia configurato correttamente:

### a) Configurare bind address nel backend

Modifica il file `app-config.yaml` nel progetto Backstage:

```yaml
backend:
  listen:
    port: 7007
    host: 0.0.0.0  # Ascolta su tutte le interfacce di rete
```

### b) Configurare bind address nel frontend

Se necessario, configura il frontend per ascoltare su tutte le interfacce (di default ascolta su 0.0.0.0).

---

## 7. Script di installazione automatica

Utilizza il file `install_backstage.sh` per automatizzare il processo di installazione:

```bash
chmod +x install_backstage.sh
./install_backstage.sh
```

---

## 8. Utilizzo di Vagrant

Per una gestione più semplice dell'ambiente, puoi utilizzare il `Vagrantfile` fornito:

```bash
# Primo avvio (scarica box e provisiona)
vagrant up --provider=vmware_desktop

# Accesso SSH
vagrant ssh

# Avviare Backstage dall'interno della VM
cd /root/my-backstage  # o il nome del progetto che hai scelto
yarn start

# Uscire dalla VM
exit

# Fermare la VM
vagrant halt

# Riavviare la VM
vagrant up --provider=vmware_desktop

# Eliminare la VM
vagrant destroy
```

La VM sarà automaticamente disponibile su:
- **Frontend:** http://192.168.1.48:3000
- **Backend:** http://192.168.1.48:7007

---

## Note importanti

- Backstage richiede Node.js LTS (versione 20 o superiore)
- L'installazione iniziale può richiedere 10-15 minuti
- Assicurati che le porte 3000 e 7007 siano libere e accessibili
- Per ambienti di produzione, consulta la [documentazione ufficiale di Backstage](https://backstage.io/docs/deployment/docker)

---

## Troubleshooting

### Il frontend non si connette al backend

Assicurati che il backend ascolti su `0.0.0.0` e che il file `app-config.yaml` sia configurato correttamente.

### Errore di rete

Verifica la connettività con:

```bash
ping 192.168.1.48
curl http://192.168.1.48:7007/api/health
```

### Port già in uso

Se le porte 3000 o 7007 sono già in uso, puoi cambiarle nel file `app-config.yaml`:

```yaml
frontend:
  listen:
    port: 3001  # Cambia la porta se necessario
```

Per ulteriori soluzioni, consulta [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

