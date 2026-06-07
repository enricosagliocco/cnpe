# Le 20 domande dell'esame — CNPE Alternative Lab (simulatore lab)

Scenario creato da `setup-cnpe-alt-lab.sh`. I file sono in `~/course-alt`.

**Vincolo:** non disinstallare i tool installati. Puoi modificare configurazioni,
manifest e risorse applicative, ma non rimuovere i componenti core.

Ogni domanda parte da una risorsa running non conforme, da un controller in
errore o da un file starter incompleto creato dal setup. Devi prima osservare
o riprodurre il problema, poi modificare e applicare la soluzione e infine
verificare il risultato nel cluster. Commit, report o file locali richiesti
sono evidenze aggiuntive e non sostituiscono la verifica runtime.

## Accesso GUI

Le interfacce principali sono esposte sul nodo del cluster:

| Prodotto | URL | Port-forward alternativo |
|---|---|---|
| Prometheus | `http://<node>:30020` | `kubectl -n prometheus port-forward --address 0.0.0.0 svc/prometheus-server 30020:9090` |
| Argo CD | `https://<node>:30030` | `kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 30030:443` |
| OpenCost | `http://<node>:30070` | `kubectl -n opencost port-forward --address 0.0.0.0 svc/opencost-nodeport 30070:9090` |
| Grafana | `http://<node>:30080` | `kubectl -n monitoring port-forward --address 0.0.0.0 svc/grafana 30080:80` |
| Argo Workflows | `http://<node>:30110` | `kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 30110:2746` |
| Tekton | `http://<node>:30120` | `kubectl -n tekton-pipelines port-forward --address 0.0.0.0 svc/tekton-dashboard 30120:9097` |
| Jaeger | `http://<node>:30014` | `kubectl -n eyre port-forward --address 0.0.0.0 svc/jaeger 30014:16686` |
| Argo Rollouts | `http://<node>:30160` | `kubectl -n argo-rollouts port-forward --address 0.0.0.0 svc/argo-rollouts-dashboard 30160:3100` |

Credenziali:

- Argo CD: utente `admin`; password con
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`.
- Grafana: utente `admin`, password `admin`; e abilitato anche l'accesso anonimo.
- Le altre GUI normalmente non richiedono login nel lab.

Usa le GUI per query, sincronizzazioni, log, trace e avanzamento dei rollout.
Per CRD, Crossplane, policy e risorse Kubernetes usa Lens/OpenLens con il
kubeconfig corrente. Mantieni il terminale per modificare e applicare i file
starter e per salvare gli output richiesti.

---

### Q1 – CRD, Kustomize e Git

La CRD `PlatformService` è installata dal repository
`~/course-alt/1/platform-service`.

1. Aggiungi la versione `v1alpha2`.
2. In `v1alpha2`, aggiungi:
   - `spec.tier`, string enum `bronze`, `silver`, `gold`;
   - `spec.exposure`, oggetto con proprietà string `hostname` e `path`.
3. Mantieni `v1alpha1` servita ma non storage; imposta `v1alpha2` come storage.
4. Applica la CRD con Kustomize.
5. Fai commit e push sul branch `main`.
6. Crea nel Namespace `selfservice-alt` una `PlatformService` chiamata
   `payments`, con `tier: gold`, hostname `payments.internal` e path `/api`.
7. Verifica la versione storage della CRD e la risorsa `payments` dal cluster.

---

### Q2 – Prometheus

Prometheus è nel Namespace `prometheus`. Nel Namespace `atlas` esistono i
Deployment `checkout` e `proxy`, che espongono `/metrics` sulla porta `8080`.
La configurazione attuale non include `atlas`.

1. Modifica il ConfigMap `prometheus-server` aggiungendo uno scrape job
   `atlas-apps`:
   - Namespace: `atlas`;
   - Pod label `app` corrispondente a `checkout|proxy`;
   - target `<pod-ip>:8080`;
   - path `/metrics`.
2. Ricarica Prometheus tramite `POST /-/reload` oppure riavvia lo StatefulSet.
3. Esegui la query:
   ```promql
   http_requests_per_minute{namespace="atlas"}
   ```
4. Scala a 2 repliche il Deployment con il valore maggiore.
5. Salva query, risultato e comando di scaling in
   `~/course-alt/2/prometheus-report.txt`.
6. Verifica il nuovo numero di repliche e che entrambi i target restino UP.

---

### Q3 – Argo CD e branch Git

Il repository `~/course-alt/3/portal-client` è usato dall'Application Argo CD
`portal-client`, branch `main`, Namespace `baltic`.

1. Sul branch `main`, cambia la label Pod `version` da `v1` a `v2`, fai commit
   e push.
2. Crea il branch `staging`, cambia la label a `version: v3`, fai commit e push.
3. Crea l'Application `portal-client-staging`:
   - project `lagoon`;
   - stesso repository di `portal-client`;
   - path `manifests`;
   - branch `staging`;
   - Namespace destinazione `baltic-staging`;
   - sync automatica con prune e self-heal.
4. Verifica che `portal-client` esponga `version=v2` e
   `portal-client-staging` esponga `version=v3`.

---

### Q4 – Flagger pre-rollout webhook

Nel Namespace `delivery-alt` esistono Deployment `catalog` e Canary `catalog`.
Il Deployment ha `APP_VERSION=1.0.0`.

1. Aggiungi al Canary un webhook:
   - name `catalog-http-check`;
   - type `pre-rollout`;
   - URL `http://catalog-canary.delivery-alt`;
   - timeout `5s`;
   - metodo `GET`;
   - status atteso `200`.
