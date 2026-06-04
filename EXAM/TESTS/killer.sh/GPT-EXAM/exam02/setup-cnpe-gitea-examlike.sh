#!/usr/bin/env bash
# ============================================================
# CNPE Exam-like Lab 2 — Minikube + external Gitea
# ============================================================
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-gitea}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-12000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
GITEA_USER="${GITEA_USER:-cnpe-user}"
GITEA_PASS="${GITEA_PASS:-cnpe-pass}"
GITEA_ORG="${GITEA_ORG:-organization}"
BASE_DIR="${BASE_DIR:-$HOME/course/cnpe-gitea-lab}"
REPO_ROOT="$BASE_DIR/repos-src"
WORK_ROOT="$BASE_DIR/work"
QUESTIONS_DIR="$BASE_DIR/questions"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info(){ echo -e "${CYAN}[INFO]${NC} $*"; }
success(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[ERR]${NC} $*"; exit 1; }
section(){ echo -e "\n${BOLD}${GREEN}== $* ==${NC}\n"; }
have(){ command -v "$1" >/dev/null 2>&1; }
repo_url(){ echo "${GITEA_URL%/}/${GITEA_ORG}/$1.git"; }
api(){ local m="$1" p="$2" d="${3:-}"; if [[ -n "$d" ]]; then curl -fsS -X "$m" -H "Authorization: token ${GITEA_TOKEN}" -H 'Content-Type: application/json' -d "$d" "${GITEA_URL%/}/api/v1${p}"; else curl -fsS -X "$m" -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1${p}"; fi; }
ensure_repo(){ local n="$1"; api GET "/repos/${GITEA_ORG}/${n}" >/dev/null 2>&1 || api POST "/orgs/${GITEA_ORG}/repos" "{\"name\":\"${n}\",\"private\":false,\"auto_init\":false}" >/dev/null; }
push_repo(){ local n="$1" d="$2"; rm -rf "$WORK_ROOT/$n"; cp -a "$d" "$WORK_ROOT/$n"; cd "$WORK_ROOT/$n"; git init -b main >/dev/null; git config user.name 'CNPE User'; git config user.email cnpe-user@example.local; git add .; git commit -m 'initial broken exam state' >/dev/null; git remote add origin "$(repo_url "$n")"; git push -u origin main --force >/dev/null; cd - >/dev/null; }
cleanup(){ section Cleanup; kubectl delete ns argocd tekton-pipelines prometheus flagger-system platform-dev platform-prod lagoon lagoon-testing kariba malawi builder security-lab pacific --ignore-not-found --timeout=90s || true; kubectl delete crd teammonitorings.monitoring.cnpe.local --ignore-not-found || true; rm -rf "$BASE_DIR"; success 'Cleanup locale completato'; }
[[ "${1:-}" == "--cleanup" ]] && cleanup && exit 0

section "0. Prerequisiti"
for c in kubectl helm minikube git curl; do have "$c" || die "$c non trovato"; done
mkdir -p "$REPO_ROOT" "$WORK_ROOT" "$QUESTIONS_DIR" "$BASE_DIR/answers"

section "1. Minikube"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then minikube start -p "$PROFILE" --driver="$DRIVER" --cpus="$CPUS" --memory="${MEMORY}mb" --disk-size=50g --kubernetes-version="$K8S_VERSION" --force; fi
export KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE")"
kubectl cluster-info >/dev/null

section "2. Gitea"
api GET /version >/dev/null || die "Gitea non raggiungibile: $GITEA_URL"
api GET "/orgs/${GITEA_ORG}" >/dev/null || die "Org ${GITEA_ORG} non trovata/token non autorizzato"
for r in team-monitoring web-client platform-apps pipeline-tasks policy-manifests; do ensure_repo "$r"; done

section "3. Repo sorgenti"
mkdir -p "$REPO_ROOT/team-monitoring"
cat > "$REPO_ROOT/team-monitoring/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [crd.yaml]
YAML
cat > "$REPO_ROOT/team-monitoring/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: teammonitorings.monitoring.cnpe.local
spec:
  group: monitoring.cnpe.local
  scope: Namespaced
  names:
    kind: TeamMonitoring
    plural: teammonitorings
    singular: teammonitoring
    shortNames: [tmon]
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          apiVersion: {type: string}
          kind: {type: string}
          metadata: {type: object}
          spec:
            type: object
            properties:
              target:
                type: string
          status: {type: object}
YAML
cat > "$REPO_ROOT/team-monitoring/README.md" <<'TXT'
Repo esame: CRD TeamMonitoring da estendere a v1alpha2.
TXT

mkdir -p "$REPO_ROOT/web-client/manifests"
cat > "$REPO_ROOT/web-client/manifests/web-client.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-client
  namespace: lagoon
data:
  nginx.conf: |
    events {}
    http { server { listen 80; location / { return 200 'Lagoon Web Client v1'; } } }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-client
  namespace: lagoon
spec:
  replicas: 1
  selector:
    matchLabels: {app: web-client}
  template:
    metadata:
      labels: {app: web-client, version: v1}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        volumeMounts:
        - name: conf
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: conf
        configMap: {name: web-client}
---
apiVersion: v1
kind: Service
metadata:
  name: web-client
  namespace: lagoon
spec:
  selector: {app: web-client}
  ports: [{port: 80, targetPort: 80}]
YAML
cat > "$REPO_ROOT/web-client/manifests/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [web-client.yaml]
YAML

mkdir -p "$REPO_ROOT/platform-apps/apps/api" "$REPO_ROOT/platform-apps/apps/worker" "$REPO_ROOT/platform-apps/argocd"
cat > "$REPO_ROOT/platform-apps/apps/api/app.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: platform-dev
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api, team: platform}}
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: platform-dev
spec:
  selector: {app: api}
  ports: [{port: 80, targetPort: 80}]
