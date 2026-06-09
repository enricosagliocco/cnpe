#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-security-policy-enforcement}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-existing}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-security}"
KYVERNO_VERSION="${KYVERNO_VERSION:-3.8.1}"
TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"

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

install_calico() {
  info "Installing Calico ${CALICO_VERSION}"
  kubectl apply -f \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
    >/dev/null
  kubectl -n kube-system rollout status daemonset/calico-node --timeout=300s
  kubectl -n kube-system rollout status deployment/calico-kube-controllers \
    --timeout=300s
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
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
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
  - role: worker
EOF
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kind started, but kubectl cannot reach the cluster"
      if ! kubectl -n kube-system get daemonset calico-node >/dev/null 2>&1; then
        if kubectl -n kube-system get daemonset kindnet >/dev/null 2>&1; then
          die "Existing kind cluster uses kindnet and cannot enforce this lab's NetworkPolicy; delete it with: kind delete cluster --name $KIND_CLUSTER_NAME"
        fi
        install_calico
      fi
      ;;
    *)
      die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

install_kyverno() {
  info "Installing Kyverno chart ${KYVERNO_VERSION}"
  helm repo add kyverno https://kyverno.github.io/kyverno/ \
    --force-update >/dev/null
  helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --version "$KYVERNO_VERSION" \
    --wait \
    --timeout 5m >/dev/null
  kubectl -n kyverno rollout status deploy/kyverno-admission-controller \
    --timeout=300s
  kubectl -n kyverno rollout status deploy/kyverno-reports-controller \
    --timeout=300s
}

install_tekton() {
  info "Installing Tekton Pipelines ${TEKTON_VERSION}"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml" \
    >/dev/null
  kubectl -n tekton-pipelines rollout status \
    deploy/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status \
    deploy/tekton-pipelines-webhook --timeout=300s
}

