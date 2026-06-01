  #!/usr/bin/env bash
  set -euo pipefail

  PROFILE="cnpe-flagger"
  K8S_VERSION="v1.35.0"

  ok() { echo "[OK] $*"; }
  warn() { echo "[WARN] $*"; }
  info() { echo "[INFO] $*"; }

  GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
  GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
  GITEA_API="${GITEA_URL%/}/api/v1"
  GITEA_OWNER="organization"

  gitea_available() {
    curl -fsS --connect-timeout 3 --max-time 5 -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" >/dev/null 2>&1
  }

  seed_git_repo_to_gitea() {
    local repo_path="$1"
    local repo_name="$2"
    local commit_message="$3"
    local status post_status push_base push_url

    git -C "$repo_path" init -b main >/dev/null 2>&1
    git -C "$repo_path" config user.name "CNPE Setup"
    git -C "$repo_path" config user.email "cnpe-setup@example.local"
    git -C "$repo_path" add .
    git -C "$repo_path" commit -m "$commit_message" >/dev/null 2>&1 || true

    if ! gitea_available; then
      warn "Gitea non raggiungibile, salto il push per ${repo_name}"
      return 0
    fi

    if [[ -z "$GITEA_OWNER" ]]; then
      if ! GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/user" | sed -n 's/.*"login":"\([^\"]*\)".*/\1/p' | head -n1)"; then
        warn "Impossibile risolvere l'owner Gitea, salto il push per ${repo_name}"
        return 0
      fi
    fi
    if [[ -z "$GITEA_OWNER" ]]; then
      warn "Unable to resolve Gitea owner, skipping push for ${repo_name}"
      return 0
    fi

    status="$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_API}/repos/${GITEA_OWNER}/${repo_name}" || true)"
    if [[ "$status" != "200" ]]; then
      post_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" -d "{\"name\":\"${repo_name}\",\"private\":false,\"auto_init\":false}" "${GITEA_API}/orgs/${GITEA_OWNER}/repos" || true)"
      if [[ "$post_status" != "201" && "$post_status" != "409" ]]; then
        warn "Gitea repo create failed for ${repo_name} (HTTP ${post_status})"
        return 0
      fi
    fi

    push_base="${GITEA_URL%/}"
    push_url="${push_base/\/\//\/\/${GITEA_OWNER}:${GITEA_TOKEN}@}/${GITEA_OWNER}/${repo_name}.git"
    git -C "$repo_path" remote remove origin >/dev/null 2>&1 || true
    git -C "$repo_path" remote add origin "$push_url" >/dev/null 2>&1 || true
    git -C "$repo_path" push -u origin main --force >/dev/null 2>&1 || warn "Push to Gitea failed for ${repo_name}"
  }

  for cmd in minikube kubectl git curl docker helm; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "[ERR] missing command: $cmd"; exit 1; }
  done

  if mkdir -p /course >/dev/null 2>&1; then
    COURSE_ROOT="/course"
  else
    COURSE_ROOT="$HOME/course"
    mkdir -p "$COURSE_ROOT"
    warn "Cannot write /course, using ${COURSE_ROOT}"
  fi

  for i in $(seq 1 12); do
    mkdir -p "$COURSE_ROOT/$i"
  done

  echo "[INFO] Removing any pre-existing minikube clusters/profiles"
  minikube delete --all >/dev/null 2>&1 || true
  minikube delete -p "$PROFILE" >/dev/null 2>&1 || true

  info "Starting minikube profile ${PROFILE}"
  minikube start \
    --profile="$PROFILE" \
    --kubernetes-version="$K8S_VERSION" \
    --driver=docker \
    --cpus=4 \
    --memory=8192 \
    --addons=ingress,metrics-server

  kubectl config use-context "$PROFILE" >/dev/null
  kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null

  kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl create namespace flagger-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  info "Installing Flagger (best effort)"
  if ! kubectl apply -f "https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml" >/dev/null 2>&1; then
    warn "Flagger CRD install failed"
  fi
  if ! helm repo add flagger https://flagger.app --force-update >/dev/null 2>&1; then
    warn "Flagger helm repo add failed"
  fi
  if ! helm repo update >/dev/null 2>&1; then
    warn "Flagger helm repo update failed"
  fi
  flagger_render_file="$(mktemp)"
  flagger_render_err="$(mktemp)"
  flagger_apply_err="$(mktemp)"
  if ! helm template flagger flagger/flagger \
    --namespace flagger-system \
    --set meshProvider=nginx \
    --set prometheus.install=true >"${flagger_render_file}" 2>"${flagger_render_err}"; then
    warn "Flagger helm render failed"
    tail -n 20 "${flagger_render_err}" >&2 || true
  elif ! kubectl apply -f "${flagger_render_file}" >/dev/null 2>"${flagger_apply_err}"; then
    warn "Flagger apply rendered manifests failed"
    tail -n 20 "${flagger_apply_err}" >&2 || true
  fi
  rm -f "${flagger_render_file}" >/dev/null 2>&1 || true
  rm -f "${flagger_render_err}" >/dev/null 2>&1 || true
  rm -f "${flagger_apply_err}" >/dev/null 2>&1 || true

  flagger_deploy_name="$(kubectl -n flagger-system get deploy -l app.kubernetes.io/name=flagger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${flagger_deploy_name}" ]]; then
    kubectl -n flagger-system rollout status "deploy/${flagger_deploy_name}" --timeout=300s >/dev/null || warn "flagger deployment not ready yet"
  else
    warn "Flagger deployment not found in flagger-system"
  fi

  mkdir -p "$COURSE_ROOT/2/repo-flagger/apps/podinfo"

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/deploy.yaml" <<'YAML'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: podinfo
    namespace: flagger-lab
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: podinfo
    template:
      metadata:
        labels:
          app: podinfo
      spec:
        containers:
        - name: app
          image: ghcr.io/stefanprodan/podinfo:6.6.0
          ports:
          - containerPort: 9898
