#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="${KYVERNO_VERSION:-3.8.1}"
CLI_VERSION="${CLI_VERSION:-1.18.1}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-kyverno}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

die() { echo "[ERR] $*" >&2; exit 1; }

load_question_layout() {
  local shared_layout="$SCRIPT_DIR/../lab-question-layout.sh"

  if [ -f "$shared_layout" ]; then
    # The full repository keeps this helper next to all lab directories.
    source "$shared_layout"
    return
  fi

  # Keep the lab runnable when only the kyverno-lab directory is copied.
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
  if kubectl cluster-info >/dev/null 2>&1; then
    return
  fi
  if command -v minikube >/dev/null 2>&1; then
    echo "[INFO] No reachable cluster; starting Minikube"
    minikube start --cpus=4 --memory=6144
    kubectl cluster-info >/dev/null 2>&1 ||
      die "Minikube started, but kubectl still cannot reach the cluster"
    return
  fi
  die "No reachable Kubernetes cluster and Minikube is not installed"
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || { echo "helm is required"; exit 1; }
  helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace \
    --version "$KYVERNO_VERSION" --wait
  kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=300s
  kubectl -n kyverno rollout status deploy/kyverno-background-controller --timeout=300s
fi

if ! command -v kyverno >/dev/null; then
  command -v curl >/dev/null || { echo "curl is required to install kyverno CLI"; exit 1; }
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "unsupported architecture: $arch"; exit 1 ;;
  esac
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/kyverno/kyverno/releases/download/v${CLI_VERSION}/kyverno-cli_v${CLI_VERSION}_linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp/kyverno" "$HOME/.local/bin/kyverno"
  rm -rf "$tmp"
fi

mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

for ns in apps production team-a team-b exempt; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
kubectl label ns team-a policy.kyverno.io/enabled=true --overwrite >/dev/null
kubectl label ns team-b policy.kyverno.io/enabled=true --overwrite >/dev/null
kubectl label ns exempt policy.kyverno.io/enabled=true policy.kyverno.io/exempt=true --overwrite >/dev/null

cat > "$COURSE_DIR/01/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-ns-annotation
spec:
  validationActions: [] # TODO Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "namespaces"
  validations:
    - message: "Namespace must have annotation 'project-name'"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/01/bad.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: kyverno-project-bad
YAML
cat > "$COURSE_DIR/01/good.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: kyverno-project-good
  annotations:
    project-name: payments
YAML

cat > "$COURSE_DIR/02/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata:
  name: mutate-pods
  namespace: apps
spec:
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "pods"
  mutations: [] # TODO ApplyConfiguration label and annotation
YAML
cat > "$COURSE_DIR/02/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: metadata-demo
  namespace: apps
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML

cat > "$COURSE_DIR/03/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-deployment-labels
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "Deployment is missing required labels"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/03/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: labels-bad
  namespace: apps
spec:
  selector:
    matchLabels:
      app: labels-bad
  template:
    metadata:
      labels:
        app: labels-bad
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/03/good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: labels-good
  namespace: apps
  labels:
    app.kubernetes.io/name: labels-good
    owner: platform
spec:
  selector:
    matchLabels:
      app: labels-good
  template:
    metadata:
      labels:
        app: labels-good
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/04/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: minimum-replicas
spec:
  validationActions:
    - Deny
  matchConstraints:
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
  matchConditions: [] # TODO environment=production
  validations:
    - message: "Production Deployments require at least 2 replicas"
      expression: "true" # TODO
YAML
for mode in bad good; do
  replicas=1; [ "$mode" = good ] && replicas=2
  cat > "$COURSE_DIR/04/${mode}.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: replicas-${mode}
  namespace: production
  labels:
    environment: production
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: replicas-${mode}
  template:
    metadata:
      labels:
        app: replicas-${mode}
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
done

cat > "$COURSE_DIR/05/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-resources
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "All containers require CPU/memory requests and limits"
      expression: "true" # TODO containers and initContainers
YAML
cat > "$COURSE_DIR/05/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: resources-bad
  namespace: apps
spec:
  initContainers:
    - name: init
      image: busybox:1.36
      command:
        - sh
        - -c
        - "true"
  containers:
    - name: app
      image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/05/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: resources-good
  namespace: apps
spec:
  containers:
    - name: app
      image: nginx:1-alpine
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 100m
          memory: 64Mi
YAML

cat > "$COURSE_DIR/06/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata:
  name: allowed-registries
  namespace: apps
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "Container image uses a disallowed registry"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/06/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: registry-bad
  namespace: apps
spec:
  initContainers:
    - name: init
      image: docker.io/library/busybox:1.36
      command:
        - sh
        - -c
        - "true"
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
cat > "$COURSE_DIR/06/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: registry-good
  namespace: apps
spec:
  containers:
    - name: app
      image: ghcr.io/company/api:1.0.0
YAML

cat > "$COURSE_DIR/07/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: disallow-latest
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "Images require an explicit non-latest tag or digest"
      expression: "true" # TODO
YAML
for name in latest untagged pinned; do
  image=nginx:latest
  [ "$name" = untagged ] && image=nginx
  [ "$name" = pinned ] && image=nginx:1.27-alpine
  cat > "$COURSE_DIR/07/${name}.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: image-${name}
  namespace: apps
spec:
  containers:
    - name: app
      image: ${image}
YAML
done
touch "$COURSE_DIR/07/result.txt"

cat > "$COURSE_DIR/08/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "Pod must run as non-root with seccomp"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/08/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: pss-bad
  namespace: apps
spec:
  containers:
    - name: app
      image: nginx:1-alpine
YAML
cat > "$COURSE_DIR/08/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: pss-good
  namespace: apps
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginx:1-alpine
YAML

cat > "$COURSE_DIR/09/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: secure-containers
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "Containers must not be privileged or allow privilege escalation"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/09/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: privilege-bad
  namespace: apps
spec:
  containers:
    - name: app
      image: nginx:1-alpine
      securityContext:
        privileged: true
        allowPrivilegeEscalation: true
YAML
cat > "$COURSE_DIR/09/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: privilege-good
  namespace: apps
spec:
  containers:
    - name: app
      image: nginx:1-alpine
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
YAML

cat > "$COURSE_DIR/10/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: disallow-hostpath
spec:
  validationActions:
    - Deny
  matchConstraints:
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
    - message: "hostPath volumes are not allowed"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/10/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-bad
  namespace: apps
spec:
  volumes:
    - name: host
      hostPath:
        path: /var/lib
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - "sleep 3600"
      volumeMounts:
        - name: host
          mountPath: /host
YAML
cat > "$COURSE_DIR/10/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-good
  namespace: apps
spec:
  volumes:
    - name: data
      emptyDir: {}
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - "sleep 3600"
      volumeMounts:
        - name: data
          mountPath: /data
YAML

cat > "$COURSE_DIR/11/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata:
  name: restrict-service-types
  namespace: production
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
          - "UPDATE"
        resources:
          - "services"
  validations:
    - message: "Only ClusterIP and ExternalName Services are allowed"
      expression: "true" # TODO
YAML
for type in default clusterip nodeport; do
  extra=""
  [ "$type" = clusterip ] && extra='type: ClusterIP'
  [ "$type" = nodeport ] && extra='type: NodePort'
  cat > "$COURSE_DIR/11/${type}.yaml" <<YAML
apiVersion: v1
kind: Service
metadata:
  name: service-${type}
  namespace: production
spec:
  ${extra}
  selector:
    app: demo
  ports:
    - port: 80
      targetPort: 80
YAML
done

cat > "$COURSE_DIR/12/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-ingress-tls
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - "networking.k8s.io"
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
          - "UPDATE"
        resources:
          - "ingresses"
  validations:
    - message: "Every Ingress host must be covered by TLS"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/12/bad.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-bad
  namespace: apps
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
YAML
cat > "$COURSE_DIR/12/good.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-good
  namespace: apps
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
YAML

cat > "$COURSE_DIR/13/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: immutable-team
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - "apps"
        apiVersions:
          - "v1"
        operations:
          - "UPDATE"
        resources:
          - "deployments"
  validations:
    - message: "The team label is immutable"
      expression: "true" # TODO object vs oldObject
YAML
cat > "$COURSE_DIR/13/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-demo
  namespace: apps
  labels:
    team: platform
    version: v1
spec:
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
cat > "$COURSE_DIR/13/change-team.yaml" <<'YAML'
metadata:
  labels:
    team: payments
YAML
cat > "$COURSE_DIR/13/change-version.yaml" <<'YAML'
metadata:
  labels:
    version: v2
YAML

cat > "$COURSE_DIR/14/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: production-security
spec:
  validationActions:
    - Deny
  matchConstraints:
    namespaceSelector: {} # TODO enabled and not exempt
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "pods"
  validations:
    - message: "Pod requires security-reviewed=true"
      expression: "'security-reviewed' in object.metadata.?labels.orValue({}) && object.metadata.labels['security-reviewed'] == 'true'"
YAML
for ns in team-a team-b exempt; do
  cat > "$COURSE_DIR/14/${ns}.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: selector-${ns}
  namespace: ${ns}
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
done

cat > "$COURSE_DIR/15/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata:
  name: team-a-owner
  namespace: team-a
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "configmaps"
  validations:
    - message: "ConfigMap requires owner annotation"
      expression: "true" # TODO
YAML
for name in bad good other; do
  ns=team-a; annotations=""
  [ "$name" = good ] && annotations='annotations: {owner: platform}'
  [ "$name" = other ] && ns=team-b
  cat > "$COURSE_DIR/15/${name}.yaml" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: owner-${name}
  namespace: ${ns}
  ${annotations}
data:
  key: value
YAML
done

cat > "$COURSE_DIR/16/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-cost-center
spec:
  validationActions:
    - Audit
  matchConstraints:
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
    - message: "Deployment requires cost-center label"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/16/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-demo
  namespace: apps
spec:
  selector:
    matchLabels:
      app: audit-demo
  template:
    metadata:
      labels:
        app: audit-demo
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
YAML
kubectl apply -f "$COURSE_DIR/16/deployment.yaml" >/dev/null

cat > "$COURSE_DIR/17/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: required-owner-message
spec:
  validationActions:
    - Deny
  matchConstraints:
    resourceRules:
      - apiGroups:
          - "apps"
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "deployments"
  validations:
    - message: "Deployment requires owner annotation"
      # TODO messageExpression with object.metadata.name
      expression: "'owner' in object.metadata.?annotations.orValue({})"
YAML
cp "$COURSE_DIR/03/bad.yaml" "$COURSE_DIR/17/bad.yaml"
sed -i 's/labels-bad/api-no-owner/g' "$COURSE_DIR/17/bad.yaml"

cat > "$COURSE_DIR/18/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata:
  name: default-environment
  namespace: apps
spec:
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "pods"
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: |-
          Object{metadata: Object.metadata{labels: Object.metadata.labels{environment: "development"}}} # TODO conditional
YAML
for mode in missing existing; do
  labels=""
  [ "$mode" = existing ] && labels='labels: {environment: production}'
  cat > "$COURSE_DIR/18/pod-${mode}.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: environment-${mode}
  namespace: apps
  ${labels}
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
done

cat > "$COURSE_DIR/19/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata:
  name: default-container-security
  namespace: apps
spec:
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "pods"
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO map containers
YAML
cat > "$COURSE_DIR/19/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: security-defaults
  namespace: apps
spec:
  containers:
    - name: api
      image: nginx:1-alpine
    - name: sidecar
      image: busybox:1.36
      command:
        - sh
        - -c
        - "sleep 3600"
YAML

mkdir -p "$COURSE_DIR/20/bundle"
cat > "$COURSE_DIR/20/bundle/validating-policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata:
  name: final-validation
  namespace: apps
spec:
  validationActions:         # TODO Deny
    - Audit
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:                # TODO pods
          - "configmaps"
  validations:
    - message: "Pod requires owner annotation"
      expression: "'owner' in object.metadata.annotations" # TODO safe optional map
YAML
cat > "$COURSE_DIR/20/bundle/mutating-policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata:
  name: final-mutation
  namespace: apps
spec:
  matchConstraints:
    resourceRules:
      - apiGroups:
          - ""
        apiVersions:
          - "v1"
        operations:
          - "CREATE"
        resources:
          - "pods"
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: 'Object{metadata: Object.metadata{labels: Object.metadata.labels{owner: "platform", managed: "true"}}}' # TODO preserve owner
YAML
cat > "$COURSE_DIR/20/bundle/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - validating-policy.yaml
  - mutating-policy.yaml
YAML
cat > "$COURSE_DIR/20/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: final-bad
  namespace: apps
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
cat > "$COURSE_DIR/20/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: final-good
  namespace: apps
  annotations:
    owner: payments
  labels:
    owner: payments
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
touch "$COURSE_DIR/20/report.md"

load_question_layout
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
echo "Kyverno lab ready: $COURSE_DIR"
