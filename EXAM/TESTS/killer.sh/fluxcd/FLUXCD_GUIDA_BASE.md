# FluxCD guida base con Gitea

Questa guida mostra un flusso completo e minimale per:

- installare FluxCD con Helm
- creare in modo scriptato due repository su Gitea
- fare deploy di base da Git con Kustomization
- fare deploy Helm da un chart versionato su Gitea
- creare gli oggetti Flux necessari

Scenario usato:

- Kubernetes: Minikube o cluster equivalente
- Gitea: http://192.168.1.56:3000
- Organization Gitea: organization
- Namespace Flux: flux-system

## 1. Prerequisiti

Comandi richiesti:

- kubectl
- helm
- git
- curl
- yq (opzionale)

Variabili ambiente consigliate:

~~~bash
export GITEA_URL="http://192.168.1.56:3000"
export GITEA_ORG="organization"
export GITEA_TOKEN="d2fcd54b7a8e2762920d929bfd4456db208659e4"
export GITEA_USER="cnpe-user"
export LAB_DIR="$HOME/course/flux-guide"
mkdir -p "$LAB_DIR"
~~~

Verifica cluster:

~~~bash
kubectl cluster-info
~~~

### 1.1 Minikube — installazione e avvio

Se non hai un cluster Kubernetes, Minikube è una scelta comoda per laboratorio. Qui i comandi più usati (Linux/macOS). Scegli un `--driver` disponibile sul tuo sistema (`docker`, `virtualbox`, `hyperkit`, `kvm2`, ecc.).

Imposta variabili utili:

~~~bash
MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-cnpe}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-8192} # MB
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-docker}
~~~

Installazione rapida (Linux):

~~~bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
~~~

Avvio idempotente del profilo Minikube (crea se mancante, altrimenti avvia):

~~~bash
if ! minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\s*\"${MINIKUBE_PROFILE}\""; then
  echo "Creating Minikube profile '${MINIKUBE_PROFILE}'"
  # ✅ Il flag va messo qui, alla creazione del cluster
  minikube start -p "${MINIKUBE_PROFILE}" \
    --driver="${MINIKUBE_DRIVER}" \
    --cpus="${MINIKUBE_CPUS}" \
    --memory="${MINIKUBE_MEMORY}" \
    --kubernetes-version=v1.35.0
else
  echo "Starting (or reusing) Minikube profile '${MINIKUBE_PROFILE}'"
  # Qui basta solo avviare, la versione è già stata decisa alla creazione
  minikube start -p "${MINIKUBE_PROFILE}" --driver="${MINIKUBE_DRIVER}"
fi

# Set kubeconfig to the profile
export KUBECONFIG=$(minikube kubeconfig --no-env -p "${MINIKUBE_PROFILE}" 2>/dev/null || echo ~/.kube/config)

# Enable useful addons
minikube -p "${MINIKUBE_PROFILE}" addons enable ingress 2>/dev/null || true
minikube -p "${MINIKUBE_PROFILE}" addons enable metrics-server 2>/dev/null || true

# Quick checks
minikube -p "${MINIKUBE_PROFILE}" status
minikube -p "${MINIKUBE_PROFILE}" ip
~~~

Se usi Windows (PowerShell) installa Minikube via choco o scarica il binario, poi usa gli stessi comandi con adattamenti alla shell.


## 2. Installazione FluxCD via Helm

Aggiungi repository chart e installa release Flux:

~~~bash
helm repo add fluxcd-community https://fluxcd-community.github.io/helm-charts
helm repo update

kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install flux2 fluxcd-community/flux2 \
  --namespace flux-system \
  --set imageAutomationController.create=true \
  --set imageReflectionController.create=true \
  --wait
~~~

Verifica controller:

~~~bash
kubectl -n flux-system get deploy
kubectl -n flux-system get pods
~~~

## 3. Script unico: crea repo Gitea + contenuti base + chart Helm

Crea il file script e rendilo eseguibile.

~~~bash
cat > "$LAB_DIR/setup-gitea-repos.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

: "${GITEA_URL:?missing GITEA_URL}"
: "${GITEA_ORG:?missing GITEA_ORG}"
: "${GITEA_TOKEN:?missing GITEA_TOKEN}"
: "${GITEA_USER:=cnpe-user}"
: "${LAB_DIR:=$HOME/course/flux-guide}"

GITEA_URL="${GITEA_URL%/}"
BASE_REPO="flux-base-app"
HELM_REPO="flux-helm-app"