2. Imposta `APP_VERSION=1.0.1` nel Deployment.
3. Attendi la conclusione del rollout.
4. Salva gli eventi del Canary in `~/course-alt/4/catalog-events.log`.
5. Verifica Canary `Succeeded` e Deployment stabile alla nuova versione.

---

### Q5 – Argo Rollouts e AnalysisTemplate

Nel Namespace `delivery-alt` il Rollout `frontend-rollout` usa una strategia
canary con una pausa al 50%. Il file
`~/course-alt/5/analysis-template.yaml` contiene un URL incompleto.

1. Imposta l'URL del metric provider a:
   `http://frontend-rollout-canary.delivery-alt`.
2. Applica l'AnalysisTemplate `frontend-http-check`.
3. Nel Rollout sostituisci il passo `pause` con:
   ```yaml
   - analysis:
       templates:
         - templateName: frontend-http-check
   ```
4. Avvia un nuovo rollout impostando `VERSION=2.0.0`.
5. Promuovi il Rollout solo se l'AnalysisRun termina con stato `Successful`.
6. Verifica Rollout `Healthy` e AnalysisRun `Successful`.

---

### Q6 – Tekton Pipeline

Il file `~/course-alt/6/tekton-api/pipeline.yaml` contiene due Task completi,
ma la Pipeline `api-build` non li usa.

1. Aggiungi alla Pipeline il Task `clone` con `taskRef: api-git-clone`.
2. Passa `repo-url` e il workspace `source`.
3. Aggiungi `print-sha` con `taskRef: api-print-sha`, stesso workspace e
   `runAfter: [clone]`.
4. Applica il file nel Namespace `cicd-alt`.
5. Applica `~/course-alt/6/tekton-api/pipelinerun.yaml`.
6. Verifica che il log contenga un commit SHA di 40 caratteri.
7. Fai commit e push della Pipeline corretta sul branch `main`.

---

### Q7 – FluxCD

Il repository `~/course-alt/7/flux-platform` contiene
`clusters/dev/apps/demo`, ma il `kustomization.yaml` padre non lo include.
Il GitRepository Flux `flux-platform` usa inoltre il branch inesistente
`develop`.

1. Aggiungi `demo` a `clusters/dev/apps/kustomization.yaml`.
2. Fai commit e push sul branch `main`.
3. Correggi il GitRepository `flux-platform` affinché usi `main`.
4. Verifica la Kustomization `flux-platform`:
   - path `./clusters/dev/apps`;
   - target Namespace `flux-platform`;
   - `prune: true`;
   - stato `Ready=True`.
5. Verifica Deployment e Service `demo`.

---

### Q8 – Crossplane platform API

In `~/course-alt/8/platform-api` sono presenti XRD, Composition e XR
incompleti.

1. Nell'XRD aggiungi allo schema:
   - `spec.databaseName`, string;
   - `spec.storageSize`, string.
