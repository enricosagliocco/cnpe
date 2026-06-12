# Platform Automation Lab - 20 exam-style tasks

Ogni domanda e una prova pratica autonoma. Esamina i file forniti, applica
le risorse richieste e verifica il risultato nel cluster. Le sezioni
`Tip` aiutano a individuare API, file e comandi utili; la sezione
Le soluzioni sono raccolte nella sezione finale del documento.

Non modificare o disinstallare i componenti core installati dal setup.
Usa il kubeconfig corrente e conserva le evidenze richieste dalla domanda.


Comandi utili:

```bash
kubectl config current-context
kubectl api-resources
kubectl get events -A --sort-by=.lastTimestamp
```

---
### Q1 - Gatekeeper ConstraintTemplate

Percorso: `~/course-platform-automation/01`.

Completa `template.yaml` affinche i Deployment:

1. abbiano la label `owner`;
2. abbiano almeno il numero di repliche ricevuto nel parametro `minReplicas`;
3. producano messaggi di violazione distinti per label e repliche.

Applica il ConstraintTemplate e attendi che sia `Created=True`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f template.yaml
```

---

### Q2 - Gatekeeper enforcement e test

Percorso: `~/course-platform-automation/01`.

1. Completa `constraint.yaml` con `minReplicas: 2` e limita il match al
   Namespace `policy-apps`.
2. Verifica che `invalid-deployment.yaml` venga negato.
3. Correggi il Deployment aggiungendo `owner: platform` e due repliche.
4. Salva test negativo, test positivo e violazioni in `gatekeeper-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/01` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f constraint.yaml
```

---

### Q3 - Crossplane XRD

Percorso: `~/course-platform-automation/02`.

Completa `xrd.yaml` per una API namespaced `WebApp`:

1. group `platform.cnpe.io`, plural `webapps`;
2. versione `v1alpha1` served e referenceable;
3. campi obbligatori `spec.image` e `spec.replicas`;
4. `replicas` integer tra 1 e 5, default 1.

Applica la XRD e verifica la CRD generata.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f xrd.yaml
```

---

### Q4 - Crossplane Composition

Percorso: `~/course-platform-automation/02`.

Completa e applica `composition.yaml` affinche ogni `WebApp` generi:

1. un Deployment con nome e Namespace ereditati dalla XR;
2. immagine e repliche ricavate dallo spec;
3. un Service ClusterIP sulla porta 80 con selector coerente.

Applica `webapp.yaml`, attendi le risorse composte e salva stato e resource
references in `crossplane-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/02` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f composition.yaml
```

---

### Q5 - Tekton TriggerBinding e TriggerTemplate

Percorso: `~/course-platform-automation/03`.

Completa `triggers.yaml`:

1. estrai `repository.name` e `after` dal payload JSON;
2. passa i valori al TriggerTemplate;
3. genera un PipelineRun della Pipeline `webhook-build`;
4. usa il ServiceAccount `tekton-trigger`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f triggers.yaml
```

---

### Q6 - EventListener e webhook

Percorso: `~/course-platform-automation/03`.

1. Completa l'EventListener con un interceptor CEL che accetti solo
   `body.ref == 'refs/heads/main'`.
2. Applica RBAC e risorse Trigger.
3. Invia `payload-main.json`: deve creare un PipelineRun riuscito.
4. Invia `payload-feature.json`: non deve creare PipelineRun.
5. Salva risposta HTTP, PipelineRun e log in `tekton-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/03` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f payload-main.json
```

---

### Q7 - OpenTelemetry Collector pipeline

Percorso: `~/course-platform-automation/04`.

Correggi `collector-config.yaml`:

1. abilita il receiver OTLP gRPC e HTTP;
2. aggiungi processor `batch`;
3. configura exporter `debug`;
4. crea pipeline `traces` con receiver, processor ed exporter.

Applica ConfigMap e Deployment e verifica il rollout.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f collector-config.yaml
```

---

### Q8 - Invio e verifica trace

Percorso: `~/course-platform-automation/04`.

1. Esegui `telemetrygen-job.yaml` per inviare almeno 20 span al Collector.
2. Verifica nei log del Collector `ResourceSpans` e il service name
   `checkout`.
3. Salva configurazione effettiva, log ed esito Job in `otel-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/04` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f telemetrygen-job.yaml
```

---

### Q9 - RBAC least privilege

Percorso: `~/course-platform-automation/05`.

Completa `rbac.yaml` affinche `release-bot` nel Namespace `team-a` possa:

1. leggere Deployment;
2. aggiornare e patchare solo il Deployment `web`;
3. leggere Pod e relativi log;
4. non creare o eliminare Deployment.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/05` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f rbac.yaml
```

---

### Q10 - Test RBAC positivi e negativi

Percorso: `~/course-platform-automation/05`.

Usando impersonation verifica:

1. patch di `team-a/web` consentita;
2. patch di `team-a/worker` negata;
3. lettura log Pod consentita;
4. lettura Secret e accesso al Namespace `team-b` negati.

Salva comandi, output ed exit code in `rbac-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/05` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q11 - NetworkPolicy ingress

Percorso: `~/course-platform-automation/06`.

Completa `networkpolicy.yaml` per applicare default deny e consentire al
backend TCP 8080 soltanto dai Pod `app=frontend` nel Namespace
`network-client`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/06` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f networkpolicy.yaml
```

---

### Q12 - NetworkPolicy egress e verifica

Percorso: `~/course-platform-automation/06`.

1. Consenti al frontend egress DNS UDP/TCP 53.
2. Consenti egress TCP 8080 soltanto verso il backend.
3. Dimostra frontend consentito, intruder negato ed egress Internet negato.
4. Salva i test in `network-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/06` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q13 - Taint e toleration

