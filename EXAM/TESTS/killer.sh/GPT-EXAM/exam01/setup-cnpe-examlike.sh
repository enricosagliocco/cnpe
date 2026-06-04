#!/usr/bin/env bash
# =============================================================================
# CNPE Exam-like Lab 2026 — multi-domain performance simulator
#
# Targets CNPE-style domains:
# - Platform Architecture and Infrastructure
# - GitOps and Continuous Delivery
# - Platform APIs / Self-Service
# - Observability and Operations
# - Security and Policy Enforcement
#
# Usage:
#   chmod +x setup-cnpe-examlike.sh
#   ./setup-cnpe-examlike.sh
#   ./setup-cnpe-examlike.sh --cleanup
#
# Notes:
# - This is intentionally broken in several places.
# - Do not treat this as an answer key.
# - Main workspace: ~/course/cnpe-examlike
# =============================================================================
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-exam}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-12000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi

LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/cnpe-examlike}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info(){ echo -e "${CYAN}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERR]${NC} $*"; exit 1; }
section(){ echo -e "\n${BOLD}${GREEN}== $* ==${NC}\n"; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  section "Cleanup"
  kubectl delete ns team-a team-b platform-system policy-lab rollouts-lab observability-lab gitops-lab --ignore-not-found --timeout=90s 2>/dev/null || true
  kubectl delete clusterrole platform-viewer --ignore-not-found 2>/dev/null || true
  kubectl delete clusterrolebinding platform-viewer-binding --ignore-not-found 2>/dev/null || true
  kubectl delete constrainttemplate k8srequiredlabels k8sallowedrepos k8srequiredresources --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredLabels required-owner-costcenter --ignore-not-found 2>/dev/null || true
  kubectl delete K8sAllowedRepos allowed-image-repos --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredResources required-resources --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "Cleanup completato. Controller Helm lasciati installati."
}
[[ "${1:-}" == "--cleanup" ]] && cleanup && exit 0

section "0. Prerequisites"
have kubectl || die "kubectl non trovato"
have helm || die "helm non trovato"
have minikube || die "minikube non trovato"
mkdir -p "$LAB_DIR"/{manifests,gitops/apps,gitops/clusters/dev,platform-api,answers}

section "1. Minikube cluster"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=50g \
    --kubernetes-version="$K8S_VERSION" \
    --extra-config=kubelet.fail-swap-on=false \
    --force
fi
export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "${HOME}/.kube/config")"
kubectl cluster-info >/dev/null
minikube -p "$PROFILE" addons enable metrics-server >/dev/null || true
minikube -p "$PROFILE" addons enable ingress >/dev/null || true

section "2. Namespaces"
for ns in team-a team-b platform-system policy-lab rollouts-lab observability-lab gitops-lab; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

section "3. Platform architecture broken resources"
cat >"$LAB_DIR/manifests/platform-workloads.yaml" <<'YAML'
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: 512Mi
    limits.cpu: "500m"
    limits.memory: 512Mi
    pods: "4"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: team-a-defaults
  namespace: team-a
spec:
  limits:
  - type: Container
    defaultRequest:
      cpu: 300m
      memory: 300Mi
    default:
      cpu: 600m
      memory: 600Mi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: team-a
data:
  BACKEND_URL: "http://backend.team-a.svc.cluster.local:8080"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: team-a
  labels:
    app.kubernetes.io/name: backend
    owner: payments
    cost-center: cc100
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend
        owner: payments
        cost-center: cc100
    spec:
      containers:
      - name: api
        image: ghcr.io/nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 3
          periodSeconds: 5
        resources:
          requests:
            cpu: 200m
            memory: 128Mi
          limits:
            cpu: 400m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: team-a
spec:
  selector:
    app: backend-api
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: team-a
  labels:
    app: frontend
    owner: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        owner: web
    spec:
      containers:
      - name: web
        image: nginx:latest
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: frontend-config
              key: API_ENDPOINT
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: team-a
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: team-a
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    name: pg
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: team-a
  labels:
    app: postgres
    owner: data
    cost-center: cc100
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        owner: data
        cost-center: cc100
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: platform
        ports:
        - containerPort: 5432
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 200m
            memory: 512Mi
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: slow-retain
      resources:
        requests:
          storage: 1Gi
