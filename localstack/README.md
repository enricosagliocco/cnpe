# LocalStack su Vagrant (Docker Compose)

Questa cartella contiene un setup LocalStack su Rocky Linux 9 con provisioning automatico via Vagrant.

File principali:
- Vagrantfile
- install_localstack.sh
- docker-compose.yml

## Prerequisiti

- Vagrant
- VMware Desktop provider per Vagrant
- Accesso rete locale con bridge WLAN (come da Vagrantfile)
- Curl disponibile sul client per test endpoint

## Parametri attuali

Nel Vagrantfile sono configurati questi valori:
- IP VM LocalStack: 192.168.1.58
- Endpoint LocalStack: http://192.168.1.58:4566
- Versione LocalStack: 3.5.0
- Regione AWS default: eu-west-1

## Avvio ambiente

Dalla cartella localstack:

```bash
vagrant up --provider=vmware_desktop
```

Accesso VM:

```bash
vagrant ssh
```

Verifica servizi LocalStack in VM:

```bash
sudo docker compose -f /opt/localstack/docker-compose.yml ps
```

Log servizio LocalStack:

```bash
sudo docker compose -f /opt/localstack/docker-compose.yml logs -f localstack
```

## Verifica endpoint LocalStack

Dal client o dalla VM:

```bash
curl -s http://192.168.1.58:4566/_localstack/health
```

Dovresti ricevere un JSON con stato `running`.

## Test rapido API AWS emulata (S3)

Da VM (installato nel provisioning):

```bash
awslocal s3 mb s3://demo-bucket
awslocal s3 ls
```

## Servizi abilitati nel compose

Nel file `docker-compose.yml` sono preconfigurati:
- s3
- sqs
- sns
- dynamodb
- lambda
- iam
- sts
- cloudwatch
- logs
- apigateway

Puoi personalizzare la variabile `SERVICES` e rilanciare:

```bash
sudo docker compose -f /opt/localstack/docker-compose.yml up -d
```

## Troubleshooting rapido

- LocalStack non raggiungibile:
  - Verifica IP bridged nel Vagrantfile.
  - Verifica container attivo con `docker ps` in VM.

- Endpoint health non disponibile:
  - Controlla log con `sudo docker compose -f /opt/localstack/docker-compose.yml logs localstack`.

- Errore networking su VM:
  - Riesegui provisioning: `vagrant provision`.