YAML
cat > "$REPO_ROOT/platform-apps/apps/api/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [app.yaml]
YAML
cat > "$REPO_ROOT/platform-apps/apps/worker/app.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: platform-dev
spec:
  replicas: 1
  selector: {matchLabels: {app: worker}}
  template:
    metadata: {labels: {app: worker, team: platform}}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh","-c","sleep 3600"]
YAML
cat > "$REPO_ROOT/platform-apps/apps/worker/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [app.yaml]
YAML
cat > "$REPO_ROOT/platform-apps/argocd/appset.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: $(repo_url platform-apps)
      revision: main
      directories:
      - path: apps/*
  template:
    metadata:
      name: '{{path.basename}}-dev'
    spec:
      project: default
      source:
        repoURL: $(repo_url platform-apps)
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: platform-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
YAML

mkdir -p "$REPO_ROOT/pipeline-tasks/p1-team-onboarding" "$REPO_ROOT/pipeline-tasks/p2-team-scanner"
cat > "$REPO_ROOT/pipeline-tasks/p1-team-onboarding/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p1-create-namespace
  namespace: builder
spec:
  params: [{name: team-name}]
  steps:
  - name: create
    image: bitnami/kubectl:latest
    script: |
      kubectl create ns $(params.team-name) --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p1-create-roles
  namespace: builder
spec:
  params: [{name: team-name}]
  steps:
  - name: role
    image: bitnami/kubectl:latest
    script: |
      kubectl -n $(params.team-name) create role viewer --verb=get,list,watch --resource=pods --dry-run=client -o yaml | kubectl apply -f -
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: p1-team-onboarding
  namespace: builder
spec:
  params: [{name: team-name}]
  tasks:
  - name: p1-create-namespace
    taskRef: {name: p1-create-namespace}
    params: [{name: team-name, value: $(params.team-name)}]
  - name: p1-create-roles
    runAfter: [p1-create-namespace]
    taskRef: {name: p1-create-roles}
    params: [{name: team-name, value: $(params.team-name)}]
YAML
cat > "$REPO_ROOT/pipeline-tasks/p2-team-scanner/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: p2-scan-namespace
  namespace: builder
spec:
  params:
  - {name: target_namespace}
  - {name: forbidden1}
  - {name: forbidden2}
  steps:
  - name: scan
    image: bitnami/kubectl:latest
    script: |
      echo "Scanning namespace $(params.target_namespace)"
      kubectl -n $(params.target_namespace) get pods -o wide || true
      echo "Forbidden: $(params.forbidden1), $(params.forbidden2)"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: p2-team-scanner
  namespace: builder
spec:
  params:
  - {name: target_namespace}
  - {name: forbidden1}
  - {name: forbidden2}
  tasks:
  - name: scan
    taskRef: {name: p2-scan-namespace}
    params:
    - {name: target_namespace, value: $(params.target_namespace)}
    - {name: forbidden1, value: $(params.forbidden1)}
    - {name: forbidden2, value: $(params.forbidden2)}
YAML

mkdir -p "$REPO_ROOT/policy-manifests"
cat > "$REPO_ROOT/policy-manifests/namespace.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: security-lab
YAML
cat > "$REPO_ROOT/policy-manifests/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: security-lab
  labels: {app: payment-api}
spec:
  replicas: 1
  selector: {matchLabels: {app: payment-api}}
  template:
    metadata: {labels: {app: payment-api}}
    spec:
      containers:
      - name: api
        image: nginx
        ports: [{containerPort: 80}]
YAML
cat > "$REPO_ROOT/policy-manifests/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
- deployment.yaml
YAML

for r in team-monitoring web-client platform-apps pipeline-tasks policy-manifests; do push_repo "$r" "$REPO_ROOT/$r"; done
success "Repo Gitea creati e popolati"

section "4. Namespace"
for ns in pacific lagoon lagoon-testing platform-dev platform-prod kariba malawi builder; do kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -; done

section "5. Argo CD"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait --timeout=8m --set server.service.type=NodePort --set server.service.nodePortHttp=30030 || warn "Argo CD non completamente Ready"
cat > "$BASE_DIR/web-client-app.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-client
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(repo_url web-client)
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: lagoon
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML
kubectl apply -f "$BASE_DIR/web-client-app.yaml"
kubectl apply -f "$WORK_ROOT/platform-apps/argocd/appset.yaml" || true

section "6. Prometheus minimale"
cat > "$BASE_DIR/prometheus.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata: {name: prometheus}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server
  namespace: prometheus
data:
  prometheus.yml: |
    global:
      scrape_interval: 10s
      evaluation_interval: 10s
    scrape_configs:
    - job_name: 'minimal'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['kariba']
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        regex: (frontend|backend)
        action: keep
      - source_labels: [__meta_kubernetes_pod_ip]
        target_label: __address__
        replacement: ${1}:8080
      - target_label: __metrics_path__
        replacement: /metrics
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-server
  namespace: prometheus
spec:
  replicas: 1
  selector: {matchLabels: {app: prometheus-server}}
  template:
    metadata: {labels: {app: prometheus-server}}
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.55.1
        args: ["--config.file=/etc/prometheus/prometheus.yml", "--web.enable-lifecycle"]
        ports: [{containerPort: 9090}]
        volumeMounts:
        - {name: config, mountPath: /etc/prometheus}
      volumes:
      - name: config
        configMap: {name: prometheus-server}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-server
  namespace: prometheus
spec:
  type: NodePort
  selector: {app: prometheus-server}
  ports: [{port: 9090, targetPort: 9090, nodePort: 30020}]
YAML
kubectl apply -f "$BASE_DIR/prometheus.yaml"
cat > "$BASE_DIR/kariba-apps.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend, namespace: kariba}
spec:
  replicas: 1
  selector: {matchLabels: {app: frontend}}
  template:
    metadata: {labels: {app: frontend, deployment: frontend}}
    spec:
      containers:
      - name: metrics
        image: python:3.12-alpine
        command: ["sh","-c"]
        args: ["cat > /tmp/s.py <<'PY'\nfrom http.server import BaseHTTPRequestHandler,HTTPServer\nclass H(BaseHTTPRequestHandler):\n def do_GET(self):\n  self.send_response(200); self.end_headers(); self.wfile.write(b'http_requests_per_minute{deployment=\"frontend\"} 18\n')\nHTTPServer(('0.0.0.0',8080),H).serve_forever()\nPY\npython /tmp/s.py"]
        ports: [{containerPort: 8080}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: backend, namespace: kariba}
spec:
  replicas: 1
  selector: {matchLabels: {app: backend}}
  template:
    metadata: {labels: {app: backend, deployment: backend}}
    spec:
      containers:
      - name: metrics
        image: python:3.12-alpine
        command: ["sh","-c"]
        args: ["cat > /tmp/s.py <<'PY'\nfrom http.server import BaseHTTPRequestHandler,HTTPServer\nclass H(BaseHTTPRequestHandler):\n def do_GET(self):\n  self.send_response(200); self.end_headers(); self.wfile.write(b'http_requests_per_minute{deployment=\"backend\"} 55\n')\nHTTPServer(('0.0.0.0',8080),H).serve_forever()\nPY\npython /tmp/s.py"]
        ports: [{containerPort: 8080}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: proxy, namespace: kariba}
spec:
  replicas: 1
  selector: {matchLabels: {app: proxy}}
  template:
    metadata: {labels: {app: proxy, deployment: proxy}}
    spec:
      containers:
      - name: metrics
        image: python:3.12-alpine
        command: ["sh","-c"]
        args: ["cat > /tmp/s.py <<'PY'\nfrom http.server import BaseHTTPRequestHandler,HTTPServer\nclass H(BaseHTTPRequestHandler):\n def do_GET(self):\n  self.send_response(200); self.end_headers(); self.wfile.write(b'http_requests_per_minute{deployment=\"proxy\"} 9\n')\nHTTPServer(('0.0.0.0',8080),H).serve_forever()\nPY\npython /tmp/s.py"]
        ports: [{containerPort: 8080}]
YAML
kubectl apply -f "$BASE_DIR/kariba-apps.yaml"

section "7. Flagger"
helm repo add flagger https://flagger.app >/dev/null 2>&1 || true
helm upgrade --install flagger flagger/flagger -n flagger-system --create-namespace --wait --timeout=5m --set meshProvider=kubernetes || warn "Flagger install non completata"
cat > "$BASE_DIR/flagger-apps.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: malawi
  labels: {app: app1}
spec:
  replicas: 1
  selector: {matchLabels: {app: app1}}
  template:
    metadata: {labels: {app: app1}}
    spec:
      containers:
      - name: httpd
        image: httpd:2-alpine
        env: [{name: APP_VERSION, value: "2.4.8"}]
        command: ["/bin/sh","-c"]
        args: ['echo "app1 version ${APP_VERSION}" > /usr/local/apache2/htdocs/index.html; httpd-foreground']
        ports: [{containerPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: malawi
  labels: {app: app2}
spec:
  replicas: 1
  selector: {matchLabels: {app: app2}}
  template:
    metadata: {labels: {app: app2}}
    spec:
      containers:
      - name: httpd
        image: httpd:2-alpine
        env: [{name: APP_VERSION, value: "1.0.0"}]
        command: ["/bin/sh","-c"]
        args: ['echo "app2 version ${APP_VERSION}" > /usr/local/apache2/htdocs/index.html; httpd-foreground']
        ports: [{containerPort: 80}]
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata: {name: app1, namespace: malawi}
spec:
  provider: kubernetes
  targetRef: {apiVersion: apps/v1, kind: Deployment, name: app1}
  service: {port: 80, targetPort: 80, portDiscovery: true}
  analysis: {interval: 5s, iterations: 2, threshold: 5, metrics: []}
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata: {name: app2, namespace: malawi}
spec:
  provider: kubernetes
  targetRef: {apiVersion: apps/v1, kind: Deployment, name: app2}
  service: {port: 80, targetPort: 80, portDiscovery: true}
  analysis: {interval: 5s, iterations: 2, threshold: 5, metrics: []}
YAML
kubectl apply -f "$BASE_DIR/flagger-apps.yaml" || true

section "8. Tekton"
helm repo add tektoncd https://cdfoundation.github.io/tekton-helm-chart >/dev/null 2>&1 || true
helm upgrade --install tekton-pipeline tektoncd/tekton-pipeline -n tekton-pipelines --create-namespace --wait --timeout=5m || warn "Tekton install non completata"
kubectl create rolebinding builder-admin --clusterrole=admin --serviceaccount=builder:default -n builder --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$WORK_ROOT/pipeline-tasks/p1-team-onboarding/pipeline.yaml" || true

section "9. Security lab"
kubectl apply -k "$WORK_ROOT/policy-manifests" || true

cat > "$QUESTIONS_DIR/domande-cnpe-gitea-examlike.md" <<QUESTIONS
# CNPE Exam-like Lab 2 — batteria domande

Setup: \`$BASE_DIR\`  
Gitea: \`$GITEA_URL\`  
Org: \`$GITEA_ORG\`  
Repo: team-monitoring, web-client, platform-apps, pipeline-tasks, policy-manifests.

Tempo consigliato: 120 minuti. Modifica il minimo necessario, verifica e salva output richiesti.

## Q1 — CRD, Kustomize, Git
Repo: \`$BASE_DIR/work/team-monitoring\`.
1. Aggiungi versione \`v1alpha2\` al CRD \`TeamMonitoring\`.
2. In \`v1alpha2\`, \`spec.target\` deve diventare object con stringhe \`namespace\` e \`service\`.
3. \`v1alpha1\` deve restare served ma non storage; \`v1alpha2\` deve essere storage.
4. Applica con \`kubectl apply -k .\` e committa su main.
5. Crea \`TeamMonitoring/general\` in namespace \`pacific\` con target \`test-ns/test-svc\`.

## Q2 — Argo CD GitOps update
Applicazione Argo CD: \`web-client\`. Repo: \`$BASE_DIR/work/web-client\`.
1. Porta la label pod \`version\` a \`v2\`.
2. Cambia la risposta Nginx in \`Lagoon Web Client v2\`.
3. Commit e push su main.
4. Sincronizza Argo CD e verifica pod e risposta HTTP.

## Q3 — Branch e nuova Argo Application
1. Nel repo \`web-client\`, crea branch \`testing\`.
2. Porta label \`version\` a \`v3\` e risposta a \`Lagoon Web Client v3\`.
3. Push del branch.
4. Crea Application \`web-client-testing\` in \`argocd\`, branch \`testing\`, path \`manifests\`, namespace destinazione \`lagoon-testing\`.
5. Verifica che \`web-client\` resti v2 in \`lagoon\` e testing sia v3 in \`lagoon-testing\`.

## Q4 — ApplicationSet troubleshooting
Repo: \`platform-apps\`. ApplicationSet: \`platform-apps\`.
1. Correggi la destinazione generata: le app devono andare in \`platform-dev\`, non \`platform-prod\`.
2. Commit e push.
3. Applica/aggiorna ApplicationSet.
4. Verifica che \`api-dev\` e \`worker-dev\` siano Synced/Healthy e che i pod siano in \`platform-dev\`.

## Q5 — Prometheus scrape config
Namespace: \`prometheus\`; workload metrics: \`kariba\`.
1. Estendi la ConfigMap \`prometheus-server\` affinché lo scrape job \`minimal\` includa anche pod \`app=proxy\`.
2. Fai reload/restart di Prometheus.
3. Esegui query PromQL: \`sum by (deployment) (http_requests_per_minute{})\`.
4. Scala a 2 repliche il Deployment con valore più alto.
5. Salva query e risultato in \`$BASE_DIR/answers/q5-prometheus.txt\`.

## Q6 — Flagger blue/green app1
Namespace: \`malawi\`.
1. Aumenta di 1 la patch version di \`APP_VERSION\` per \`deploy/app1\`.
2. Attendi promozione Flagger.
3. Salva gli eventi rilevanti della Canary in \`$BASE_DIR/answers/q6-app1-events.log\`.

## Q7 — Flagger pre-rollout webhook app2
1. Aggiorna \`canary/app2\` aggiungendo webhook \`pre-rollout\` che faccia HTTP GET su \`http://app2-canary.malawi\` e si aspetti 200.
2. Triggera rollout impostando \`APP_VERSION=1.0.1\`.
3. Verifica promozione e salva \`kubectl -n malawi describe canary app2\` in \`$BASE_DIR/answers/q7-app2.txt\`.

## Q8 — Tekton onboarding parallelo
Repo: \`pipeline-tasks\`, path \`p1-team-onboarding\`.
1. Aggiungi Task \`p1-create-labels\` che aggiunga label \`auto-created=true\` al namespace creato.
2. Deve partire dopo \`p1-create-namespace\` e in parallelo con \`p1-create-roles\`.
3. Applica e lancia PipelineRun per team \`butter\` e \`croissant\`.
4. Verifica namespace, label e role.

## Q9 — Tekton scanner
1. Applica risorse da \`p2-team-scanner\`.
2. Lancia Pipeline \`p2-team-scanner\` con \`target_namespace=kariba\`, \`forbidden1=miner\`, \`forbidden2=torrent\`.
3. Salva log in \`$BASE_DIR/answers/q9-p2.log\`.

## Q10 — Security hardening e immagine esplicita
Repo: \`policy-manifests\`.
1. Correggi immagine \`payment-api\`: non deve usare tag implicito latest.
2. Aggiungi securityContext pod/container con \`runAsNonRoot\`, \`allowPrivilegeEscalation=false\`, \`readOnlyRootFilesystem=true\` dove compatibile.
3. Applica con Kustomize, commit e push.
4. Verifica rollout.

## Q11 — NetworkPolicy minima
Namespace \`security-lab\`.
1. Crea NetworkPolicy che consenta ingress a \`payment-api\` solo da pod con label \`access=allowed\` sulla porta 80.
2. Salva il manifest in repo \`policy-manifests\` e committa.
3. Applica e verifica che la policy esista.

## Q12 — Report finale
Crea \`$BASE_DIR/answers/final-report.txt\` con:
1. output \`kubectl get applications -A\`
2. output \`kubectl -n kariba get deploy\`
3. output \`kubectl -n malawi get canary\`
4. output \`kubectl get teammonitoring -A\`
5. lista commit Git dei repo modificati.
QUESTIONS

cat > "$BASE_DIR/README.md" <<README
# CNPE Gitea Exam-like Lab 2

Avvio:
\`\`\`bash
chmod +x setup-cnpe-gitea-examlike.sh
./setup-cnpe-gitea-examlike.sh
\`\`\`

Domande: \`$QUESTIONS_DIR/domande-cnpe-gitea-examlike.md\`
Cleanup: \`./setup-cnpe-gitea-examlike.sh --cleanup\`
README

section "10. Stato finale"
echo "Domande: $QUESTIONS_DIR/domande-cnpe-gitea-examlike.md"
echo "Working copy repo: $WORK_ROOT"
echo "Answers: $BASE_DIR/answers"
echo "Argo CD: http://$(minikube ip -p "$PROFILE"):30030"
echo "Prometheus: http://$(minikube ip -p "$PROFILE"):30020"
success "Lab CNPE Gitea exam-like pronto"