2. Completa la Composition affinché crei un ConfigMap `postgres-config` nel
   Namespace dell'XR con:
   - `data.databaseName` da `spec.databaseName`;
   - `data.storageSize` da `spec.storageSize`.
3. Applica XRD e Composition.
4. Completa e applica l'XR `orders-db` in `selfservice-alt` con:
   - `databaseName: orders`;
   - `storageSize: 10Gi`.
5. Verifica il ConfigMap generato.

---

### Q9 – Backstage Software Template

Completa `~/course-alt/9/backstage-template/template.yaml`.

1. Crea un unico gruppo di parametri con i campi obbligatori:
   - `serviceName`, string;
   - `owner`, string;
   - `namespace`, string.
2. Aggiungi uno step `fetch-template` con action `fetch:template`:
   - `url: ./skeleton`;
   - valori presi dai tre parametri.
3. Aggiungi uno step `publish` con action `publish:gitea`:
   - `repoUrl: gitea.local?repo=${{ parameters.serviceName }}&owner=organization`;
   - description `Generated platform service`.
4. Nell'output aggiungi il link `Repository` da
   `${{ steps.publish.output.remoteUrl }}`.
5. Verifica che il file sia YAML valido.

---

### Q10 – OpenTofu Kubernetes provider

Il Namespace `team-a` esiste già. Il file
`~/course-alt/10/tofu-k8s/main.tf` contiene solo il provider.

1. Dichiara `kubernetes_namespace.team` con nome `team-a`.
2. Importa il Namespace nello state:
   ```bash
   tofu import kubernetes_namespace.team team-a
   ```
   Usa `terraform` se `tofu` non è disponibile.
3. Aggiungi nel Namespace `team-a`:
   - ConfigMap `platform-settings` con `environment = "training"`;
   - ServiceAccount `automation`.
4. Esegui init, plan e apply.
5. Salva l'output finale in `~/course-alt/10/tofu-output.txt`.
6. Verifica Namespace importato, ConfigMap e ServiceAccount nel cluster.

---

### Q11 – OpenTelemetry endpoint

Il Deployment `telemetry-api` nel Namespace `obs-alt` usa
`OTEL_EXPORTER_OTLP_ENDPOINT=http://wrong-collector:4317`.
Il collector disponibile è `jaeger-collector.obs-alt:4317`.

1. Correggi la variabile con:
   `http://jaeger-collector.obs-alt:4317`.
2. Riavvia il Deployment.
3. Verifica dal Pod che DNS e porta TCP `4317` siano raggiungibili.
4. Salva la verifica in `~/course-alt/11/otel-check.txt`.

---

### Q12 – Grafana e Loki

Grafana è su `http://<node>:30080`; Loki è la datasource predefinita.
Il Deployment `telemetry-api` genera log `INFO` e `ERROR`.

1. Esegui in Explore:
   ```logql
   {namespace="obs-alt", pod=~"telemetry-api.*"} |= "ERROR"
   ```
2. Nel dashboard `observability-alt`, sostituisci la query del pannello con:
   ```logql
   count_over_time({namespace="obs-alt", pod=~"telemetry-api.*"} |= "ERROR" [5m])
   ```
3. Imposta `Maximum lines` della datasource Loki a `200`.
4. Salva in `~/course-alt/12/log-triage.md` query, Pod trovato e comando
   `kubectl logs` equivalente.
5. Verifica che dashboard e datasource mantengano le modifiche dopo reload.

---

### Q13 – Gatekeeper owner label

In `~/course-alt/13/gatekeeper` sono presenti template, Constraint e due
Deployment di test.

1. Completa lo schema con parametro `label` di tipo string.
2. Modifica la policy affinché usi `input.parameters.label`.
3. Il messaggio deve essere:
   `Deployment is missing required label: <label>`.
4. Completa `require-owner.yaml` per richiedere `owner` soltanto ai Deployment
   nel Namespace `security-alt`, con `enforcementAction: deny`.
5. Verifica che `deployment-bad.yaml` sia negato e `deployment-good.yaml`
   accettato.

---

### Q14 – Kyverno runAsNonRoot

Completa `~/course-alt/14/kyverno/policy.yaml`.

1. Usa `validationFailureAction: Enforce`.
2. Applica la regola soltanto ai Pod nel Namespace `security-alt`.
3. Escludi il Namespace `kube-system`.
4. Richiedi:
   ```yaml
   spec:
     securityContext:
       runAsNonRoot: true
   ```
