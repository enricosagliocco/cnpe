#!/usr/bin/env bash
# =============================================================================
# CNPE Mini Lab — OPA Gatekeeper focus
# Scenario: gatekeeper-mini
#
# Obiettivo:
#   creare un ambiente "exam-like" piccolo ma realistico per esercitarsi su:
#   - ConstraintTemplate e Rego
#   - Constraint match/enforcementAction
#   - AssignMetadata mutation
#   - audit/status violations
#   - patch minime ai workload
#
# Uso:
#   chmod +x setup-gatekeeper-mini.sh
#   ./setup-gatekeeper-mini.sh
#   ./setup-gatekeeper-mini.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-gk-mini}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

NS="gk-mini"
GK_NS="gatekeeper-system"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi

LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/gatekeeper-mini}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERR]${NC} $*"; exit 1; }
section() {
  echo -e "\n${BOLD}${GREEN}== $* ==${NC}\n"
}

have() { command -v "$1" >/dev/null 2>&1; }

cleanup() {
  section "Cleanup"
  kubectl delete ns "$NS" --ignore-not-found --timeout=120s 2>/dev/null || true
  kubectl delete K8sRequiredLabels required-platform-labels --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredResources required-container-resources --ignore-not-found 2>/dev/null || true
  kubectl delete K8sDisallowedImages disallow-latest-images --ignore-not-found 2>/dev/null || true
  kubectl delete K8sMinReplicas min-replicas --ignore-not-found 2>/dev/null || true
  kubectl delete assignmetadata default-owner --ignore-not-found 2>/dev/null || true
  for ct in k8srequiredlabels k8srequiredresources k8sdisallowedimages k8sminreplicas; do
    kubectl delete constrainttemplate "$ct" --ignore-not-found 2>/dev/null || true
  done
  rm -rf "$LAB_DIR"
  ok "Pulizia completata. Gatekeeper resta installato."
  exit 0
}

[[ "${1:-}" == "--cleanup" ]] && cleanup

section "0. Prerequisiti"
have minikube || die "minikube non trovato"
have kubectl  || die "kubectl non trovato"
have helm     || die "helm non trovato"
mkdir -p "$LAB_DIR"

section "1. Minikube"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=35g \
    --kubernetes-version="$K8S_VERSION" \
    --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

section "2. Install Gatekeeper"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace "$GK_NS" \
  --create-namespace \
  --wait \
  --timeout=300s \
  --set validatingWebhookConfiguration.timeoutSeconds=15

kubectl -n "$GK_NS" wait --for=condition=Ready pod -l gatekeeper.sh/operation=webhook --timeout=300s
ok "Gatekeeper webhook Ready"

section "3. Namespace e workload"
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

cat > "$LAB_DIR/00-workloads.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: gk-mini
  labels:
    app: payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: api
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-api
  namespace: gk-mini
  labels:
    app: catalog
    owner: retail
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
        owner: retail
    spec:
      containers:
      - name: api
        image: httpd:2-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: payments-api
  namespace: gk-mini
spec:
  selector:
    app: payments
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-api
  namespace: gk-mini
spec:
  selector:
    app: catalog
  ports:
  - port: 80
    targetPort: 80
YAML

kubectl apply -f "$LAB_DIR/00-workloads.yaml"

section "4. ConstraintTemplate volutamente difettosi"
cat > "$LAB_DIR/10-constrainttemplates-broken.yaml" <<'YAML'
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
        input.review.kind.kind == "Pod"
        required := input.parameters.labels[_]
        not input.review.object.metadata.labels[required]
        msg := sprintf("missing required label %v", [required])
      }
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredresources
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredResources
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredresources

      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        container := input.review.object.spec.containers[_]
        not container.resources.limits.cpu
        msg := sprintf("container %v missing cpu limit", [container.name])
      }

      violation[{"msg": msg}] {
        input.review.kind.kind == "Pod"
        container := input.review.object.spec.containers[_]
        not container.resources.limits.cpu
        msg := sprintf("container %v missing cpu limit", [container.name])
      }
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdisallowedimages
spec:
  crd:
    spec:
      names:
        kind: K8sDisallowedImages
      validation:
        openAPIV3Schema:
          type: object
          properties:
            forbiddenTags:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sdisallowedimages

      violation[{"msg": msg}] {
        input.review.kind.kind == "Pod"
        container := input.review.object.spec.containers[_]
        tag := input.parameters.forbiddenTags[_]
        endswith(container.image, tag)
        msg := sprintf("image %v uses forbidden tag suffix %v", [container.image, tag])
      }
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sminreplicas
spec:
  crd:
    spec:
      names:
        kind: K8sMinReplicas
      validation:
        openAPIV3Schema:
          type: object
          properties:
            min:
              type: integer
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sminreplicas

      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        input.review.object.spec.replicas < input.parameters.min
        msg := sprintf("deployment %v has replicas %v, required minimum %v", [input.review.object.metadata.name, input.review.object.spec.replicas, input.parameters.min])
      }
YAML

kubectl apply -f "$LAB_DIR/10-constrainttemplates-broken.yaml"
kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/k8srequiredlabels --timeout=180s
kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/k8srequiredresources --timeout=180s
kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/k8sdisallowedimages --timeout=180s
kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/k8sminreplicas --timeout=180s

section "5. Constraint e mutation volutamente difettose"
cat > "$LAB_DIR/20-constraints-broken.yaml" <<'YAML'
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: required-platform-labels
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - gk-mini-wrong
  parameters:
    labels:
    - app
    - owner
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: required-container-resources
spec:
  enforcementAction: dryrun
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - gk-mini
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedImages
metadata:
  name: disallow-latest-images
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - gk-mini
  parameters:
    forbiddenTags:
    - latest
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sMinReplicas
metadata:
  name: min-replicas
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces:
    - gk-mini
  parameters:
    min: 2
---
apiVersion: mutations.gatekeeper.sh/v1
kind: AssignMetadata
metadata:
  name: default-owner
spec:
  match:
    scope: Namespaced
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces:
    - gk-mini-mutate-wrong
  location: "metadata.labels.owner"
  parameters:
    assign:
      value: platform
YAML

kubectl apply -f "$LAB_DIR/20-constraints-broken.yaml"

cat > "$LAB_DIR/30-test-bad-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: gk-mini
  labels:
    app: bad
spec:
  containers:
  - name: c
    image: busybox:latest
    command: ["sleep", "3600"]
YAML

cat > "$LAB_DIR/README.txt" <<'TXT'
File principali:
  /course/gatekeeper-mini/00-workloads.yaml
  /course/gatekeeper-mini/10-constrainttemplates-broken.yaml
  /course/gatekeeper-mini/20-constraints-broken.yaml
  /course/gatekeeper-mini/30-test-bad-pod.yaml

Namespace:
  workload: gk-mini
  gatekeeper: gatekeeper-system

Nota:
  Le policy sono volutamente rotte o parziali.
  Le domande ti chiedono di correggerle con patch minime, come in esame.
TXT

section "6. Stato finale iniziale"
kubectl -n "$NS" get deploy,pod,svc
echo
kubectl get constrainttemplate
echo
kubectl get k8srequiredlabels,k8srequiredresources,k8sdisallowedimages,k8sminreplicas 2>/dev/null || true
echo
warn "Lab pronto. Domande nel file domande-gatekeeper-mini.md del pack."
warn "Working dir nel cluster: $LAB_DIR"
ok "Completato"
