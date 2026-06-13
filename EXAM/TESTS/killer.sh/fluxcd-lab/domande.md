# Flux CD Lab - Git and standalone tools

Ogni domanda è una prova autonoma. Gli esercizi Q1-Q10 attestano il repository
Gitea `__GIT_REPO_URL__`, che contiene file YAML e overlay Kustomize. Gli
esercizi Q11-Q20 attestano repository Helm ufficiali e installano tool
standalone tramite `HelmRelease`.

Repository Helm utilizzati:

- Headlamp: `https://kubernetes-sigs.github.io/headlamp/`;
- Metrics Server: `https://kubernetes-sigs.github.io/metrics-server/`;
- Prometheus Community: `https://prometheus-community.github.io/helm-charts`.

Le soluzioni sono raccolte alla fine del documento.

---

### Q1 - Attestare il repository Gitea

Percorso: `~/course-fluxcd/01`.

Correggi `source.yaml` usando `__GIT_REPO_URL__`, branch `main` e interval
`1m`. Forza la riconciliazione e verifica `Ready=True`, artifact e revision.

---

### Q2 - Applicare manifest YAML dal repository

Percorso: `~/course-fluxcd/02`.

Completa la Kustomization con path `./apps/catalog`, `prune: true`,
`wait: true` e timeout `2m`. Distribuisci Deployment e Service nel Namespace
`flux-apps` e verifica l'inventory.

---

### Q3 - Aggiungere metadata comuni

Percorso: `~/course-fluxcd/03`.

Mantieni l'overlay dev e configura `commonMetadata` affinché tutte le risorse
abbiano label `managed-by=flux` e annotation
`platform.example.com/source=gitea`. Verifica il Deployment `dev-web`.

---

### Q4 - Selezionare l'overlay production

Percorso: `~/course-fluxcd/04`.

Correggi il path usando `./apps/web/overlays/prod`. Verifica Namespace
`flux-prod`, Deployment `prod-web`, tre repliche e label
`environment=prod`.

---

### Q5 - Sostituzione da ConfigMap

Percorso: `~/course-fluxcd/05`.

Completa `postBuild.substituteFrom` usando ConfigMap `q05-values`. Verifica
nel ConfigMap `runtime-settings` i valori `configured-by-flux` e
`platform-team`.

---

### Q6 - Dipendenza infrastruttura-applicazione

Percorso: `~/course-fluxcd/06`.

Configura `q06-application` affinché dipenda da `q06-namespaces`. Applica la
Source e le due Kustomization e dimostra che i Namespace vengono attestati
prima dell'applicazione production.

---

### Q7 - Health check del workload

Percorso: `~/course-fluxcd/07`.

Abilita `wait`, timeout `2m` e health check sul Deployment `catalog` nel
Namespace `flux-apps`. Verifica `Ready=True` soltanto dopo la disponibilità
del Deployment.

---

### Q8 - Suspend e resume Kustomization

Percorso: `~/course-fluxcd/08`.

Applica le risorse sospese, verifica l'assenza del workload, imposta
`suspend: false`, forza il reconcile e verifica Deployment e Service.

---

### Q9 - Correzione del drift Git

Percorso: `~/course-fluxcd/09`.

Applica l'overlay dev, porta manualmente `dev-web` a cinque repliche e forza
una riconciliazione. Verifica il ritorno a una replica e salva condizioni,
inventory ed eventi in `evidence.txt`.

---

### Q10 - Scenario Git/Kustomize completo

Percorso: `~/course-fluxcd/10`.

Configura la dipendenza da `q10-infrastructure`, abilita `prune` e `wait`,
quindi attesta l'overlay production. Elimina il Service gestito, forza il
reconcile e verifica che venga ricreato.

---

### Q11 - Attestare il repository Helm Headlamp

Percorso: `~/course-fluxcd/11`.

Correggi l'URL del `HelmRepository` usando
`https://kubernetes-sigs.github.io/headlamp/`, imposta interval `5m` e
verifica artifact e revision.

---

### Q12 - Installare Headlamp

Percorso: `~/course-fluxcd/12`.

Completa il HelmRelease usando chart `headlamp`, versione `0.42.x` e
`install.createNamespace: true`. Verifica release, Deployment e Service nel
Namespace `headlamp`.

---

### Q13 - Headlamp con valuesFrom

Percorso: `~/course-fluxcd/13`.

Collega ConfigMap `q13-headlamp-values`, key `values.yaml`. Verifica due
repliche, Service `ClusterIP` sulla porta 8080, base URL `/headlamp` e assenza
del ClusterRoleBinding creato dal chart.

---

### Q14 - Metrics Server per cluster lab

Percorso: `~/course-fluxcd/14`.

Configura `install.createNamespace: true`, due repliche e argomento
`--kubelet-insecure-tls`. Verifica HelmRelease e Deployment nel Namespace
`metrics-server`.

---

### Q15 - Metrics Server: metriche e risorse

Percorso: `~/course-fluxcd/15`.

Abilita `metrics.enabled`, aggiungi al Service la label
`app.kubernetes.io/part-of=platform-observability` e configura request CPU
`100m`, memoria `200Mi`. Verifica i valori nel Deployment e nel Service.

---

### Q16 - kube-state-metrics

Percorso: `~/course-fluxcd/16`.

Configura `install.createNamespace: true`, due repliche e
`customLabels.team=platform`. Verifica release e Deployment nel Namespace
`monitoring`.

