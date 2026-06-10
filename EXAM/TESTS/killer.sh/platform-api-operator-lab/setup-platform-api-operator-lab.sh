#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-platform-api-operator}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-platform-api}"
TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

load_question_layout() {
  local shared_layout="$SCRIPT_DIR/../lab-question-layout.sh"

  if [ -f "$shared_layout" ]; then
    source "$shared_layout"
    return
  fi

  # Keep the lab runnable when only this lab directory is copied.
  prepare_question_layout() {
    local course_dir="$1"
    local questions_file="$2"
    local directory_style="${3:-padded}"
    local directory
    local number
    local heading

    [ -f "$questions_file" ] || {
      echo "[ERR] questions file not found: $questions_file" >&2
      return 1
    }

    for number in $(seq 1 20); do
      if [ "$directory_style" = "plain" ]; then
        directory="$number"
      else
        directory="$(printf '%02d' "$number")"
      fi
      mkdir -p "$course_dir/$directory"
      rm -f "$course_dir/$directory/QUESTION.md"
      touch "$course_dir/$directory/evidence.txt"
    done

    awk -v course_dir="$course_dir" -v directory_style="$directory_style" '
      /^### Q[0-9]+ / {
        heading = $0
        sub(/^### Q/, "", heading)
        split(heading, fields, " ")
        if (directory_style == "plain") {
          question = fields[1] + 0
        } else {
          question = sprintf("%02d", fields[1])
        }
        output = course_dir "/" question "/QUESTION.md"
        print $0 > output
        next
      }
      /^### / {
        question = ""
      }
      question != "" {
        print $0 > output
      }
    ' "$questions_file"

    {
      echo "# Question index"
      echo
      for number in $(seq 1 20); do
        if [ "$directory_style" = "plain" ]; then
          directory="$number"
        else
          directory="$(printf '%02d' "$number")"
        fi
        if [ ! -s "$course_dir/$directory/QUESTION.md" ]; then
          echo "[ERR] Q${number#0} was not extracted from $questions_file" >&2
          return 1
        fi
        heading="$(head -n 1 "$course_dir/$directory/QUESTION.md")"
        heading="${heading#\#\#\# }"
        printf -- '- [%s](%s/QUESTION.md)\n' "$heading" "$directory"
      done
    } > "$course_dir/questions-index.md"
  }
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a Kubernetes cluster"
      ;;
    kind)
      command -v kind >/dev/null || die "kind is required"
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        info "Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
        info "Creating kind cluster: $KIND_CLUSTER_NAME"
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_tekton() {
  info "Installing Tekton Pipelines ${TEKTON_VERSION}"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml" \
    >/dev/null
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-pipelines-webhook --timeout=300s
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  install_tekton
else
  kubectl get crd pipelines.tekton.dev >/dev/null 2>&1 ||
    die "Tekton Pipelines CRDs are required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  kubectl delete namespace platform-system tenant-a self-service \
    --ignore-not-found --wait=true
  kubectl delete clusterrole platform-service-operator --ignore-not-found
  kubectl delete clusterrolebinding platform-service-operator \
    --ignore-not-found
  kubectl delete crd platformservices.platform.cnpe.io --ignore-not-found
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done
for namespace in platform-system tenant-a self-service; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

cat > "$COURSE_DIR/01/platformservice-crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformservices.platform.cnpe.io
spec:
  group: platform.cnpe.io
  scope: Namespaced
  names:
    plural: platformservices
    singular: platformservice
    kind: PlatformService
    shortNames:
      - ps
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true # TODO structural schema
YAML
kubectl apply -f "$COURSE_DIR/01/platformservice-crd.yaml" >/dev/null

cat > "$COURSE_DIR/01/service-valid.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: api-valid
  namespace: tenant-a
spec:
  owner:
    team: platform
  plan: small
  image: nginx:1.27-alpine
YAML

cat > "$COURSE_DIR/01/service-invalid-plan.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: api-invalid-plan
  namespace: tenant-a
spec:
  owner:
    team: platform
  plan: large
  image: nginx:1.27-alpine
YAML

cat > "$COURSE_DIR/01/service-invalid-replicas.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: api-invalid-replicas
  namespace: tenant-a
spec:
  owner:
    team: platform
  plan: medium
  image: nginx:1.27-alpine
  replicas: 8
YAML
touch "$COURSE_DIR/01/crd-check.txt"

cat > "$COURSE_DIR/02/developer-rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer
  namespace: tenant-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: platform-service-editor
  namespace: tenant-a
rules:
  - apiGroups:
      - platform.cnpe.io
    resources:
      - platformservices
    verbs:
      - get
      - list
      - watch
      # TODO allow self-service create, update, patch and delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: platform-service-editor
  namespace: tenant-a
subjects:
  - kind: ServiceAccount
    name: developer
    namespace: tenant-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: platform-service-editor
YAML
kubectl apply -f "$COURSE_DIR/02/developer-rbac.yaml" >/dev/null
touch "$COURSE_DIR/02/rbac-check.txt"

cat > "$COURSE_DIR/03/operator-rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: platform-service-operator
  namespace: platform-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-service-operator
rules:
  - apiGroups:
      - platform.cnpe.io
    resources:
      - platformservices
    verbs:
      - get
      - list
      - watch
      # TODO Q17 add patch for metadata.finalizers
  - apiGroups:
      - platform.cnpe.io
    resources:
      - platformservices/status
    verbs: [] # TODO get, patch and update
  - apiGroups:
      - apps
    resources:
      - deployments
    verbs:
      - get
      - list
      - watch
      # TODO create, update, patch and delete
  - apiGroups:
      - ""
    resources:
      - services
      - configmaps
    verbs:
      - get
      - list
      - watch
      # TODO create, update, patch and delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-service-operator
subjects:
  - kind: ServiceAccount
    name: platform-service-operator
    namespace: platform-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-service-operator
YAML

cat > "$COURSE_DIR/03/operator.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-service-operator
  namespace: platform-system
data:
  reconcile.sh: |
    #!/bin/sh
    set -u

    while true; do
      kubectl get platformservices.platform.cnpe.io --all-namespaces \
        --no-headers -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' |
      while read -r namespace name; do
        [ -n "$namespace" ] || continue
        deletion_timestamp="$(kubectl -n "$namespace" get platformservice "$name" \
          -o jsonpath='{.metadata.deletionTimestamp}')"
        finalizers="$(kubectl -n "$namespace" get platformservice "$name" \
          -o jsonpath='{.metadata.finalizers[*]}')"

        if [ -n "$deletion_timestamp" ]; then
          if echo "$finalizers" | grep -qw platform.cnpe.io/cleanup; then
            # TODO Q18: delete Deployment, Service and ConfigMap, then remove
            # platform.cnpe.io/cleanup from metadata.finalizers.
            echo "cleanup pending for ${namespace}/${name}"
          fi
          continue
        fi

        image="$(kubectl -n "$namespace" get platformservice "$name" \
          -o jsonpath='{.spec.image}')"
        replicas="$(kubectl -n "$namespace" get platformservice "$name" \
          -o jsonpath='{.spec.replicas}')"
        team="$(kubectl -n "$namespace" get platformservice "$name" \
          -o jsonpath='{.spec.owner.team}')"

        kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${name}-platform
      namespace: ${namespace}
      labels:
        platform.cnpe.io/managed-by: platform-service-operator
    data:
      TEAM: "${team}"
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${name}
      namespace: ${namespace}
      labels:
        platform.cnpe.io/managed-by: platform-service-operator
    spec:
      replicas: ${replicas}
      selector:
        matchLabels:
          app: ${name}
      template:
        metadata:
          labels:
            app: ${name}
        spec:
          containers:
            - name: app
              image: ${image}
              ports:
                - name: http
                  containerPort: 80
              envFrom:
                - configMapRef:
                    name: ${name}-platform
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: ${name}
      namespace: ${namespace}
      labels:
        platform.cnpe.io/managed-by: platform-service-operator
    spec:
      selector:
        app: ${name}
      ports:
        - name: http
          port: 80
          targetPort: http
    EOF

        kubectl -n "$namespace" patch platformservice "$name" \
          --subresource=status --type=merge \
          -p '{"status":{"phase":"Ready","message":"Resources reconciled"}}'
      done
      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-service-operator
  namespace: platform-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: platform-service-operator
  template:
    metadata:
      labels:
        app: platform-service-operator
    spec:
      serviceAccountName: platform-service-operator
      containers:
        - name: operator
          image: registry.k8s.io/kubectl:v1.32.0
          command:
            - /bin/sh
            - /opt/operator/reconcile.sh
          volumeMounts:
            - name: script
              mountPath: /opt/operator
      volumes:
        - name: script
          configMap:
            name: platform-service-operator
            defaultMode: 0755
YAML
kubectl apply -f "$COURSE_DIR/03/operator-rbac.yaml" >/dev/null
kubectl apply -f "$COURSE_DIR/03/operator.yaml" >/dev/null

cat > "$COURSE_DIR/03/sample-service.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: catalog
  namespace: tenant-a
spec:
  owner:
    team: storefront
  plan: small
  image: nginx:1.27-alpine
  replicas: 2
YAML
kubectl apply -f "$COURSE_DIR/03/sample-service.yaml" >/dev/null
touch "$COURSE_DIR/03/operator-check.txt"

cat > "$COURSE_DIR/04/pipeline-rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: provisioner
  namespace: self-service
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: provisioner
  namespace: tenant-a
rules:
  - apiGroups:
      - platform.cnpe.io
    resources:
      - platformservices
    verbs:
      - get
      # TODO create, update and patch through the platform API
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: provisioner
  namespace: tenant-a
subjects:
  - kind: ServiceAccount
    name: provisioner
    namespace: self-service
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: provisioner
YAML

cat > "$COURSE_DIR/04/provisioning-pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: provision-platform-service
  namespace: self-service
spec:
  params:
    - name: service-name
      type: string
    - name: target-namespace
      type: string
      default: tenant-a
    - name: team
      type: string
    - name: plan
      type: string
      default: small
    - name: image
      type: string
      default: nginx:1.27-alpine
  tasks:
    - name: validate-request
      taskSpec:
        params:
          - name: plan
        steps:
          - name: validate
            image: alpine:3.20
            script: |
              #!/bin/sh
              case "$(params.plan)" in
                small|medium) exit 0 ;;
                *) echo "unsupported plan" >&2; exit 1 ;;
              esac
      params:
        - name: plan
          value: $(params.plan)
    - name: create-platform-request
      # TODO run only after validate-request succeeds
      taskSpec:
        params:
          - name: service-name
          - name: target-namespace
          - name: team
          - name: plan
          - name: image
        steps:
          - name: create
            image: registry.k8s.io/kubectl:v1.32.0
            script: |
              #!/bin/sh
              kubectl apply -f - <<EOF
              apiVersion: platform.cnpe.io/v1alpha1
              kind: PlatformService
              metadata:
                name: $(params.service-name)
                namespace: $(params.target-namespace)
              spec:
                owner:
                  team: $(params.team)
                plan: $(params.plan)
                image: $(params.image)
                replicas: 1
              EOF
      params:
        - name: service-name
          value: $(params.service-name)
        - name: target-namespace
          value: $(params.target-namespace)
        - name: team
          value: $(params.team)
        - name: plan
          value: $(params.plan)
        - name: image
          value: $(params.image)
