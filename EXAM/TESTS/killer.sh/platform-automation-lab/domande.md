# Le 20 domande dell'esame - Platform Automation Lab (simulatore lab)

## Metodo operativo obbligatorio

Ogni domanda e un ticket di troubleshooting. Devi:

1. riprodurre o osservare lo stato iniziale nel cluster;
2. raccogliere il sintomo tramite stato, condizioni, eventi, log o output del controller;
3. identificare e registrare la causa radice;
4. creare gli elementi mancanti o correggere le sole risorse coinvolte;
5. applicare la soluzione e verificarla con un test runtime positivo e, quando previsto, negativo.

La sola modifica del file, il solo dry-run client-side o una risposta teorica
non completano il ticket. Conserva comando, errore iniziale, correzione e
verifica finale nell'evidence file indicato dalla domanda.

Scenario creato da `setup-platform-automation-lab.sh`. Gli starter sono in
`~/course-platform-automation/`.

Vincoli:

- non disinstallare o modificare i componenti core di Gatekeeper, Crossplane,
  Tekton, OpenTelemetry, Metrics Server o KEDA;
- non concedere `cluster-admin` e non usare wildcard RBAC;
- non usare `nodeName`;
- applicare realmente i manifest e conservare le verifiche nei file indicati.

Comandi utili:

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl api-resources
kubectl auth can-i --list
```

---

### Q1 - Gatekeeper ConstraintTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/01`.

Completa `template.yaml` affinche i Deployment:

1. abbiano la label `owner`;
2. abbiano almeno il numero di repliche ricevuto nel parametro `minReplicas`;
3. producano messaggi di violazione distinti per label e repliche.

Applica il ConstraintTemplate e attendi che sia `Created=True`.

### Q2 - Gatekeeper enforcement e test
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/01`.

1. Completa `constraint.yaml` con `minReplicas: 2` e limita il match al
   Namespace `policy-apps`.
2. Verifica che `invalid-deployment.yaml` venga negato.
3. Correggi il Deployment aggiungendo `owner: platform` e due repliche.
4. Salva test negativo, test positivo e violazioni in `gatekeeper-check.txt`.

---

### Q3 - Crossplane XRD
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/02`.

Completa `xrd.yaml` per una API namespaced `WebApp`:

1. group `platform.cnpe.io`, plural `webapps`;
2. versione `v1alpha1` served e referenceable;
3. campi obbligatori `spec.image` e `spec.replicas`;
4. `replicas` integer tra 1 e 5, default 1.

Applica la XRD e verifica la CRD generata.

### Q4 - Crossplane Composition
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/02`.

Completa e applica `composition.yaml` affinche ogni `WebApp` generi:

1. un Deployment con nome e Namespace ereditati dalla XR;
2. immagine e repliche ricavate dallo spec;
3. un Service ClusterIP sulla porta 80 con selector coerente.

Applica `webapp.yaml`, attendi le risorse composte e salva stato e resource
references in `crossplane-check.txt`.

---

### Q5 - Tekton TriggerBinding e TriggerTemplate
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/03`.

Completa `triggers.yaml`:

1. estrai `repository.name` e `after` dal payload JSON;
2. passa i valori al TriggerTemplate;
3. genera un PipelineRun della Pipeline `webhook-build`;
4. usa il ServiceAccount `tekton-trigger`.

### Q6 - EventListener e webhook
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/03`.

1. Completa l'EventListener con un interceptor CEL che accetti solo
   `body.ref == 'refs/heads/main'`.
2. Applica RBAC e risorse Trigger.
3. Invia `payload-main.json`: deve creare un PipelineRun riuscito.
4. Invia `payload-feature.json`: non deve creare PipelineRun.
5. Salva risposta HTTP, PipelineRun e log in `tekton-check.txt`.

---

### Q7 - OpenTelemetry Collector pipeline
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/04`.

Correggi `collector-config.yaml`:

1. abilita il receiver OTLP gRPC e HTTP;
2. aggiungi processor `batch`;
3. configura exporter `debug`;
4. crea pipeline `traces` con receiver, processor ed exporter.

Applica ConfigMap e Deployment e verifica il rollout.