5. Verifica che `pod-bad.yaml` sia negato e `pod-good.yaml` accettato.

---

### Q15 – Pod Security Standards restricted

Il Namespace `security-alt` non applica ancora Pod Security Standards e
contiene il Deployment non conforme `legacy-worker`. Il manifest è
`~/course-alt/15/pod-security/legacy-worker.yaml`.

1. Configura il Namespace con:
   - `pod-security.kubernetes.io/enforce=restricted`;
   - `pod-security.kubernetes.io/enforce-version=latest`.
2. Correggi Pod e container impostando:

- `runAsNonRoot: true`;
- `runAsUser: 1000`;
- `seccompProfile.type: RuntimeDefault`;
- `allowPrivilegeEscalation: false`;
- `capabilities.drop: ["ALL"]`;
- container non privilegiato.

3. Applica il file, riavvia il Deployment e verifica il rollout.

---

### Q16 – RBAC least privilege

Nel Namespace `security-alt` esiste il ServiceAccount `report-reader`.
Completa `~/course-alt/16/rbac/rbac.yaml`:

1. Role `report-reader`:
   - apiGroup core;
   - risorse `pods` e `configmaps`;
   - verbi `get`, `list`, `watch`.
2. RoleBinding `report-reader` associato al ServiceAccount omonimo.
3. Verifica:
   - può listare Pod e ConfigMap;
   - non può eliminare Pod;
   - non può leggere Secret.
4. Salva i risultati in `~/course-alt/16/rbac/auth-check.txt`.

---

### Q17 – KEDA cron scaling

KEDA è installato. Nel Namespace `data-alt` esiste il Deployment
`queue-worker`. Completa `~/course-alt/17/keda/scaledobject.yaml`.

1. Configura un trigger `cron` con:
   - timezone `Europe/Rome`;
   - start `0 8 * * 1-5`;
   - end `0 18 * * 1-5`;
   - desiredReplicas `"3"`;
   - minReplicaCount `0`;
   - maxReplicaCount `5`.
2. Applica il file.
3. Verifica la creazione dell'HPA.
4. Salva ScaledObject e HPA in `~/course-alt/17/keda/status.txt`.

---

### Q18 – OpenCost API

OpenCost è installato nel Namespace `opencost`.

1. Esegui:
   ```bash
   kubectl -n opencost port-forward svc/opencost 9003:9003
   ```
2. Interroga:
   ```text
   http://127.0.0.1:9003/allocation/compute?window=1h&aggregate=namespace
   ```
3. Salva la risposta JSON in `~/course-alt/18/opencost/allocation.json`.
4. Scrivi comando di port-forward e URL in
   `~/course-alt/18/opencost/access.txt`.
5. Verifica risposta HTTP 200 e JSON valido con almeno un'allocazione.

---

### Q19 – Linkerd

Nel Namespace `mesh-alt` esistono Deployment `mesh-server`, Deployment
`mesh-client` e Service `mesh-server`, ma il Namespace non è annotato per
l'injection.

1. Annota `mesh-alt` con `linkerd.io/inject=enabled`.
2. Riavvia entrambi i Deployment.
3. Verifica che ogni Pod abbia due container (`app` e `linkerd-proxy`).
4. Dal Pod client esegui:
   ```bash
   wget -qO- http://mesh-server
   ```
   Il risultato deve essere `mesh-server-ok`.
5. Salva verifica proxy e output HTTP in
   `~/course-alt/19/linkerd/verification.txt`.

---

### Q20 – Verifica finale

Completa la verifica integrata e scrivi
`~/course-alt/20/final/report.md`.

Il report deve dimostrare:

1. Argo CD `portal-client` e `portal-client-staging` sincronizzati sui branch
   corretti.
2. Flux `flux-platform` in stato `Ready=True`.
3. Gatekeeper nega un Deployment senza label `owner` in `security-alt`.
4. Kyverno nega un Pod senza `runAsNonRoot: true`.
5. `telemetry-api` usa `jaeger-collector.obs-alt:4317`.
6. La query Loki della Q12 restituisce log `ERROR`.
7. I Pod in `mesh-alt` hanno il proxy Linkerd e comunicano correttamente.

Per ogni punto includi comando, risultato e rollback.
