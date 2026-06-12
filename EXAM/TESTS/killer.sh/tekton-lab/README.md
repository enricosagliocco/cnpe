# Tekton Pipelines and Triggers Lab

Le 20 domande sono presentate in formato exam-style: obiettivo
diretto, tip, soluzione operativa e verifica runtime.

Laboratorio autonomo con 20 esercizi deterministici dedicati a Tekton
Pipelines, TriggerBinding, TriggerTemplate, EventListener, interceptor CEL e
webhook end-to-end.

## Avvio con Minikube

Prerequisiti: Linux, `kubectl`, `curl` e Minikube.

```bash
chmod +x setup-tekton-lab.sh
./setup-tekton-lab.sh
```

## Avvio con kind

Prerequisiti: Linux, Docker o Podman, `kubectl`, `curl` e `kind`.

```bash
chmod +x setup-tekton-lab-kind.sh
./setup-tekton-lab-kind.sh
```

Il cluster viene creato con il nome `tekton-lab`. Puoi cambiarlo impostando
`KIND_CLUSTER_NAME`, per esempio:

```bash
KIND_CLUSTER_NAME=cnpe ./setup-tekton-lab-kind.sh
```

La variante kind installa anche il local-path provisioner e lo configura come
StorageClass predefinita, necessario per gli esercizi che creano PVC.

Il setup installa Tekton Pipelines v1.9.0 LTS, Tekton Triggers v0.33.0,
interceptor CEL e Tekton Dashboard. Gli starter vengono creati in
`~/course-tekton`; ogni directory contiene una risorsa incompleta o guasta e
gli input con cui verificare la correzione. Gli esercizi Trigger Q11-Q20
includono autonomamente Pipeline, RBAC, risorse Trigger, payload JSON e uno
script `send-event.sh` per la prova end-to-end. Per aprire la GUI:

```bash
kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 30120:9097
```

Apri `http://127.0.0.1:30120`. Per rigenerare:
`LAB_FORCE=true ./setup-tekton-lab-kind.sh` (oppure lo script Minikube).

## Metodologia comune

Questo lab segue il contratto descritto in `../LAB-METHODOLOGY.md`: 20 task
numerati, `QUESTION.md` ed `evidence.txt` per ogni domanda, soluzioni separate
e verifica esplicita del risultato runtime.

Controllo metodologico offline:

```bash
./
validate-tekton-lab.sh
```
