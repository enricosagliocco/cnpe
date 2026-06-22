#!/usr/bin/env bash
set -euo pipefail

KYVERNO_VERSION="${KYVERNO_VERSION:-3.8.1}"
KYVERNO_CLI_VERSION="${KYVERNO_CLI_VERSION:-1.18.1}"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.22.2}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-policy-exam}"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-policy-exam-lab}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

info() { echo "[INFO] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      require kind
      if ! kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        require minikube
        minikube start --cpus=4 --memory=7168
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

install_components() {
  if [ "$INSTALL_TOOLS" != "true" ]; then
    return
  fi

  require helm
  info "Installing Kyverno $KYVERNO_VERSION"
  helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace \
    --version "$KYVERNO_VERSION" --wait

  info "Installing Gatekeeper $GATEKEEPER_VERSION"
  kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
  kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=300s
  kubectl -n gatekeeper-system rollout status deploy/gatekeeper-audit --timeout=300s
}

install_kyverno_cli() {
  command -v kyverno >/dev/null 2>&1 && return
  require curl
  local arch tmp
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) die "Unsupported architecture: $arch" ;;
  esac
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_CLI_VERSION}/kyverno-cli_v${KYVERNO_CLI_VERSION}_linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp/kyverno" "$HOME/.local/bin/kyverno"
  rm -rf "$tmp"
}