api() {
  curl -sS -H "Authorization: token ${GITEA_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}

ensure_repo() {
  local repo="$1"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${repo}")

  if [ "$code" = "200" ]; then
    echo "[OK] Repo esiste: ${repo}"
    return 0
  fi

  api -X POST "${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos" \
    -d "{\"name\":\"${repo}\",\"private\":false,\"auto_init\":false}" >/dev/null
  echo "[OK] Repo creato: ${repo}"
}

push_repo() {
  local dir="$1"
  local repo="$2"
  local remote_url="http://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_URL#http://}/${GITEA_ORG}/${repo}.git"

  (
    cd "$dir"
    git init -b main 2>/dev/null || (git init && git checkout -b main)
    git config user.email "lab@cnpe.local"
    git config user.name "CNPE Lab"
    git add -A
    git commit -m "init: ${repo}" --allow-empty || true
    git remote remove origin 2>/dev/null || true
    git remote add origin "$remote_url"
    git push -u origin main --force
  )

  echo "[OK] Push completato: ${repo}"
}

mkdir -p "$LAB_DIR/${BASE_REPO}" "$LAB_DIR/${HELM_REPO}"

# Repo 1: deploy base via Kustomize
cat > "$LAB_DIR/${BASE_REPO}/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-nginx
  template:
    metadata:
      labels:
        app: hello-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
YAML

cat > "$LAB_DIR/${BASE_REPO}/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: hello-nginx
spec:
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
YAML

cat > "$LAB_DIR/${BASE_REPO}/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
YAML

# Repo 2: chart Helm custom + values
mkdir -p "$LAB_DIR/${HELM_REPO}/charts/podhello/templates"

cat > "$LAB_DIR/${HELM_REPO}/charts/podhello/Chart.yaml" <<'YAML'
apiVersion: v2
name: podhello
description: Chart demo per Flux da GitRepository
type: application
version: 0.1.0
appVersion: "1.0.0"
YAML

cat > "$LAB_DIR/${HELM_REPO}/charts/podhello/values.yaml" <<'YAML'
replicaCount: 1
image:
  repository: nginx
  tag: "1.27"
service:
  port: 80
YAML

cat > "$LAB_DIR/${HELM_REPO}/charts/podhello/templates/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
      - name: web
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
YAML

cat > "$LAB_DIR/${HELM_REPO}/charts/podhello/templates/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  selector:
    app: {{ .Release.Name }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: 80
YAML

ensure_repo "$BASE_REPO"
ensure_repo "$HELM_REPO"

push_repo "$LAB_DIR/${BASE_REPO}" "$BASE_REPO"
push_repo "$LAB_DIR/${HELM_REPO}" "$HELM_REPO"

cat <<EOF

Repository pronti:
- ${GITEA_URL}/${GITEA_ORG}/${BASE_REPO}
- ${GITEA_URL}/${GITEA_ORG}/${HELM_REPO}
EOF
SCRIPT

chmod +x "$LAB_DIR/setup-gitea-repos.sh"
~~~

Esegui:

~~~bash
"$LAB_DIR/setup-gitea-repos.sh"
~~~

## 4. Crea oggetti Flux per autenticazione Git e sorgenti

Flux deve leggere Gitea con credenziali. Crea secret basic-auth:

~~~bash
kubectl -n flux-system create secret generic gitea-auth \
  --from-literal=username="$GITEA_USER" \
  --from-literal=password="$GITEA_TOKEN" \
  --type=kubernetes.io/basic-auth \
  --dry-run=client -o yaml | kubectl apply -f -
~~~

Crea GitRepository e Kustomization per deploy base:

~~~bash
cat <<YAML | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-base-app
  namespace: flux-system
spec:
  interval: 1m
  url: ${GITEA_URL}/${GITEA_ORG}/flux-base-app.git
  secretRef:
    name: gitea-auth
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-base-app
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: flux-base-app
  path: ./
  prune: true
  targetNamespace: default
YAML
~~~

## 5. Crea oggetti Flux per chart Helm da GitRepository

Crea GitRepository e HelmRelease che punta al chart nel repo Git:

~~~bash
cat <<YAML | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-helm-app
  namespace: flux-system
spec:
  interval: 1m
  url: ${GITEA_URL}/${GITEA_ORG}/flux-helm-app.git
  secretRef:
    name: gitea-auth
  ref:
    branch: main
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: flux-helm-app
  namespace: default
spec:
  interval: 2m
  chart:
    spec:
      chart: ./charts/podhello
      sourceRef:
        kind: GitRepository
        name: flux-helm-app
        namespace: flux-system
      reconcileStrategy: Revision
  values:
    replicaCount: 2
    image:
      repository: nginx
      tag: "1.27"
YAML
~~~

## 6. Verifica e troubleshooting rapido

Verifica stato sorgenti Flux:

~~~bash
kubectl -n flux-system get gitrepositories
kubectl -n flux-system get kustomizations
kubectl -n default get helmreleases
~~~

Verifica workload:

~~~bash
kubectl -n default get deploy,svc,pods
~~~

Forza reconcile manuale:

~~~bash
kubectl -n flux-system annotate gitrepository flux-base-app \
  reconcile.fluxcd.io/requestedAt="$(date -Iseconds)" --overwrite
kubectl -n flux-system annotate gitrepository flux-helm-app \
  reconcile.fluxcd.io/requestedAt="$(date -Iseconds)" --overwrite
~~~

Se vedi Unauthorized su GitRepository:

- controlla secret flux-system/gitea-auth
- verifica username e token Gitea
- conferma URL repo con suffisso .git
- ripeti patch secretRef se manca in spec

## 7. Cleanup

~~~bash
kubectl -n default delete helmrelease flux-helm-app --ignore-not-found
kubectl -n flux-system delete gitrepository flux-helm-app --ignore-not-found
kubectl -n flux-system delete kustomization flux-base-app --ignore-not-found
kubectl -n flux-system delete gitrepository flux-base-app --ignore-not-found
~~~

## Note finali

Questo walkthrough è pensato come base didattica. Da qui puoi estendere con:

- ambienti separati dev stage prod
- policy immagine con image-reflector e image-automation
- alerting Flux con provider webhook e alert
- integrazione con receiver per webhook Gitea