YAML

cat > "$COURSE_DIR/04/provisioning-run.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: provision-checkout-
  namespace: self-service
spec:
  pipelineRef:
    name: provision-platform-service
  taskRunTemplate:
    serviceAccountName: default # TODO provisioner
  params:
    - name: service-name
      value: checkout
    - name: target-namespace
      value: tenant-a
    - name: team
      value: payments
    - name: plan
      value: medium
YAML

cat > "$COURSE_DIR/04/provisioning-run-invalid.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: provision-invalid-
  namespace: self-service
spec:
  pipelineRef:
    name: provision-platform-service
  taskRunTemplate:
    serviceAccountName: provisioner
  params:
    - name: service-name
      value: rejected-service
    - name: target-namespace
      value: tenant-a
    - name: team
      value: payments
    - name: plan
      value: large
YAML
kubectl apply -f "$COURSE_DIR/04/pipeline-rbac.yaml" >/dev/null
touch "$COURSE_DIR/04/workflow-check.txt"

cat > "$COURSE_DIR/05/lifecycle-service.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformService
metadata:
  name: reports
  namespace: tenant-a
  # TODO add platform.cnpe.io/cleanup finalizer
spec:
  owner:
    team: analytics
  plan: medium
  image: nginx:1.27-alpine
  replicas: 2
YAML
touch "$COURSE_DIR/05/lifecycle-check.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
load_question_layout
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Platform API and operator lab ready: $COURSE_DIR"
kubectl get crd platformservices.platform.cnpe.io
kubectl -n platform-system get deployment,pods
kubectl -n tenant-a get platformservices