YAML

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/svc.yaml" <<'YAML'
  apiVersion: v1
  kind: Service
  metadata:
    name: podinfo
    namespace: flagger-lab
  spec:
    selector:
      app: podinfo
    ports:
    - port: 80
      targetPort: 9898
YAML

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/ingress.yaml" <<'YAML'
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: podinfo
    namespace: flagger-lab
    labels:
      app: podinfo
    annotations:
      kubernetes.io/ingress.class: nginx
  spec:
    ingressClassName: nginx
    rules:
    - host: podinfo.flagger.local
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: podinfo
              port:
                number: 80
YAML

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/hpa.yaml" <<'YAML'
  apiVersion: autoscaling/v2
  kind: HorizontalPodAutoscaler
  metadata:
    name: podinfo
    namespace: flagger-lab
  spec:
    scaleTargetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: podinfo
    minReplicas: 2
    maxReplicas: 5
    metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
YAML

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/canary.yaml" <<'YAML'
  apiVersion: flagger.app/v1beta1
  kind: Canary
  metadata:
    name: podinfo
    namespace: flagger-lab
  spec:
    provider: nginx
    targetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: podinfo
    ingressRef:
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      name: podinfo
    autoscalerRef:
      apiVersion: autoscaling/v2
      kind: HorizontalPodAutoscaler
      name: podinfo
    progressDeadlineSeconds: 120
    service:
      port: 80
      targetPort: 9898
    analysis:
      interval: 30s
      threshold: 3
      maxWeight: 50
      stepWeight: 10
      metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
YAML

  cat > "$COURSE_ROOT/2/repo-flagger/apps/podinfo/kustomization.yaml" <<'YAML'
  resources:
  - deploy.yaml
  - svc.yaml
  - ingress.yaml
  - hpa.yaml
  - canary.yaml
YAML

  seed_git_repo_to_gitea "$COURSE_ROOT/2/repo-flagger" "cnpe-specific-flagger-repo" "init flagger repo"

  cat > "$COURSE_ROOT/README-flagger.txt" <<'TXT'
  CNPE Batteria Specifica Flagger

  Namespace controller: flagger-system
  Namespace laboratorio: flagger-lab

  Repo seedato su Gitea:
  - cnpe-specific-flagger-repo

  Working copy locale:
  - /course/2/repo-flagger
TXT

  ok "Setup batteria Flagger completato"
  echo "Course root: $COURSE_ROOT"