---

### Q17 - Risorse kube-state-metrics

Percorso: `~/course-fluxcd/17`.

Imposta request CPU `50m`, memoria `64Mi`, limit CPU `200m`, memoria `256Mi`.
Mantieni Service `ClusterIP` sulla porta 8080 e `selfMonitor.enabled: false`.

---

### Q18 - Remediation e drift Headlamp

Percorso: `~/course-fluxcd/18`.

Configura tre retry per install e upgrade, rollback per gli upgrade falliti e
`driftDetection.mode: enabled`. Verifica la configurazione osservata e la
history della release.

---

### Q19 - Suspend, resume e drift Headlamp

Percorso: `~/course-fluxcd/19`.

Applica il HelmRelease sospeso, verifica l'assenza della release, riprendilo e
forza il reconcile. Porta manualmente il Deployment a cinque repliche e
verifica il ripristino a due repliche tramite drift detection.

---

### Q20 - Gitea production e Headlamp

Percorso: `~/course-fluxcd/20`.

1. Abilita `prune` e `wait` sulla Kustomization production.
2. Configura Headlamp con namespace automatico, due repliche,
   `clusterRoleBinding.create: false` e drift detection.
3. Applica Source, HelmRepository, Kustomization e HelmRelease.
4. Verifica tutte le risorse `Ready=True`.
5. Elimina il Service production e modifica le repliche Headlamp; forza le
   riconciliazioni e documenta il ripristino in `final-report.md`.

---

## Soluzioni

### Soluzione Q1 - Attestare il repository Gitea

```yaml
spec:
  interval: 1m
  url: __GIT_REPO_URL__
  ref:
    branch: main
```

---

### Soluzione Q2 - Applicare manifest YAML dal repository

```yaml
path: ./apps/catalog
targetNamespace: flux-apps
prune: true
wait: true
timeout: 2m
```

---

### Soluzione Q3 - Aggiungere metadata comuni

```yaml
commonMetadata:
  labels:
    managed-by: flux
  annotations:
    platform.example.com/source: gitea
```

---

### Soluzione Q4 - Selezionare l'overlay production

```yaml
path: ./apps/web/overlays/prod
```

---

### Soluzione Q5 - Sostituzione da ConfigMap

```yaml
postBuild:
  substituteFrom:
    - kind: ConfigMap
      name: q05-values
```

---

### Soluzione Q6 - Dipendenza infrastruttura-applicazione

```yaml
dependsOn:
  - name: q06-namespaces
```

---

### Soluzione Q7 - Health check del workload

```yaml
wait: true
timeout: 2m
healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: catalog
    namespace: flux-apps
```

---

### Soluzione Q8 - Suspend e resume Kustomization

Imposta `suspend: false`, applica il manifest e forza il reconcile con
`reconcile.fluxcd.io/requestedAt`.

---

### Soluzione Q9 - Correzione del drift Git

```bash
kubectl -n flux-dev scale deployment/dev-web --replicas=5
kubectl annotate -n flux-system kustomization/q09-drift \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

---

### Soluzione Q10 - Scenario Git/Kustomize completo

```yaml
dependsOn:
  - name: q10-infrastructure
prune: true
wait: true
```

---

### Soluzione Q11 - Attestare il repository Helm Headlamp

```yaml
spec:
  interval: 5m
  url: https://kubernetes-sigs.github.io/headlamp/
```

---

### Soluzione Q12 - Installare Headlamp

```yaml
chart:
  spec:
    chart: headlamp
    version: "0.42.x"
    sourceRef:
      kind: HelmRepository
      name: q12-headlamp
install:
  createNamespace: true
```

---

### Soluzione Q13 - Headlamp con valuesFrom

```yaml
valuesFrom:
  - kind: ConfigMap
    name: q13-headlamp-values
    valuesKey: values.yaml
```

---

### Soluzione Q14 - Metrics Server per cluster lab

```yaml
install:
  createNamespace: true
values:
  replicas: 2
  args:
    - --kubelet-insecure-tls
```

---

### Soluzione Q15 - Metrics Server: metriche e risorse

```yaml
values:
  metrics:
    enabled: true
  service:
    type: ClusterIP
    labels:
      app.kubernetes.io/part-of: platform-observability
  resources:
    requests:
      cpu: 100m
      memory: 200Mi
```

---

### Soluzione Q16 - kube-state-metrics

```yaml
install:
  createNamespace: true
values:
  replicas: 2
  customLabels:
    team: platform
```

---

### Soluzione Q17 - Risorse kube-state-metrics

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

---

### Soluzione Q18 - Remediation e drift Headlamp

```yaml
install:
  createNamespace: true
  remediation:
    retries: 3
upgrade:
  remediation:
    retries: 3
    strategy: rollback
driftDetection:
  mode: enabled
```

---

### Soluzione Q19 - Suspend, resume e drift Headlamp

Imposta `suspend: false`, applica e forza il reconcile. Dopo il drift:

```bash
kubectl annotate -n flux-system helmrelease/q19-headlamp \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

---

### Soluzione Q20 - Gitea production e Headlamp

Kustomization:

```yaml
prune: true
wait: true
```

HelmRelease:

```yaml
install:
  createNamespace: true
values:
  replicaCount: 2
  clusterRoleBinding:
    create: false
driftDetection:
  mode: enabled
```
