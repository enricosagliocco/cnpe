# Backstage su Rocky 9 con Vagrant (installazione nativa)

Questa cartella contiene una installazione base di Backstage su VM Rocky Linux 9,
senza Docker, usando la procedura standard adattata da Ubuntu a Rocky.

## Struttura minima

```
backstage/
├── Vagrantfile
├── scripts/
│   └── install_backstage.sh
└── README.md
```

## Avvio rapido

```bash
cd backstage
vagrant up
```

Il provisioning esegue automaticamente:

1. Aggiornamento sistema e prerequisiti (`curl`, `git`, `make`, `gcc`, `python3`, `python3-pip`)
2. Installazione `nvm`
3. Installazione Node.js LTS (>=20)
4. `corepack enable` e `yarn set version 4.4.1`
5. `npx @backstage/create-app@latest` con nome app `my-backstage`
6. Aggiornamento di `app-config.yaml` con IP `192.168.1.60`
7. Avvio di Backstage come servizio systemd

## Accesso GUI

- Frontend: http://192.168.1.60:3000
- Backend: http://192.168.1.60:7007

## Comandi utili

```bash
# Stato VM
vagrant status

# Accesso shell VM
vagrant ssh

# Stato servizio Backstage (dentro VM)
sudo systemctl status backstage

# Log servizio (dentro VM)
sudo journalctl -u backstage -f
```

## Note

- VM base: `rocky9-updated`
- Rete bridged: `192.168.1.60`
- Porte 3000 e 7007 aperte se `firewalld` è attivo
