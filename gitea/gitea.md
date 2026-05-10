# Gitea — Installazione su VM Rocky Linux 9

---

## Indice

1. [Prerequisiti](#prerequisiti)
2. [Struttura della cartella](#struttura-della-cartella)
3. [Avvio della VM con Vagrant](#avvio-della-vm-con-vagrant)
4. [Cosa installa il provisioner](#cosa-installa-il-provisioner)
5. [Primo accesso e setup iniziale](#primo-accesso-e-setup-iniziale)
6. [Operazioni comuni](#operazioni-comuni)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisiti

| Requisito | Versione | Note |
|---|---|---|
| VMware Desktop | 17+ | Provider Vagrant |
| Vagrant | 2.x | `vagrant --version` |
| vagrant-vmware-desktop | plugin | `vagrant plugin install vagrant-vmware-desktop` |
| Box base | `rocky9-updated` | Come negli altri ambienti del repository |
| RAM disponibile host | 6+ GB | La VM usa 4 GB |

---

## Struttura della cartella

```text
gitea/
├── gitea.md
├── Vagrantfile
└── scripts/
    └── install_gitea.sh
```

---

## Avvio della VM con Vagrant

Dalla cartella `gitea/`:

```bash
vagrant up --provider=vmware_desktop
```

Il `Vagrantfile` crea una VM Rocky Linux 9 con queste impostazioni:

- Hostname: `gitea-rocky9`
- IP bridged: `192.168.1.56`
- Interfaccia web Gitea: `http://192.168.1.56:3000`
- SSH Git: `192.168.1.56:2222`

Per entrare nella VM:

```bash
vagrant ssh
```

---

## Cosa installa il provisioner

Lo script `scripts/install_gitea.sh` esegue automaticamente:

1. aggiornamento del sistema Rocky 9;
2. disabilitazione di `firewalld` e SELinux per semplificare il laboratorio;
3. creazione dell'utente di servizio `git`;
4. download del binario ufficiale Gitea;
5. configurazione base con database SQLite locale;
6. registrazione di `gitea.service` in systemd;
7. avvio automatico del servizio.

La configurazione applicativa viene scritta in:

```text
/etc/gitea/app.ini
```

I dati vengono salvati in:

```text
/var/lib/gitea/
```

---

## Primo accesso e setup iniziale

Una volta completato il provisioning:

1. Apri `http://192.168.1.56:3000` dal browser.
2. Verifica che i parametri proposti corrispondano alla configurazione precompilata.
3. Lascia **SQLite3** come database se vuoi mantenere un setup leggero.
4. Crea l'utente amministratore iniziale dalla procedura guidata.
5. Completa l'installazione.

> Lo script lascia `INSTALL_LOCK = false` apposta, così la procedura web iniziale può completare la configurazione definitiva e generare le chiavi applicative.

---

## Operazioni comuni

### Stato del servizio

```bash
sudo systemctl status gitea
```

### Log applicativi

```bash
sudo journalctl -u gitea -f
```

### Riavvio del servizio

```bash
sudo systemctl restart gitea
```

### File di configurazione

```bash
sudo vi /etc/gitea/app.ini
```

Dopo una modifica:

```bash
sudo systemctl restart gitea
```

### URL clone SSH

Con la configurazione proposta, i repository SSH useranno la porta `2222`.
Esempio:

```bash
git clone ssh://git@192.168.1.56:2222/nomeutente/progetto.git
```

---

## Troubleshooting

### Il servizio non parte

Controlla:

```bash
sudo systemctl status gitea --no-pager
sudo journalctl -u gitea -n 100 --no-pager
```

### La pagina web non risponde

Verifica che la VM sia raggiungibile sull'IP configurato e che il servizio ascolti sulla porta 3000:

```bash
sudo ss -ltnp | grep 3000
```

### Cambio versione Gitea

Per installare una versione diversa, modifica la variabile `GITEA_VERSION` nel `Vagrantfile` oppure rilancia il provisioner con un valore diverso:

```bash
GITEA_VERSION=1.22.2 vagrant provision
```