Percorso: `~/course-platform-automation/07`.

Il worker con label `workload.cnpe.io/tier=dedicated` ha il taint
`dedicated=platform:NoSchedule`.

1. Aggiungi al Deployment `platform-api` la toleration esatta.
2. Aggiungi required node affinity verso la label del worker dedicato.
3. Applica e verifica che le due repliche siano sul nodo corretto.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/07` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q14 - Pod anti-affinity

Percorso: `~/course-platform-automation/07`.

1. Aggiungi preferred pod anti-affinity su `kubernetes.io/hostname`.
2. Mantieni invariati taint, toleration e required node affinity.
3. Salva Pod, nodi, taint e decisioni dello scheduler in
   `scheduling-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/07` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q15 - Helm templating

Percorso: `~/course-platform-automation/08/app-chart`.

Correggi il chart affinche:

1. nome immagine, tag, repliche e service port provengano da `values.yaml`;
2. label e selector usino un helper comune;
3. `helm lint` e `helm template` non producano errori.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/08/app-chart` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f values.yaml
```

---

### Q16 - Helm install e upgrade

Percorso: `~/course-platform-automation/08`.

1. Imposta `appVersion: 1.27.4` e chart `version: 0.2.0`.
2. Installa release `portal` nel Namespace `helm-apps`.
3. Esegui upgrade con `replicaCount=3` e `service.port=8080`.
4. Salva history, values e manifest in `helm-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/08` prima di applicarli.

**Tip 2**

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Q17 - StorageClass e binding ritardato

Percorso: `~/course-platform-automation/09`.

Correggi `storage.yaml`:

1. StorageClass `platform-local` con `WaitForFirstConsumer`;
2. reclaim policy `Retain`;
3. PV locale sul worker indicato in `node.txt`;
4. PVC da `1Gi`, `ReadWriteOnce`, StorageClass corretta.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/09` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f storage.yaml
```

---

### Q18 - PVC, scheduling e persistenza

Percorso: `~/course-platform-automation/09`.

1. Applica `storage.yaml` e verifica PV/PVC `Bound`.
2. Verifica che `storage-writer` sia schedulato sul nodo del PV.
3. Scrivi un valore in `/data/check.txt`, ricrea il Pod e verifica che resti.
4. Salva binding, affinity e prova di persistenza in `storage-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/09` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f storage.yaml
```

---

### Q19 - HPA CPU

Percorso: `~/course-platform-automation/10`.

Correggi `hpa.yaml`:

1. target Deployment `api`;
2. minimo 1, massimo 5 repliche;
3. target CPU media 50%;
4. verifica che l'HPA legga metriche valide.

Genera carico con `load-generator.yaml` e salva il comportamento in
`autoscaling-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f hpa.yaml
```

---

### Q20 - KEDA ScaledObject

Percorso: `~/course-platform-automation/10`.

Completa `scaledobject.yaml`:

1. target Deployment `worker`;
2. minimo 1, massimo 4 repliche;
3. polling 10 secondi e cooldown 30 secondi;
4. trigger CPU con target utilization 40.

Applica la risorsa, verifica l'HPA creato da KEDA e salva condizioni,
repliche e nome HPA in `autoscaling-check.txt`.

**Tip 1**

Esamina tutti i manifest presenti in `~/course-platform-automation/10` prima di applicarli.

**Tip 2**

```bash
kubectl apply --server-side --dry-run=server -f scaledobject.yaml
```

---

## Soluzioni

Le soluzioni sono raccolte qui per permettere lo svolgimento delle prove senza anticipazioni.

### Soluzione Q1 - Gatekeeper ConstraintTemplate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/01
kubectl apply -f template.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q2 - Gatekeeper enforcement e test

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/01
kubectl apply -f constraint.yaml
kubectl apply -f invalid-deployment.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q3 - Crossplane XRD

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/02
kubectl apply -f xrd.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q4 - Crossplane Composition

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/02
kubectl apply -f composition.yaml
kubectl apply -f webapp.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q5 - Tekton TriggerBinding e TriggerTemplate

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/03
kubectl apply -f triggers.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q6 - EventListener e webhook

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/03
kubectl apply -f payload-main.json
kubectl apply -f payload-feature.json
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q7 - OpenTelemetry Collector pipeline

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/04
kubectl apply -f collector-config.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q8 - Invio e verifica trace

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/04
kubectl apply -f telemetrygen-job.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q9 - RBAC least privilege

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/05
kubectl apply -f rbac.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q10 - Test RBAC positivi e negativi

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/05
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q11 - NetworkPolicy ingress

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/06
kubectl apply -f networkpolicy.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q12 - NetworkPolicy egress e verifica

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/06
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q13 - Taint e toleration

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/07
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q14 - Pod anti-affinity

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/07
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q15 - Helm templating

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/08/app-chart
kubectl apply -f values.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q16 - Helm install e upgrade

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/08
kubectl get all -A
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q17 - StorageClass e binding ritardato

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/09
kubectl apply -f storage.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q18 - PVC, scheduling e persistenza

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/09
kubectl apply -f storage.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q19 - HPA CPU

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/10
kubectl apply -f hpa.yaml
kubectl apply -f load-generator.yaml
kubectl get events -A --sort-by=.lastTimestamp
```

---

### Soluzione Q20 - KEDA ScaledObject

Porta le risorse allo stato richiesto dalla domanda, applicale e verifica
condizioni, eventi e comportamento runtime indicati nei criteri precedenti.

```bash
cd ~/course-platform-automation/10
kubectl apply -f scaledobject.yaml
kubectl get events -A --sort-by=.lastTimestamp
```