generate_mtls_secrets() {
  command -v openssl >/dev/null || die "openssl is required"
  local tmp
  tmp="$(mktemp -d)"

  openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
    -subj "/CN=cnpe-security-ca" \
    -keyout "$tmp/ca.key" \
    -out "$tmp/ca.crt" >/dev/null 2>&1

  openssl req -newkey rsa:2048 -nodes \
    -subj "/CN=payments.security-apps.svc" \
    -keyout "$tmp/server.key" \
    -out "$tmp/server.csr" >/dev/null 2>&1
  cat > "$tmp/server.ext" <<'EOF'
subjectAltName=DNS:payments,DNS:payments.security-apps,DNS:payments.security-apps.svc,DNS:payments.security-apps.svc.cluster.local
extendedKeyUsage=serverAuth
EOF
  openssl x509 -req -days 365 \
    -in "$tmp/server.csr" \
    -CA "$tmp/ca.crt" \
    -CAkey "$tmp/ca.key" \
    -CAcreateserial \
    -out "$tmp/server.crt" \
    -extfile "$tmp/server.ext" >/dev/null 2>&1

  openssl req -newkey rsa:2048 -nodes \
    -subj "/CN=frontend.security-apps.svc" \
    -keyout "$tmp/client.key" \
    -out "$tmp/client.csr" >/dev/null 2>&1
  cat > "$tmp/client.ext" <<'EOF'
extendedKeyUsage=clientAuth
EOF
  openssl x509 -req -days 365 \
    -in "$tmp/client.csr" \
    -CA "$tmp/ca.crt" \
    -CAkey "$tmp/ca.key" \
    -CAcreateserial \
    -out "$tmp/client.crt" \
    -extfile "$tmp/client.ext" >/dev/null 2>&1

  kubectl -n security-apps create secret generic payments-mtls \
    --from-file=tls.crt="$tmp/server.crt" \
    --from-file=tls.key="$tmp/server.key" \
    --from-file=ca.crt="$tmp/ca.crt" \
    --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null

  kubectl -n security-apps create secret generic frontend-client-mtls \
    --from-file=tls.crt="$tmp/client.crt" \
    --from-file=tls.key="$tmp/client.key" \
    --from-file=ca.crt="$tmp/ca.crt" \
    --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null

  rm -rf "$tmp"
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || die "helm is required when INSTALL_TOOLS=true"
  install_kyverno
  install_tekton
else
  kubectl get crd validatingpolicies.policies.kyverno.io >/dev/null 2>&1 ||
    die "Kyverno validating policy CRD is required"
  kubectl get crd pipelines.tekton.dev >/dev/null 2>&1 ||
    die "Tekton Pipelines CRDs are required"
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  for namespace in security-apps security-exempt security-platform security-pipeline; do
    kubectl delete namespace "$namespace" --ignore-not-found --wait=true
  done
  rm -rf "$COURSE_DIR"
fi

for number in $(seq -w 1 20); do
  mkdir -p "$COURSE_DIR/$number"
done
for namespace in security-apps security-exempt security-platform security-pipeline; do
  kubectl create namespace "$namespace" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done
kubectl label namespace security-apps security.cnpe.io/policy=enabled \
  --overwrite >/dev/null

generate_mtls_secrets

cat > "$COURSE_DIR/01/app-config.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: security-apps
data:
  BACKEND_URL: http://payments:8080
YAML

cat > "$COURSE_DIR/01/networkpolicy.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payments-ingress
  namespace: security-apps
spec:
  podSelector:
    matchLabels:
      app: payments
  policyTypes:
    - Ingress
  ingress: [] # TODO allow frontend to reach TCP 8443 only
YAML

cat > "$COURSE_DIR/01/verification.txt" <<'TXT'
TODO: save frontend logs, rogue-client test, and final curl result here.
TXT

kubectl apply -f "$COURSE_DIR/01/app-config.yaml" >/dev/null
kubectl apply -f "$COURSE_DIR/01/networkpolicy.yaml" >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: payments-nginx
  namespace: security-apps
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 8443 ssl;
        ssl_certificate /etc/nginx/tls/tls.crt;
        ssl_certificate_key /etc/nginx/tls/tls.key;
        ssl_client_certificate /etc/nginx/tls/ca.crt;
        ssl_verify_client on;
        location / {
          return 200 "payments ok\n";
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  namespace: security-apps
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
        security.cnpe.io/tier: backend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - name: mtls
              containerPort: 8443
          volumeMounts:
            - name: config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
              readOnly: true
            - name: mtls
              mountPath: /etc/nginx/tls
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: payments-nginx
        - name: mtls
          secret:
            secretName: payments-mtls
---
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: security-apps
spec:
  selector:
    app: payments
  ports:
    - name: mtls
      port: 8443
      targetPort: 8443
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: security-apps
  annotations:
    exam.cnpe.io/do-not-modify: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        security.cnpe.io/tier: frontend
    spec:
      containers:
        - name: client
          image: curlimages/curl:8.11.1
          envFrom:
            - configMapRef:
                name: frontend-config
          command:
            - /bin/sh
            - -c
          args:
            - |
              while true; do
                echo "calling ${BACKEND_URL}"
                curl --fail --silent --show-error \
                  --cacert /mtls/ca.crt \
                  --cert /mtls/tls.crt \
                  --key /mtls/tls.key \
                  "${BACKEND_URL}"
                sleep 30
              done
          volumeMounts:
            - name: mtls
              mountPath: /mtls
              readOnly: true
      volumes:
        - name: mtls
          secret:
            secretName: frontend-client-mtls
---
apiVersion: v1
kind: Pod
metadata:
  name: rogue-client
  namespace: security-apps
  labels:
    app: rogue-client
spec:
  restartPolicy: Never
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command:
        - /bin/sh
        - -c
      args:
        - sleep 3600
---
apiVersion: v1
kind: Pod
metadata:
  name: unauthenticated-client
  namespace: security-apps
  labels:
    app: frontend
spec:
  restartPolicy: Never
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command:
        - /bin/sh
        - -c
      args:
        - sleep 3600
YAML

cat > "$COURSE_DIR/02/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: platform-auditor
  namespace: security-platform
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-auditor
rules:
  - apiGroups:
      - ""
      - "apps"
      - "rbac.authorization.k8s.io"
      - "policies.kyverno.io"
      - "wgpolicyk8s.io"
      - "tekton.dev"
    resources:
      - "pods"
      - "pods/log"
      - "secrets"
      - "services"
      - "deployments"
      - "statefulsets"
      - "daemonsets"
      - "roles"
      - "rolebindings"
      - "validatingpolicies"
      - "policyreports"
      - "clusterpolicyreports"
      - "pipelines"
      - "pipelineruns"
      - "taskruns"
    verbs:
      - "get"
      - "list"
      - "watch"
      - "create"
      - "update"
      - "patch"
      - "delete"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-auditor
subjects:
  - kind: ServiceAccount
    name: platform-auditor
    namespace: security-platform
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-auditor
YAML
kubectl apply -f "$COURSE_DIR/02/rbac.yaml" >/dev/null
touch "$COURSE_DIR/02/auth-check.txt"

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-api
  namespace: security-apps
  labels:
    app: legacy-api
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
        - name: api
          image: registry.k8s.io/pause:3.10
---
apiVersion: v1
kind: Secret
metadata:
  name: audit-negative-test
  namespace: security-apps
stringData:
  token: do-not-read
YAML

cat > "$COURSE_DIR/03/audit-policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: audit-workload-metadata
spec:
  validationActions:
    - Audit
  matchConstraints:
    namespaceSelector: {} # TODO security.cnpe.io/policy=enabled
    resourceRules:
      - apiGroups:
          - "apps"
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
          - "UPDATE"
        resources:
          - "deployments"
  validations:
    - message: "Deployment must declare owner and data-classification labels"
      expression: "true" # TODO
YAML
touch "$COURSE_DIR/03/audit-before.txt" "$COURSE_DIR/03/audit-after.txt"

cat > "$COURSE_DIR/04/governance-policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: enforce-pod-security-and-digests
spec:
  validationActions:
    - Audit # TODO Deny
  matchConstraints:
    namespaceSelector: {} # TODO security.cnpe.io/policy=enabled
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
          - "UPDATE"
        resources:
          - "pods"
  validations:
    - message: "Pods must run as non-root and containers must use digest-pinned images"
      expression: "true" # TODO
YAML

cat > "$COURSE_DIR/04/pod-bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: governance-bad
  namespace: security-apps
spec:
  containers:
    - name: app
      image: nginx:latest
      securityContext:
        privileged: true
YAML

cat > "$COURSE_DIR/04/pod-good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: governance-good
  namespace: security-apps
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: registry.k8s.io/pause@sha256:ee6521f290b2168b6e093ab04e5a909942065ad9f329a5bc3d2f2a76c23c0d0f
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
YAML

cat > "$COURSE_DIR/04/pod-excluded.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: governance-excluded
  namespace: security-exempt
spec:
  containers:
    - name: app
      image: nginx:latest
      securityContext:
        privileged: true
YAML
touch "$COURSE_DIR/04/admission.txt"

cat > "$COURSE_DIR/05/sbom.json" <<'JSON'
{
  "SPDXID": "SPDXRef-DOCUMENT",
  "spdxVersion": "SPDX-2.3",
  "packages": [
    {
      "name": "orders-api",
      "licenseConcluded": "NOASSERTION"
    }
  ]
}
JSON

cat > "$COURSE_DIR/05/scan-report.json" <<'JSON'
{
  "scanner": "training-scanner",
  "summary": {
    "critical": 1,
    "high": 2,
    "medium": 4
  }
}
JSON

cat > "$COURSE_DIR/05/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: secure-deployment
  namespace: security-pipeline
spec:
  workspaces:
    - name: security-workspace
  tasks:
    - name: generate-sbom
      taskSpec:
        workspaces:
          - name: source
        volumes:
          - name: security-inputs
            configMap:
              name: security-inputs
        steps:
          - name: copy
            image: alpine:3.20
            script: |
              #!/bin/sh
              cp /security-inputs/sbom.json $(workspaces.source.path)/generated-sbom.json
              cp /security-inputs/scan-report.json $(workspaces.source.path)/scan-report.json
            volumeMounts:
              - name: security-inputs
                mountPath: /security-inputs
                readOnly: true
      workspaces:
        - name: source
          workspace: security-workspace
    - name: compliance-gate
      runAfter:
        - generate-sbom
      taskSpec:
        workspaces:
          - name: source
        results:
          - name: decision
        steps:
          - name: verify
            image: mikefarah/yq:4
            script: |
              #!/bin/sh
              # TODO: validate generated-sbom.json and scan-report.json.
              echo -n passed > $(results.decision.path)
      workspaces:
        - name: source
          workspace: security-workspace
    - name: deploy
      runAfter:
        - compliance-gate
      when: [] # TODO run only when compliance-gate result is passed
      taskSpec:
        steps:
          - name: deploy
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "deployment approved"
YAML

cat > "$COURSE_DIR/05/pipelinerun.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: secure-deployment-
  namespace: security-pipeline
spec:
  pipelineRef:
    name: secure-deployment
  workspaces:
    - name: security-workspace
      emptyDir: {}
YAML

kubectl -n security-pipeline create configmap security-inputs \
  --from-file=sbom.json="$COURSE_DIR/05/sbom.json" \
  --from-file=scan-report.json="$COURSE_DIR/05/scan-report.json" \
  --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null
touch "$COURSE_DIR/05/pipeline-result.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
load_question_layout
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Security and policy enforcement lab ready: $COURSE_DIR"
kubectl -n security-apps get deploy,pods,svc
kubectl -n security-platform get serviceaccount
kubectl -n security-pipeline get pipeline