make_namespace() {
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

require kubectl
ensure_cluster
[ ! -e "$COURSE_DIR/.initialized" ] || [ "$LAB_FORCE" = "true" ] || \
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
install_components
install_kyverno_cli

for ns in caribbean apps production team-a team-b exempt legacy finale; do
  make_namespace "$ns"
done
kubectl label ns team-a policy.kyverno.io/enabled=true policy.gatekeeper/enabled=true --overwrite >/dev/null
kubectl label ns team-b policy.kyverno.io/enabled=true policy.gatekeeper/enabled=true --overwrite >/dev/null
kubectl label ns exempt policy.kyverno.io/enabled=true policy.kyverno.io/exempt=true \
  policy.gatekeeper/enabled=true policy.gatekeeper/exempt=true --overwrite >/dev/null

mkdir -p "$COURSE_DIR"
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"

# Q1: the exact conditional-mutation exam pattern.
cat > "$COURSE_DIR/01/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata:
  name: security-check
  namespace: caribbean
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO: add audit=pending only when absent
YAML
cat > "$COURSE_DIR/01/pods.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: test-pending
  namespace: caribbean
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: test-passed
  namespace: caribbean
spec:
  containers:
    - name: nginx
      image: nginx:1-alpine
YAML

# Q2-Q3: metadata and list mutation.
cat > "$COURSE_DIR/02/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: default-owner, namespace: team-a}
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["configmaps"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO
YAML
cat > "$COURSE_DIR/02/missing.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata: {name: owner-missing, namespace: team-a, labels: {version: v1}}
data: {key: value}
YAML
cat > "$COURSE_DIR/02/existing.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: owner-existing
  namespace: team-a
  annotations: {owner: payments}
  labels: {version: v1}
data: {key: value}
YAML

cat > "$COURSE_DIR/03/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: default-pull-policy, namespace: apps}
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO: use object.spec.containers.map(...)
YAML
cat > "$COURSE_DIR/03/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: pull-policy-demo, namespace: apps}
spec:
  containers:
    - {name: default-me, image: nginx:1-alpine}
    - {name: preserve-me, image: busybox:1.36, imagePullPolicy: Always, command: ["sleep", "3600"]}
YAML

# Q4-Q5: validating policies.
cat > "$COURSE_DIR/04/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata: {name: require-app-labels, namespace: production}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  validations:
    - message: "TODO"
      expression: "true" # TODO
YAML
cat > "$COURSE_DIR/04/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: labels-bad, namespace: production}
spec:
  selector: {matchLabels: {app: labels-bad}}
  template:
    metadata: {labels: {app: labels-bad}}
    spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
cat > "$COURSE_DIR/04/good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: labels-good
  namespace: production
  labels: {app.kubernetes.io/name: api, app.kubernetes.io/part-of: shop}
spec:
  selector: {matchLabels: {app: labels-good}}
  template:
    metadata: {labels: {app: labels-good}}
    spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML

cat > "$COURSE_DIR/05/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata: {name: require-pinned-images, namespace: apps}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - message: "Images must use an explicit tag or digest"
      expression: "true" # TODO containers and initContainers
YAML
for mode in bad tagged digest; do
  image=nginx
  [ "$mode" = tagged ] && image=nginx:1-alpine
  [ "$mode" = digest ] && image='registry.k8s.io/pause@sha256:8b4e6f66dbe6a0f4d1f70d8a04f6c4f269cbbc4e8d4f9303b6f8c020fd4eeaf2'
  cat > "$COURSE_DIR/05/${mode}.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata: {name: pinned-${mode}, namespace: apps}
spec: {containers: [{name: app, image: "${image}"}]}
YAML
done

# Q6-Q10: transitions, rollout and troubleshooting.
cat > "$COURSE_DIR/06/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedValidatingPolicy
metadata: {name: protect-audit-state, namespace: caribbean}
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["UPDATE"]
        resources: ["pods"]
  validations:
    - message: "Invalid audit state transition"
      expression: "true" # TODO compare object and oldObject
YAML
cat > "$COURSE_DIR/06/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: audit-transition, namespace: caribbean, labels: {audit: pending}}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
cat > "$COURSE_DIR/06/pass-patch.yaml" <<'YAML'
metadata: {labels: {audit: passed}}
YAML
cat > "$COURSE_DIR/06/revert-patch.yaml" <<'YAML'
metadata: {labels: {audit: pending}}
YAML

cat > "$COURSE_DIR/07/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: require-cost-center}
spec:
  validationActions: [Audit]
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  validations:
    - message: "Deployment requires cost-center"
      expression: "true" # TODO
YAML
cp "$COURSE_DIR/04/bad.yaml" "$COURSE_DIR/07/new-bad.yaml"
sed -i 's/labels-bad/cost-center-new/g' "$COURSE_DIR/07/new-bad.yaml"
kubectl create deployment cost-center-existing -n legacy --image=nginx:1-alpine --dry-run=client -o yaml | kubectl apply -f - >/dev/null

cat > "$COURSE_DIR/08/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: default-container-security, namespace: apps}
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO map containers and preserve explicit values
YAML
cat > "$COURSE_DIR/08/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: security-defaults, namespace: apps}
spec:
  containers:
    - {name: api, image: "nginx:1-alpine"}
    - name: explicit
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext: {allowPrivilegeEscalation: true}
YAML

cat > "$COURSE_DIR/09/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: {name: reviewed-namespaces}
spec:
  validationActions: [Deny]
  matchConstraints:
    namespaceSelector:
      matchLabels: {policy.kyverno.io/enabled: "false"} # TODO
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  validations:
    - message: "Pod must be security-reviewed"
      expression: "true" # TODO
YAML
for ns in team-a team-b exempt; do
  cat > "$COURSE_DIR/09/${ns}.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata: {name: reviewed-${ns}, namespace: ${ns}}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
done

cat > "$COURSE_DIR/10/policy.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: managed-by-kyverno, namespace: legacy}
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"] # BUG: expected CREATE and UPDATE
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: 'Object{metadata: Object.metadata{labels: Object.metadata.labels{"managed-by": "kyverno"}}}'
YAML
cat > "$COURSE_DIR/10/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: legacy-update, namespace: legacy}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML

# Shared Gatekeeper templates used by several questions.
cat > "$COURSE_DIR/11/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: requiredmetadatalabel}
spec:
  crd:
    spec:
      names: {kind: RequiredMetadataLabel}
      validation:
        openAPIV3Schema:
          type: object
          properties:
            label: {type: string}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredmetadatalabel
        violation[{"msg": msg}] {
          false # TODO
          msg := "TODO"
        }
YAML
cat > "$COURSE_DIR/11/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredMetadataLabel
metadata: {name: require-owner}
spec:
  enforcementAction: deny
  match: {} # TODO Deployment in apps
  parameters: {label: owner}
YAML
cp "$COURSE_DIR/04/bad.yaml" "$COURSE_DIR/11/bad.yaml"
sed -i 's/namespace: production/namespace: apps/' "$COURSE_DIR/11/bad.yaml"
cat > "$COURSE_DIR/11/good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: owner-good
  namespace: apps
  labels:
    owner: platform
spec:
  selector: {matchLabels: {app: owner-good}}
  template:
    metadata: {labels: {app: owner-good}}
    spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML

cat > "$COURSE_DIR/12/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: allowedrepositories}
spec:
  crd:
    spec:
      names: {kind: AllowedRepositories}
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repositories: {type: array, items: {type: string}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package allowedrepositories
        violation[{"msg": msg}] {
          false # TODO containers and initContainers
          msg := "TODO"
        }
YAML
cat > "$COURSE_DIR/12/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepositories
metadata: {name: approved-registries}
spec:
  enforcementAction: deny
  match:
    namespaces: [apps]
    kinds: [{apiGroups: [""], kinds: [Pod]}]
  parameters: {repositories: ["registry.k8s.io/", "ghcr.io/company/"]}
YAML
cat > "$COURSE_DIR/12/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: repo-bad, namespace: apps}
spec: {containers: [{name: web, image: "docker.io/library/nginx:1-alpine"}]}
YAML
cat > "$COURSE_DIR/12/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: repo-good, namespace: apps}
spec:
  initContainers: [{name: init, image: "registry.k8s.io/busybox:1.36", command: ["true"]}]
  containers: [{name: web, image: "ghcr.io/company/web:v1"}]
YAML

cat > "$COURSE_DIR/13/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: requiredresources}
spec:
  crd: {spec: {names: {kind: RequiredResources}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredresources
        violation[{"msg": msg}] {
          false # TODO check cpu/memory requests and limits
          msg := "TODO"
        }
YAML
cat > "$COURSE_DIR/13/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredResources
metadata: {name: require-pod-resources}
spec:
  enforcementAction: deny
  match: {namespaces: [production], kinds: [{apiGroups: [""], kinds: [Pod]}]}
YAML
cat > "$COURSE_DIR/13/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: resources-demo, namespace: production}
spec:
  initContainers: [{name: init, image: "busybox:1.36", command: ["true"]}]
  containers: [{name: app, image: "nginx:1-alpine", resources: {requests: {cpu: 10m}}}]
YAML

cat > "$COURSE_DIR/14/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: requiredannotation}
spec:
  crd:
    spec:
      names: {kind: RequiredAnnotation}
      validation: {openAPIV3Schema: {type: object, properties: {annotation: {type: string}}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredannotation
        violation[{"msg": msg}] {
          not input.review.object.metadata.annotations[input.parameters.annotation]
          msg := sprintf("Missing annotation: %v", [input.parameters.annotation])
        }
YAML
cat > "$COURSE_DIR/14/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotation
metadata: {name: selected-owner}
spec:
  enforcementAction: deny
  match: {} # TODO namespaceSelector, exclusion and Deployment kind
  parameters: {annotation: owner}
YAML
for ns in team-a exempt; do
  sed "s/namespace: production/namespace: ${ns}/; s/labels-bad/selected-${ns}/g" \
    "$COURSE_DIR/04/bad.yaml" > "$COURSE_DIR/14/${ns}.yaml"
done

cp "$COURSE_DIR/11/template.yaml" "$COURSE_DIR/15/template.yaml"
cat > "$COURSE_DIR/15/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredMetadataLabel
metadata: {name: audit-environment}
spec:
  enforcementAction: dryrun
  match: {namespaces: [team-a], kinds: [{apiGroups: ["apps"], kinds: [Deployment]}]}
  parameters: {label: environment}
YAML
kubectl create deployment audit-existing -n team-a --image=nginx:1-alpine --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create deployment audit-new -n team-a --image=nginx:1-alpine --dry-run=client -o yaml > "$COURSE_DIR/15/new.yaml"

cp "$COURSE_DIR/11/template.yaml" "$COURSE_DIR/16/template.yaml"
cat > "$COURSE_DIR/16/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredMetadataLabel
metadata: {name: warn-team}
spec:
  enforcementAction: warn
  match: {namespaces: [apps], kinds: [{apiGroups: [""], kinds: [Pod]}]}
  parameters: {label: team}
YAML
cat > "$COURSE_DIR/16/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: warning-demo, namespace: apps}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML

cat > "$COURSE_DIR/17/config.yaml" <<'YAML'
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata: {name: config, namespace: gatekeeper-system}
spec:
  sync:
    syncOnly: [] # TODO networking.k8s.io/v1 Ingress
YAML
cat > "$COURSE_DIR/17/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: uniqueingresshost}
spec:
  crd: {spec: {names: {kind: UniqueIngressHost}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package uniqueingresshost
        violation[{"msg": msg}] {
          false # TODO use data.inventory and ignore the same uid
          msg := "TODO"
        }
YAML
cat > "$COURSE_DIR/17/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: UniqueIngressHost
metadata: {name: unique-hosts}
spec:
  enforcementAction: deny
  match: {kinds: [{apiGroups: ["networking.k8s.io"], kinds: [Ingress]}]}
YAML
cat > "$COURSE_DIR/17/existing.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: existing, namespace: team-a}
spec:
  rules:
    - host: shared.example.test
      http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: web, port: {number: 80}}}}]}
YAML
sed 's/name: existing/name: duplicate/; s/namespace: team-a/namespace: team-b/' \
  "$COURSE_DIR/17/existing.yaml" > "$COURSE_DIR/17/duplicate.yaml"
kubectl apply -f "$COURSE_DIR/17/existing.yaml" >/dev/null

cat > "$COURSE_DIR/18/assign.yaml" <<'YAML'
apiVersion: mutations.gatekeeper.sh/v1
kind: AssignMetadata
metadata: {name: default-data-classification}
spec:
  applyTo: [] # TODO core/v1 Pod
  match: {}   # TODO apps
  location: metadata.labels.data-classification
  parameters:
    assign: {value: internal}
    pathTests: [] # TODO MustNotExist
YAML
cat > "$COURSE_DIR/18/missing.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: classification-missing, namespace: apps}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
sed '/namespace: apps/a\  labels: {data-classification: restricted}' \
  "$COURSE_DIR/18/missing.yaml" | sed 's/classification-missing/classification-existing/' \
  > "$COURSE_DIR/18/existing.yaml"

cat > "$COURSE_DIR/19/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: disallowhostnetwork}
spec:
  crd:
    spec:
      names: {kind: DisallowHostNetworking} # BUG
      validation:
        legacySchema: true # BUG
  targets:
    - target: wrong.target.example # BUG
      rego: |
        package wrongpackage
        violation[{"msg": "hostNetwork is forbidden"}] {
          input.review.object.spec.hostNetwork == false # BUG
        }
YAML
cat > "$COURSE_DIR/19/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DisallowHostNetwork
metadata: {name: no-host-network}
spec:
  enforcementAction: deny
  match: {namespaces: [production], kinds: [{apiGroups: [""], kinds: [Pod]}]}
YAML
cat > "$COURSE_DIR/19/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: hostnet-bad, namespace: production}
spec: {hostNetwork: true, containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
sed 's/hostnet-bad/hostnet-good/; s/hostNetwork: true/hostNetwork: false/' \
  "$COURSE_DIR/19/bad.yaml" > "$COURSE_DIR/19/good.yaml"

mkdir -p "$COURSE_DIR/20/bundle"
cat > "$COURSE_DIR/20/bundle/kyverno.yaml" <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: NamespacedMutatingPolicy
metadata: {name: final-security-check, namespace: finale}
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: "Object{}" # TODO conditional audit label
YAML
cp "$COURSE_DIR/11/template.yaml" "$COURSE_DIR/20/bundle/gatekeeper-template.yaml"
cat > "$COURSE_DIR/20/bundle/gatekeeper-constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredMetadataLabel
metadata: {name: final-owner}
spec:
  enforcementAction: deny
  match: {namespaces: [finale], kinds: [{apiGroups: [""], kinds: [Pod]}]}
  parameters: {label: owner}
YAML
cat > "$COURSE_DIR/20/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-bad, namespace: finale}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML
cat > "$COURSE_DIR/20/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: final-good, namespace: finale, labels: {owner: platform}}
spec: {containers: [{name: app, image: "nginx:1-alpine"}]}
YAML

touch "$COURSE_DIR/.initialized"
info "Policy exam lab ready: $COURSE_DIR"
info "Start with: cd $COURSE_DIR/01 && less QUESTION.md"