YAML
kubectl apply -f "$LAB_DIR/manifests/platform-workloads.yaml" 2>&1 | tee "$LAB_DIR/initial-apply-platform.log" || true

section "4. Security and policy with Gatekeeper"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --wait --timeout=300s \
  --set validatingWebhookConfiguration.timeoutSeconds=15 >/dev/null
kubectl -n gatekeeper-system wait --for=condition=Ready pod -l gatekeeper.sh/operation=webhook --timeout=300s

cat >"$LAB_DIR/manifests/gatekeeper-policy.yaml" <<'YAML'
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels
      violation[{"msg": msg}] {
        required := input.parameters.labels[_]
        not input.review.object.metadata.labels[required]
        msg := sprintf("missing required label %v", [required])
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: required-owner-costcenter
spec:
  enforcementAction: dryrun
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment", "StatefulSet"]
    namespaces: ["team-b"]
  parameters:
    labels: ["owner", "cost-center"]
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sallowedrepos
      violation[{"msg": msg}] {
        container := input.review.object.spec.template.spec.containers[_]
        not startswith(container.image, input.parameters.repos[_])
        msg := sprintf("container %v uses disallowed image repo %v", [container.name, container.image])
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-image-repos
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces: ["team-a"]
  parameters:
    repos:
    - "ghcr.io/"
YAML
kubectl apply -f "$LAB_DIR/manifests/gatekeeper-policy.yaml" 2>&1 | tee "$LAB_DIR/initial-apply-policy.log" || true

section "5. Argo Rollouts canary scenario"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts --create-namespace \
  --wait --timeout=300s >/dev/null
kubectl -n argo-rollouts wait --for=condition=Available deployment/argo-rollouts --timeout=300s || true

cat >"$LAB_DIR/manifests/rollout.yaml" <<'YAML'
---
apiVersion: v1
kind: Service
metadata:
  name: payments-active
  namespace: rollouts-lab
spec:
  selector:
    app: payments
    version: stable
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: payments-preview
  namespace: rollouts-lab
spec:
  selector:
    app: payments
    version: preview
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments
  namespace: rollouts-lab
spec:
  replicas: 2
  strategy:
    blueGreen:
      activeService: payments-active
      previewService: payments-preview
      autoPromotionEnabled: false
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
        version: v1
    spec:
      containers:
      - name: app
        image: ghcr.io/nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
YAML
kubectl apply -f "$LAB_DIR/manifests/rollout.yaml" 2>&1 | tee "$LAB_DIR/initial-apply-rollout.log" || true

section "6. GitOps-style local repo with broken kustomizations"
cat >"$LAB_DIR/gitops/apps/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: gitops-lab
  labels:
    app: catalog
    owner: platform
    cost-center: cc200
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
        owner: platform
        cost-center: cc200
    spec:
      containers:
      - name: catalog
        image: ghcr.io/nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
YAML
cat >"$LAB_DIR/gitops/apps/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: gitops-lab
spec:
  selector:
    app: catalog-api
  ports:
  - name: http
    port: 80
    targetPort: 8080
YAML
cat >"$LAB_DIR/gitops/apps/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- svc.yaml
commonLabels:
  managed-by: flux
YAML
cat >"$LAB_DIR/gitops/clusters/dev/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: gitops-lab
resources:
- ../../app
patches:
- target:
    kind: Deployment
    name: catalog
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
YAML

section "7. Platform API / self-service CRD"
cat >"$LAB_DIR/platform-api/platformapp-crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformapps.platform.example.com
spec:
  group: platform.example.com
  scope: Namespaced
  names:
    plural: platformapps
    singular: platformapp
    kind: PlatformApp
    shortNames:
    - papp
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        required: ["spec"]
        properties:
          spec:
            type: object
            required: ["image", "replicas", "port"]
            properties:
              image:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 3
              port:
                type: integer
                minimum: 1024
                maximum: 65535
              owner:
                type: string
YAML
cat >"$LAB_DIR/platform-api/bad-platformapp.yaml" <<'YAML'
apiVersion: platform.example.com/v1alpha1
kind: PlatformApp
metadata:
  name: checkout
  namespace: platform-system
spec:
  image: nginx
  replicas: 5
  port: 80
YAML
kubectl apply -f "$LAB_DIR/platform-api/platformapp-crd.yaml"
kubectl apply -f "$LAB_DIR/platform-api/bad-platformapp.yaml" 2>&1 | tee "$LAB_DIR/initial-platformapp-error.log" || true

section "8. RBAC broken access scenario"
cat >"$LAB_DIR/manifests/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-read
  namespace: team-a
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-read
  namespace: team-a
subjects:
- kind: ServiceAccount
  name: developer
  namespace: team-b
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-read
YAML
kubectl apply -f "$LAB_DIR/manifests/rbac.yaml"

section "9. Observability workload"
cat >"$LAB_DIR/manifests/observability.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: noisy-api
  namespace: observability-lab
  labels:
    app: noisy-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: noisy-api
  template:
    metadata:
      labels:
        app: noisy-api
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          i=0
          while true; do
            echo "level=error component=noisy-api msg=\"database timeout\" count=$i"
            i=$((i+1))
            sleep 5
          done
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
YAML
kubectl apply -f "$LAB_DIR/manifests/observability.yaml"

section "10. Exam files"
cat >"$LAB_DIR/domande-cnpe-examlike.md" <<'EOF_QUESTIONS'
# CNPE Exam-like — Batteria domande 2026

Durata consigliata: **120 minuti**.  
Workspace: `~/course/cnpe-examlike`.  
Salva prove e note in `~/course/cnpe-examlike/answers/`.

Questa batteria è volutamente meno guidata del lab Gatekeeper: simula domande pratiche distribuite sui domini CNPE.

---

## Q1 — Cluster orientation e triage iniziale

Contesto: il lab è già deployato, ma alcuni `kubectl apply` iniziali hanno fallito o prodotto risorse non funzionanti.

Task:

1. Verifica stato cluster, namespace e controller installati.
2. Crea `answers/00-triage.txt` con:
   - version Kubernetes
   - namespace principali
   - workload non Ready
   - almeno 3 cause probabili trovate da `events`, `describe` o log iniziali.
3. Non correggere ancora nulla.

---

## Q2 — Platform architecture: ResourceQuota / LimitRange

Namespace: `team-a`.

Il namespace ha quota stretta e un LimitRange incoerente.

Task:

1. Identifica perché alcuni Pod potrebbero non essere schedulabili o ammessi.
2. Correggi quota o default del LimitRange con modifica minima.
3. Salva in `answers/01-quota-limits.txt`:
   - comando usato
   - prima/dopo di `kubectl -n team-a describe quota`
   - spiegazione in massimo 5 righe.

---

## Q3 — Backend service discovery

Namespace: `team-a`.

Il Service `backend` non raggiunge correttamente i Pod.

Task:

1. Correggi solo label/selector necessari.
2. Verifica che il Service abbia endpoint.
3. Salva in `answers/02-backend-endpoints.txt`:
   - `kubectl -n team-a get endpoints backend -o wide`
   - patch applicata.

---

## Q4 — Readiness probe rotta

Namespace: `team-a`, Deployment `backend`.

Task:

1. Trova perché i Pod backend non diventano Ready.
2. Correggi la readiness probe con patch minima.
3. Verifica rollout completo.
4. Salva evidenza in `answers/03-backend-ready.txt`.

---

## Q5 — ConfigMap contract tra frontend e backend

Namespace: `team-a`, Deployment `frontend`.

Il frontend non parte correttamente perché cerca una chiave ConfigMap non esistente.

Task:

1. Non ricreare il Deployment.
2. Correggi ConfigMap o riferimento env con modifica minima.
3. Verifica che i Pod frontend siano Running.
4. Salva `kubectl -n team-a describe pod -l app=frontend` in `answers/04-frontend-config.txt`.

---

## Q6 — Security policy: immagini ammesse

Gatekeeper blocca immagini non conformi nel namespace `team-a`.

Task:

1. Identifica quale Constraint blocca immagini fuori repo.
2. Porta `frontend` a un’immagine ammessa e con tag esplicito.
3. Mantieni il container funzionante su porta 80 oppure adatta coerentemente Service/container.
4. Salva in `answers/05-image-policy.txt`:
   - Constraint coinvolta
   - patch immagine
   - stato finale Pod.

---

## Q7 — Gatekeeper: enforcement sbagliato e namespace sbagliato

Il controllo label `owner` e `cost-center` non sta proteggendo `team-a`.

Task:

1. Correggi `K8sRequiredLabels required-owner-costcenter`.
2. Deve essere `deny`, non `dryrun`.
3. Deve matchare `team-a`.
4. Applica label mancanti ai workload esistenti solo se necessario.
5. Salva `kubectl describe` della Constraint in `answers/06-required-labels.txt`.

---

## Q8 — Negative test admission

Task:

1. Crea un manifest temporaneo di Deployment non conforme in `team-a` senza `cost-center`.
2. L’apply deve essere negato da Gatekeeper.
3. Salva messaggio di errore in `answers/07-admission-denied.txt`.
4. Cancella eventuali risorse di test residue.

---

## Q9 — StatefulSet e PVC Pending

Namespace: `team-a`, StatefulSet `postgres`.

Task:

1. Trova perché il PVC resta Pending.
2. Correggi senza cancellare il namespace.
3. Porta `postgres-0` Running.
4. Salva in `answers/08-postgres-storage.txt`:
   - pvc prima/dopo
   - storageClass disponibile scelta
   - eventuale comando di delete/recreate giustificato.

Nota: se devi modificare `volumeClaimTemplates`, spiega perché Kubernetes non lo aggiorna in-place.

---

## Q10 — RBAC least privilege

Namespace: `team-a`, ServiceAccount `developer`.

Task:

1. Verifica se `system:serviceaccount:team-a:developer` può listare Pod in `team-a`.
2. Correggi il RoleBinding rotto.
3. Non dare privilegi cluster-wide.
4. Salva:
   - `kubectl auth can-i list pods -n team-a --as=system:serviceaccount:team-a:developer`
   - YAML finale RoleBinding
   in `answers/09-rbac.txt`.

---

## Q11 — GitOps local rendering con Kustomize

Directory: `~/course/cnpe-examlike/gitops`.

Task:

1. Esegui build della kustomization cluster dev.
2. Correggi path e resource errati.
3. Applica il risultato al cluster.
4. Correggi il Service `catalog` affinché abbia endpoint.
5. Salva output di:
   - `kubectl kustomize ~/course/cnpe-examlike/gitops/clusters/dev`
   - `kubectl -n gitops-lab get deploy,svc,endpoints`
   in `answers/10-gitops-kustomize.txt`.

---

## Q12 — Continuous Delivery: Argo Rollouts Blue/Green

Namespace: `rollouts-lab`, Rollout `payments`.

Task:

1. Verifica stato del Rollout.
2. Spiega perché i Service active/preview non selezionano correttamente i Pod.
3. Correggi selettori o labels senza trasformare strategia.
4. Esegui update immagine a una patch version compatibile.
5. Promuovi il rollout manualmente solo dopo aver verificato preview.
6. Salva in `answers/11-rollout-bluegreen.txt`:
   - stato prima/dopo
   - service endpoints
   - comando di promote usato.

---

## Q13 — Platform API / self-service CRD

Directory: `~/course/cnpe-examlike/platform-api`.

Task:

1. Verifica schema del CRD `PlatformApp`.
2. Correggi `bad-platformapp.yaml` senza cambiare il CRD.
3. La risorsa `PlatformApp checkout` deve essere accettata.
4. Salva in `answers/12-platform-api.txt`:
   - errore iniziale
   - manifest corretto
   - `kubectl -n platform-system get papp checkout -o yaml`.

---

## Q14 — Developer self-service manifest generation

Usando la risorsa `PlatformApp checkout`, genera manualmente un Deployment e un Service equivalenti in `platform-system`.

Requisiti:

1. Nome workload: `checkout`.
2. Repliche uguali a `spec.replicas`.
3. Immagine uguale a `spec.image`.
4. Porta container e Service uguale a `spec.port`.
5. Label obbligatorie: `app=checkout`, `owner=<spec.owner>`, `managed-by=self-service`.
6. Salva i manifest in `answers/13-checkout-generated.yaml`.
7. Applica e verifica endpoints.

---

## Q15 — Observability: logs e incident note

Namespace: `observability-lab`.

Task:

1. Trova il workload che produce errori applicativi.
2. Salva le ultime 20 righe log in `answers/14-noisy-api-logs.txt`.
3. Scala temporaneamente a 0 repliche per mitigare l’incidente.
4. Scrivi `answers/14-incident-note.txt` con:
   - sintomo
   - impatto
   - mitigazione
   - follow-up.

---

## Q16 — Observability: resource usage

Task:

1. Verifica se `metrics-server` è operativo.
2. Raccogli `kubectl top nodes` e `kubectl top pods -A`.
3. Salva in `answers/15-resource-usage.txt`.
4. Se metrics non sono disponibili, scrivi troubleshooting realistico basato su `kubectl -n kube-system logs` o `describe`.

---

## Q17 — Policy audit zero-drift

Task:

1. Leggi lo status delle Constraint Gatekeeper.
2. Verifica `totalViolations` o campi equivalenti.
3. Correggi eventuali violazioni residue nei workload target.
4. Salva report in `answers/16-policy-audit.txt`.

---

## Q18 — Production hardening rapido

Namespace: `team-a`.

Task:

1. Assicurati che `frontend`, `backend`, `postgres` abbiano:
   - requests e limits
   - label `owner` e `cost-center`
   - immagini con tag esplicito
2. Non superare la ResourceQuota.
3. Salva patch e stato finale in `answers/17-hardening.txt`.

---

## Q19 — End-to-end service test

Task:

1. Crea un Pod temporaneo `curl` o `busybox` in `team-a`.
2. Verifica DNS e reachability verso:
   - `backend.team-a.svc.cluster.local`
   - `frontend.team-a.svc.cluster.local`
   - `postgres.team-a.svc.cluster.local:5432` almeno come connessione TCP se disponibile.
3. Salva output in `answers/18-e2e-network.txt`.
4. Rimuovi il Pod temporaneo.

---

## Q20 — Final exam report

Crea `answers/final-report.txt` con:

1. Stato finale di tutti i namespace lab.
2. Lista delle correzioni applicate, ordinate per dominio CNPE:
   - Platform Architecture and Infrastructure
   - GitOps and Continuous Delivery
   - Platform APIs and Self-Service
   - Observability and Operations
   - Security and Policy Enforcement
3. Comandi finali:
   - `kubectl get pods -A`
   - `kubectl get deploy,sts,svc,pvc -A`
   - `kubectl get constrainttemplate,constraint`
   - `kubectl get rollout -n rollouts-lab`
4. Eventuali problemi rimasti e perché.

---

EOF_QUESTIONS

cat >"$LAB_DIR/README.md" <<'EOF'
# CNPE Exam-like Lab

Workspace: `~/course/cnpe-examlike`

Use `domande-cnpe-examlike.md` as the task list.

Suggested timer: 120 minutes.

Rules:
- Prefer minimal patches.
- Save requested evidence files under `~/course/cnpe-examlike/answers/`.
- Do not delete and recreate workloads unless the task explicitly allows it.
- Use `kubectl`, `helm`, `kustomize`, logs/events/describe/jsonpath.
EOF

ok "Lab pronto: $LAB_DIR"
warn "Apri la batteria domande: $LAB_DIR/domande-cnpe-examlike.md"
warn "Alcuni apply sono falliti apposta: controlla initial-*.log"