### Q8 - Invio e verifica trace
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/04`.

1. Esegui `telemetrygen-job.yaml` per inviare almeno 20 span al Collector.
2. Verifica nei log del Collector `ResourceSpans` e il service name
   `checkout`.
3. Salva configurazione effettiva, log ed esito Job in `otel-check.txt`.

---

### Q9 - RBAC least privilege
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/05`.

Completa `rbac.yaml` affinche `release-bot` nel Namespace `team-a` possa:

1. leggere Deployment;
2. aggiornare e patchare solo il Deployment `web`;
3. leggere Pod e relativi log;
4. non creare o eliminare Deployment.

### Q10 - Test RBAC positivi e negativi
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/05`.

Usando impersonation verifica:

1. patch di `team-a/web` consentita;
2. patch di `team-a/worker` negata;
3. lettura log Pod consentita;
4. lettura Secret e accesso al Namespace `team-b` negati.

Salva comandi, output ed exit code in `rbac-check.txt`.

---

### Q11 - NetworkPolicy ingress
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/06`.

Completa `networkpolicy.yaml` per applicare default deny e consentire al
backend TCP 8080 soltanto dai Pod `app=frontend` nel Namespace
`network-client`.

### Q12 - NetworkPolicy egress e verifica
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/06`.

1. Consenti al frontend egress DNS UDP/TCP 53.
2. Consenti egress TCP 8080 soltanto verso il backend.
3. Dimostra frontend consentito, intruder negato ed egress Internet negato.
4. Salva i test in `network-check.txt`.

---

### Q13 - Taint e toleration
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/07`.

Il worker con label `workload.cnpe.io/tier=dedicated` ha il taint
`dedicated=platform:NoSchedule`.

1. Aggiungi al Deployment `platform-api` la toleration esatta.
2. Aggiungi required node affinity verso la label del worker dedicato.
3. Applica e verifica che le due repliche siano sul nodo corretto.

### Q14 - Pod anti-affinity
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/07`.

1. Aggiungi preferred pod anti-affinity su `kubernetes.io/hostname`.
2. Mantieni invariati taint, toleration e required node affinity.
3. Salva Pod, nodi, taint e decisioni dello scheduler in
   `scheduling-check.txt`.

---

### Q15 - Helm templating
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/08/app-chart`.

Correggi il chart affinche:

1. nome immagine, tag, repliche e service port provengano da `values.yaml`;
2. label e selector usino un helper comune;
3. `helm lint` e `helm template` non producano errori.

### Q16 - Helm install e upgrade
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/08`.

1. Imposta `appVersion: 1.27.4` e chart `version: 0.2.0`.
2. Installa release `portal` nel Namespace `helm-apps`.
3. Esegui upgrade con `replicaCount=3` e `service.port=8080`.
4. Salva history, values e manifest in `helm-check.txt`.

---

### Q17 - StorageClass e binding ritardato
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/09`.

Correggi `storage.yaml`:

1. StorageClass `platform-local` con `WaitForFirstConsumer`;
2. reclaim policy `Retain`;
3. PV locale sul worker indicato in `node.txt`;
4. PVC da `1Gi`, `ReadWriteOnce`, StorageClass corretta.

### Q18 - PVC, scheduling e persistenza
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/09`.

1. Applica `storage.yaml` e verifica PV/PVC `Bound`.
2. Verifica che `storage-writer` sia schedulato sul nodo del PV.
3. Scrivi un valore in `/data/check.txt`, ricrea il Pod e verifica che resti.
4. Salva binding, affinity e prova di persistenza in `storage-check.txt`.

---

### Q19 - HPA CPU
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/10`.

Correggi `hpa.yaml`:

1. target Deployment `api`;
2. minimo 1, massimo 5 repliche;
3. target CPU media 50%;
4. verifica che l'HPA legga metriche valide.

Genera carico con `load-generator.yaml` e salva il comportamento in
`autoscaling-check.txt`.

### Q20 - KEDA ScaledObject
**Ticket:** riproduci il sintomo, identifica la causa radice, crea o correggi gli elementi coinvolti, applica e verifica nel cluster.

Percorso: `~/course-platform-automation/10`.

Completa `scaledobject.yaml`:

1. target Deployment `worker`;
2. minimo 1, massimo 4 repliche;
3. polling 10 secondi e cooldown 30 secondi;
4. trigger CPU con target utilization 40.

Applica la risorsa, verifica l'HPA creato da KEDA e salva condizioni,
repliche e nome HPA in `autoscaling-check.txt`.

