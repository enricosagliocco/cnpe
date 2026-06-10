#!/usr/bin/env bash
set -euo pipefail

GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.22.2}"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi

COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course-gatekeeper}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_cluster() {
  if kubectl cluster-info >/dev/null 2>&1; then
    return
  fi

  if command -v minikube >/dev/null 2>&1; then
    info "No reachable cluster; starting Minikube"
    minikube start --cpus=4 --memory=6144
    kubectl cluster-info >/dev/null 2>&1 ||
      die "Minikube started, but kubectl still cannot reach the cluster"
    return
  fi

  die "No reachable Kubernetes cluster and Minikube is not installed"
}

apply_namespace() {
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

wait_for_gatekeeper_webhook() {
  local attempts=60
  local delay=2
  local check_namespace="gatekeeper-readiness-${RANDOM}-${RANDOM}"
  local attempt

  info "Waiting for the Gatekeeper admission webhook to accept requests"
  for attempt in $(seq 1 "$attempts"); do
    if kubectl create namespace "$check_namespace" \
      --dry-run=server -o name >/dev/null 2>&1; then
      ok "Gatekeeper admission webhook is ready"
      return
    fi

    sleep "$delay"
  done

  die "Gatekeeper admission webhook did not become ready after $((attempts * delay)) seconds"
}

require kubectl
require curl
ensure_cluster

if [ -f "$COURSE_DIR/.gatekeeper-lab-initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "${COURSE_DIR} already contains an initialized lab; use LAB_FORCE=true to overwrite it"
fi

info "Installing Gatekeeper ${GATEKEEPER_VERSION}; this can take 1-2 minutes"
kubectl apply -f \
  "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"

kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager \
  --timeout=300s
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-audit \
  --timeout=300s

wait_for_gatekeeper_webhook

for ns in apps dev staging prod exempt legacy team-a team-b; do
  apply_namespace "$ns"
done

kubectl label namespace staging policy.gatekeeper/enabled=true --overwrite
kubectl label namespace prod policy.gatekeeper/enabled=true --overwrite
kubectl label namespace exempt policy.gatekeeper/enabled=false --overwrite

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$n"
done
mkdir -p "$COURSE_DIR/19/policy-bundle/base"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

cat > "$COURSE_DIR/01/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requiredannotations
spec:
  crd:
    spec:
      names:
        kind: RequiredAnnotations
      validation:
        openAPIV3Schema:
          # TODO: define parameters.annotation as string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredannotations

        violation[{"msg": msg}] {
          not input.review.object.metadata.annotations[input.parameters.annotation]
          msg := "CHANGE THIS MESSAGE"
        }
YAML

cat > "$COURSE_DIR/01/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotations
metadata:
  name: require-owner-annotation
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups:
          - "apps"
        kinds: # TODO
    namespaces: # TODO
  parameters:
    # TODO
YAML

cat > "$COURSE_DIR/01/deployment-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-owner
  namespace: apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-owner
  template:
    metadata:
      labels:
        app: no-owner
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/01/deployment-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: has-owner
  namespace: apps
  annotations:
    owner: platform-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: has-owner
  template:
    metadata:
      labels:
        app: has-owner
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/02/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requiredlabels
spec:
  crd:
    spec:
      names:
        kind: RequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              # TODO
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredlabels

        violation[{"msg": msg}] {
          # TODO: calculate missing labels
          msg := "CHANGE THIS MESSAGE"
        }
YAML

cat > "$COURSE_DIR/02/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata:
  name: require-app-team-labels
spec:
  match:
    namespaces:
      - "apps"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
      - apiGroups:
          - "apps"
        kinds:
          - "Deployment"
  parameters:
    labels: [] # TODO
YAML

cat > "$COURSE_DIR/02/pod-bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: missing-app-team
  namespace: apps
spec:
  containers:
    - name: app
      image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/02/deployment-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: labeled-workload
  namespace: apps
  annotations:
    owner: platform-team
  labels:
    app: labeled-workload
    team: platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: labeled-workload
  template:
    metadata:
      labels:
        app: labeled-workload
        team: platform
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/03/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: allowedrepos
spec:
  crd:
    spec:
      names:
        kind: AllowedRepos
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
        package allowedrepos

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          # TODO: reject images without an allowed prefix
          msg := sprintf("container %v uses disallowed image %v", [container.name, container.image])
        }
YAML

cat > "$COURSE_DIR/03/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata:
  name: apps-allowed-repos
spec:
  match:
    namespaces:
      - "apps"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
  parameters:
    repos: [] # TODO
YAML

cat > "$COURSE_DIR/03/pod-allowed.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: allowed-image
  namespace: apps
spec:
  containers:
    - name: web
      image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/03/pod-denied.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: denied-image
  namespace: apps
spec:
  containers:
    - name: web
      image: docker.io/library/httpd:2-alpine
YAML

cat > "$COURSE_DIR/04/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: minimumreplicas
spec:
  crd:
    spec:
      names:
        kind: MinimumReplicas
      validation:
        openAPIV3Schema:
          type: object
          properties:
            minimum:
              type: integer
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package minimumreplicas

        violation[{"msg": msg}] {
          replicas := input.review.object.spec.replicas
          replicas < input.parameters.minimum
          msg := sprintf("requires at least %v replicas, found %v", [input.parameters.minimum, replicas])
        }
YAML

cat > "$COURSE_DIR/04/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: MinimumReplicas
metadata:
  name: prod-minimum-replicas
spec:
  # TODO
YAML

cat > "$COURSE_DIR/04/prod-api.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-api
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prod-api
  template:
    metadata:
      labels:
        app: prod-api
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/04/deployment-no-replicas.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: implicit-single-replica
  namespace: prod
spec:
  selector:
    matchLabels:
      app: implicit-single-replica
  template:
    metadata:
      labels:
        app: implicit-single-replica
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/05/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotations
metadata:
  name: require-cost-center
spec:
  # TODO: match Deployments in dev, staging, prod and legacy; exclude legacy
  parameters:
    annotation: cost-center
YAML

cat > "$COURSE_DIR/05/dev-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-api
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-api
  template:
    metadata:
      labels:
        app: dev-api
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/05/legacy-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-debug
  namespace: legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-debug
  template:
    metadata:
      labels:
        app: legacy-debug
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/05/dev-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: dev-pod
  namespace: dev
spec:
  containers:
    - name: app
      image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/06/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata:
  name: audit-owner-label
spec:
  enforcementAction: dryrun
  # TODO
YAML
touch "$COURSE_DIR/06/violations.txt"

cat > "$COURSE_DIR/06/new-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dryrun-admission-test
  namespace: team-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dryrun-admission-test
  template:
    metadata:
      labels:
        app: dryrun-admission-test
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/07/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata:
  name: warn-missing-environment
spec:
  enforcementAction: warn
  # TODO
YAML

cat > "$COURSE_DIR/07/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: warning-demo
  namespace: dev
spec:
  containers:
    - name: app
      image: nginx:1-alpine
YAML
touch "$COURSE_DIR/07/warning.txt"

cat > "$COURSE_DIR/08/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotations
metadata:
  name: owner-on-policy-enabled-namespaces
spec:
  match:
    namespaceSelector:
      # TODO
    kinds:
      - apiGroups:
          - "apps"
        kinds:
          - "Deployment"
  parameters:
    annotation: owner
YAML

cat > "$COURSE_DIR/08/staging-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: staging-no-owner
  namespace: staging
  annotations:
    cost-center: cc-100
spec:
  replicas: 1
  selector:
    matchLabels:
      app: staging-no-owner
  template:
    metadata:
      labels:
        app: staging-no-owner
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/08/prod-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-with-owner
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-200
spec:
  replicas: 2
  selector:
    matchLabels:
      app: prod-with-owner
  template:
    metadata:
      labels:
        app: prod-with-owner
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/08/exempt-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exempt-no-owner
  namespace: exempt
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exempt-no-owner
  template:
    metadata:
      labels:
        app: exempt-no-owner
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/09/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: disallowedservicetypes
spec:
  crd:
    spec:
      names:
        kind: DisallowedServiceTypes
      validation:
        openAPIV3Schema:
          # TODO
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package disallowedservicetypes

        violation[{"msg": msg}] {
          # TODO
          msg := sprintf("Service type %v is not allowed", [input.review.object.spec.type])
        }
YAML

cat > "$COURSE_DIR/09/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DisallowedServiceTypes
metadata:
  name: no-nodeport-services
spec:
  # TODO
YAML

cat > "$COURSE_DIR/09/public-api.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: public-api
  namespace: prod
spec:
  type: NodePort
  selector:
    app: prod-api
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30090
YAML

cat > "$COURSE_DIR/10/config.yaml" <<'YAML'
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: TODO
  namespace: gatekeeper-system
spec:
  sync:
    syncOnly:
      # TODO
YAML

cat > "$COURSE_DIR/10/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: uniqueingresshost
spec:
  crd:
    spec:
      names:
        kind: UniqueIngressHost
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package uniqueingresshost

        violation[{"msg": msg}] {
          # TODO: use data.inventory and ignore the reviewed object itself
          msg := "Ingress host is already in use"
        }
YAML

cat > "$COURSE_DIR/10/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: UniqueIngressHost
metadata:
  name: unique-ingress-host
spec:
  match:
    kinds:
      - apiGroups:
          - "networking.k8s.io"
        kinds:
          - "Ingress"
YAML

cat > "$COURSE_DIR/10/duplicate.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: duplicate
  namespace: staging
spec:
  rules:
    - host: shared.example.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: missing
                port:
                  number: 80
YAML

cat > "$COURSE_DIR/11/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requiredresources
spec:
  crd:
    spec:
      names:
        kind: RequiredResources
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredresources

        violation[{"msg": msg}] {
          # TODO: containers and initContainers
          msg := "CHANGE THIS MESSAGE"
        }
YAML

cat > "$COURSE_DIR/11/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredResources
metadata:
  name: apps-required-resources
spec:
  # TODO
YAML

cat > "$COURSE_DIR/11/worker.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: worker
  namespace: apps
  labels:
    app: worker
    team: platform
spec:
  initContainers:
    - name: init
      image: nginx:1-alpine
      command:
        - "sh"
        - "-c"
        - "echo init"
  containers:
    - name: worker
      image: nginx:1-alpine
      command:
        - "sh"
        - "-c"
        - "sleep 3600"
YAML

cat > "$COURSE_DIR/12/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: securepods
spec:
  crd:
    spec:
      names:
        kind: SecurePods
      validation:
        openAPIV3Schema:
          type: object
          properties:
            allowHostNetwork:
              type: boolean
            allowPrivileged:
              type: boolean
            allowPrivilegeEscalation:
              type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package securepods
        # TODO
YAML

cat > "$COURSE_DIR/12/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: SecurePods
metadata:
  name: prod-secure-pods
spec:
  # TODO
YAML

cat > "$COURSE_DIR/12/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: insecure
  namespace: prod
spec:
  hostNetwork: true
  containers:
    - name: app
      image: nginx:1-alpine
      securityContext:
        privileged: true
        allowPrivilegeEscalation: true
YAML

cat > "$COURSE_DIR/13/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: allowedservicetypes
spec:
  crd:
    spec:
      names:
        kind: AllowedServiceTypes
      validation:
        openAPIV3Schema:
          # TODO
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package allowedservicetypes
        # TODO: default missing type to ClusterIP
YAML

cat > "$COURSE_DIR/13/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedServiceTypes
metadata:
  name: dev-service-types
spec:
  # TODO
YAML

cat > "$COURSE_DIR/13/service-default.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: default-cluster-ip
  namespace: dev
spec:
  selector:
    app: dev-api
  ports:
    - port: 80
      targetPort: 80
YAML

cat > "$COURSE_DIR/13/service-external.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: external-catalog
  namespace: dev
spec:
  type: ExternalName
  externalName: catalog.example.test
YAML

cat > "$COURSE_DIR/13/service-nodeport.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: forbidden-nodeport
  namespace: dev
spec:
  type: NodePort
  selector:
    app: dev-api
  ports:
    - port: 80
      targetPort: 80
YAML

cat > "$COURSE_DIR/14/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: immutablelabel
spec:
  crd:
    spec:
      names:
        kind: ImmutableLabel
      validation:
        openAPIV3Schema:
          type: object
          properties:
            label:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package immutablelabel
        # TODO: compare object and oldObject only on UPDATE
YAML

cat > "$COURSE_DIR/14/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: ImmutableLabel
metadata:
  name: immutable-app-name
spec:
  # TODO
YAML

cat > "$COURSE_DIR/14/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-demo
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-300
  labels:
    app.kubernetes.io/name: immutable-demo
    team: platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: immutable-demo
  template:
    metadata:
      labels:
        app: immutable-demo
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/14/change-team-label.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-demo
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-300
  labels:
    app.kubernetes.io/name: immutable-demo
    team: operations
spec:
  replicas: 2
  selector:
    matchLabels:
      app: immutable-demo
  template:
    metadata:
      labels:
        app: immutable-demo
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/14/change-app-label.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-demo
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-300
  labels:
    app.kubernetes.io/name: changed-name
    team: operations
spec:
  replicas: 2
  selector:
    matchLabels:
      app: immutable-demo
  template:
    metadata:
      labels:
        app: immutable-demo
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cp "$COURSE_DIR/03/template.yaml" "$COURSE_DIR/15/template.yaml"
cat > "$COURSE_DIR/15/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata:
  name: all-container-types-allowed-repos
spec:
  match:
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
  parameters:
    repos:
      - registry.k8s.io/
YAML

cat > "$COURSE_DIR/15/pod-init-denied.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: init-image-denied
  namespace: prod
spec:
  initContainers:
    - name: init
      image: docker.io/library/busybox:1.36
      command:
        - "sh"
        - "-c"
        - "true"
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
YAML

cat > "$COURSE_DIR/15/pod-all-allowed.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: all-images-allowed
  namespace: prod
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
    - name: init
      image: registry.k8s.io/pause:3.10
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 100m
          memory: 64Mi
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 100m
          memory: 64Mi
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
YAML

cat > "$COURSE_DIR/16/expansion.yaml" <<'YAML'
apiVersion: expansion.gatekeeper.sh/v1alpha1
kind: ExpansionTemplate
metadata:
  name: expand-deployments
spec:
  applyTo:
    # TODO
  templateSource: # TODO
  generatedGVK:
    # TODO
YAML

cat > "$COURSE_DIR/16/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: podrunasnonroot
spec:
  crd:
    spec:
      names:
        kind: PodRunAsNonRoot
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package podrunasnonroot
        # TODO
YAML

cat > "$COURSE_DIR/16/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: PodRunAsNonRoot
metadata:
  name: pods-must-run-as-non-root
spec:
  match:
    source: Generated
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
YAML

cat > "$COURSE_DIR/16/deployment-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: root-deployment
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-400
spec:
  replicas: 2
  selector:
    matchLabels:
      app: root-deployment
  template:
    metadata:
      labels:
        app: root-deployment
    spec:
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
YAML

cat > "$COURSE_DIR/16/deployment-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: non-root-deployment
  namespace: prod
  annotations:
    owner: platform-team
    cost-center: cc-400
spec:
  replicas: 2
  selector:
    matchLabels:
      app: non-root-deployment
  template:
    metadata:
      labels:
        app: non-root-deployment
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
YAML

cat > "$COURSE_DIR/17/broken-template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requiredteam
spec:
  crd:
    spec:
      names:
        kind: RequiredTeam
      validation:
        openAPIV3Schema:
          properties:
            label:
              type: array
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredteam

        violation[{"msg": msg}] {
          not input.review.object.metadata.labels[input.parameters.label]
          msg := sprintf("missing team label: %v", input.parameters.label)
YAML
touch "$COURSE_DIR/17/report.md"

cat > "$COURSE_DIR/17/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredTeam
metadata:
  name: require-team-label
spec:
  enforcementAction: dryrun
  match:
    namespaces:
      - "dev"
    kinds:
      - apiGroups:
          - "apps"
        kinds:
          - "Deployment"
  parameters:
    label: team
YAML

cat > "$COURSE_DIR/18/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: workloadstandards
spec:
  crd:
    spec:
      names:
        kind: WorkloadStandards
      validation:
        openAPIV3Schema:
          type: object
          # TODO: complete structural schema
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package workloadstandards
        violation[{"msg": "training policy"}] {
          false
        }
YAML

cat > "$COURSE_DIR/18/invalid-parameters.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: WorkloadStandards
metadata:
  name: invalid-parameters
spec:
  parameters:
    requiredLabels: owner
    allowedEnvironments:
      - "production"
    minimumReplicas: 0
    unexpected: true
YAML

cat > "$COURSE_DIR/18/valid-parameters.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: WorkloadStandards
metadata:
  name: valid-parameters
spec:
  parameters:
    requiredLabels:
      - "app"
      - "owner"
    allowedEnvironments:
      - "dev"
      - "staging"
      - "prod"
    minimumReplicas: 2
YAML

cat > "$COURSE_DIR/19/policy-bundle/base/namespace.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: bundle-test
YAML

cp "$COURSE_DIR/01/template.yaml" \
  "$COURSE_DIR/19/policy-bundle/base/requiredannotations-template.yaml"
cp "$COURSE_DIR/02/template.yaml" \
  "$COURSE_DIR/19/policy-bundle/base/requiredlabels-template.yaml"

cat > "$COURSE_DIR/19/policy-bundle/base/constraints.yaml" <<'YAML'
YAML

cat > "$COURSE_DIR/19/policy-bundle/base/workload-good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bundle-good
  namespace: bundle-test
  annotations:
    owner: platform
  labels:
    app: bundle-good
    team: platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bundle-good
  template:
    metadata:
      labels:
        app: bundle-good
        team: platform
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/19/policy-bundle/base/workload-bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bundle-bad
  namespace: bundle-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bundle-bad
  template:
    metadata:
      labels:
        app: bundle-bad
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/19/policy-bundle/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  # TODO: add constraints.yaml; workloads are applied separately by install.sh
YAML

cat > "$COURSE_DIR/19/policy-bundle/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TODO:
# 1. Apply both ConstraintTemplates.
# 2. Wait until requiredannotations.constraints.gatekeeper.sh and
#    requiredlabels.constraints.gatekeeper.sh exist.
# 3. Apply ROOT/base with kubectl apply -k.
# 4. Apply workload-good.yaml and workload-bad.yaml separately and save output
#    to ROOT/result.txt. The script must continue after the expected denial.
SH
touch "$COURSE_DIR/19/policy-bundle/result.txt"

cat > "$COURSE_DIR/20/constraints.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotations
metadata:
  name: incident-owner
spec:
  enforcementAction: dryrun
  match:
    labelSelector:
      matchLabels:
        incident: gatekeeper-final
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - "apps"
        kinds:
          - "Deployment"
  parameters:
    annotation: owner
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata:
  name: incident-repositories
spec:
  enforcementAction: dryrun
  match:
    source: Generated
    labelSelector:
      matchLabels:
        incident: gatekeeper-final
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
  parameters:
    repos: [] # TODO: allow only registry.k8s.io/
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredResources
metadata:
  name: incident-resources
spec:
  enforcementAction: dryrun
  match:
    source: Generated
    labelSelector:
      matchLabels:
        incident: gatekeeper-final
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: SecurePods
metadata:
  name: incident-security
spec:
  enforcementAction: dryrun
  match:
    source: Generated
    labelSelector:
      matchLabels:
        incident: gatekeeper-final
    namespaces:
      - "prod"
    kinds:
      - apiGroups:
          - ""
        kinds:
          - "Pod"
  parameters:
    allowHostNetwork: false
    allowPrivileged: false
    allowPrivilegeEscalation: false
YAML

cat > "$COURSE_DIR/20/bad-new-workload.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-bad
  namespace: prod
  labels:
    incident: gatekeeper-final
  annotations:
    owner: platform-team
    cost-center: cc-incident-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: incident-bad
  template:
    metadata:
      labels:
        app: incident-bad
        incident: gatekeeper-final
    spec:
      hostNetwork: true
      securityContext:
        runAsNonRoot: true
      containers:
        - name: app
          image: docker.io/library/nginx:latest
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
YAML
touch "$COURSE_DIR/20/audit-before.txt"
touch "$COURSE_DIR/20/report.md"

# Pre-policy resources intentionally contain violations for audit exercises.
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-a-api
  namespace: team-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: team-a-api
  template:
    metadata:
      labels:
        app: team-a-api
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-b-worker
  namespace: team-b
  labels:
    owner: batch-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: team-b-worker
  template:
    metadata:
      labels:
        app: team-b-worker
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - "sh"
            - "-c"
            - "sleep 3600"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-api
  namespace: legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-api
  template:
    metadata:
      labels:
        app: legacy-api
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: ingress-backend
  namespace: dev
spec:
  selector:
    app: nonexistent
  ports:
    - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: existing-shared-host
  namespace: dev
spec:
  rules:
    - host: shared.example.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ingress-backend
                port:
                  number: 80
YAML

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout
  namespace: prod
  labels:
    app.kubernetes.io/name: checkout
    incident: gatekeeper-final
spec:
  replicas: 1
  selector:
    matchLabels:
      app: checkout
  template:
    metadata:
      labels:
        app: checkout
        incident: gatekeeper-final
    spec:
      hostNetwork: true
      containers:
        - name: app
          image: docker.io/library/nginx:latest
          securityContext:
            privileged: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  namespace: prod
  labels:
    incident: gatekeeper-final
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
        incident: gatekeeper-final
    spec:
      containers:
        - name: app
          image: docker.io/library/busybox:1.36
          command:
            - "sh"
            - "-c"
            - "sleep 3600"
YAML

source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.gatekeeper-lab-initialized"

ok "Gatekeeper lab ready"
echo "Questions: ${COURSE_DIR}/domande.md"
echo "Exercises: ${COURSE_DIR}/01 ... ${COURSE_DIR}/20"
echo
kubectl -n gatekeeper-system get pods
