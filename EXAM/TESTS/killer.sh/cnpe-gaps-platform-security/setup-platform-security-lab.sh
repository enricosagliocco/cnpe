#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-platform-security}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  echo "$COURSE_DIR already initialized; use LAB_FORCE=true"; exit 1
fi
mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
for ns in tenant-a team-payments; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

if [ "$INSTALL_TOOLS" = "true" ]; then
  command -v helm >/dev/null || { echo "helm is required"; exit 1; }
  kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.22.2/deploy/gatekeeper.yaml
  kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=300s
  helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install crossplane crossplane-stable/crossplane -n crossplane-system --create-namespace --wait
fi

cat > "$COURSE_DIR/01/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: databaseclaims.platform.example.io}
spec:
  group: platform.example.io
  scope: Namespaced
  names: {plural: databaseclaims, singular: databaseclaim, kind: DatabaseClaim}
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec: {type: object, properties: {}} # TODO
YAML
cat > "$COURSE_DIR/01/valid.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: DatabaseClaim
metadata: {name: orders, namespace: tenant-a}
spec: {engine: postgres, storageGi: 10}
YAML
cat > "$COURSE_DIR/01/invalid.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: DatabaseClaim
metadata: {name: broken, namespace: tenant-a}
spec: {engine: oracle, storageGi: 0, extra: true}
YAML
for n in 02 03 04; do cp "$COURSE_DIR/01/crd.yaml" "$COURSE_DIR/$n/crd.yaml"; done
cp "$COURSE_DIR/01/valid.yaml" "$COURSE_DIR/03/cache.yaml"
touch "$COURSE_DIR/03/result.txt"

cat > "$COURSE_DIR/05/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: appenvironments.platform.example.io}
spec:
  scope: TODO
  group: platform.example.io
  names: {kind: AppEnvironment, plural: appenvironments}
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec: {type: object, properties: {}} # TODO
YAML
cat > "$COURSE_DIR/06/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: app-environment}
spec:
  compositeTypeRef: {apiVersion: platform.example.io/v1alpha1, kind: AppEnvironment}
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef: {name: function-patch-and-transform}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: environment-config
            base:
              apiVersion: v1
              kind: ConfigMap
              metadata: {name: environment-config}
              data: {}
            patches: [] # TODO
YAML
for n in 07 08; do cp "$COURSE_DIR/06/composition.yaml" "$COURSE_DIR/$n/composition.yaml"; done
cat > "$COURSE_DIR/09/xr.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: AppEnvironment
metadata: {name: TODO, namespace: TODO}
spec: {team: TODO, environment: TODO}
YAML
touch "$COURSE_DIR/09/result.txt"

cat > "$COURSE_DIR/10/quota.yaml" <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata: {name: tenant-budget, namespace: tenant-a}
spec: {hard: {}} # TODO
YAML
cat > "$COURSE_DIR/11/limitrange.yaml" <<'YAML'
apiVersion: v1
kind: LimitRange
metadata: {name: tenant-defaults, namespace: tenant-a}
spec: {limits: []} # TODO
YAML
cat > "$COURSE_DIR/11/pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: defaults-demo, namespace: tenant-a}
spec: {containers: [{name: app, image: registry.k8s.io/pause:3.10}]}
YAML
cat > "$COURSE_DIR/12/policies.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: tenant-a}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
---
# TODO frontend-to-backend:8080 and DNS egress
YAML
cat > "$COURSE_DIR/13/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata: {name: tenant-admin, namespace: tenant-a}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: tenant-admin, namespace: tenant-a}
rules: [] # TODO
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: tenant-admin, namespace: tenant-a}
subjects: [] # TODO
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: tenant-admin}
YAML
touch "$COURSE_DIR/13/checks.txt"
cat > "$COURSE_DIR/14/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: restricted-app, namespace: tenant-a}
spec:
  replicas: 1
  selector: {matchLabels: {app: restricted-app}}
  template:
    metadata: {labels: {app: restricted-app}}
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: [sh, -c, "sleep 3600"]
          securityContext: {privileged: true}
YAML

cat > "$COURSE_DIR/15/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: requiredannotations}
spec:
  crd:
    spec:
      names: {kind: RequiredAnnotations}
      validation: {openAPIV3Schema: {}} # TODO
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredannotations
        # TODO
YAML
cat > "$COURSE_DIR/15/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredAnnotations
metadata: {name: tenant-owner}
spec: {} # TODO
YAML
cat > "$COURSE_DIR/15/bad.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: no-owner, namespace: tenant-a}
spec:
  replicas: 1
  selector: {matchLabels: {app: no-owner}}
  template:
    metadata: {labels: {app: no-owner}}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
YAML
cat > "$COURSE_DIR/15/good.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: has-owner
  namespace: tenant-a
  annotations: {owner: platform-team}
spec:
  replicas: 1
  selector: {matchLabels: {app: has-owner}}
  template:
    metadata: {labels: {app: has-owner}}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
YAML
cat > "$COURSE_DIR/16/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: allowedrepos}
spec:
  crd:
    spec:
      names: {kind: AllowedRepos}
      validation: {openAPIV3Schema: {type: object, properties: {repos: {type: array, items: {type: string}}}}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package allowedrepos
        # TODO containers and initContainers
YAML
cat > "$COURSE_DIR/16/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata: {name: tenant-allowed-repos}
spec:
  enforcementAction: deny
  match:
    namespaces: ["tenant-a"]
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    repos: ["registry.k8s.io/"]
YAML
cat > "$COURSE_DIR/16/bad.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: disallowed-init, namespace: tenant-a}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile: {type: RuntimeDefault}
  initContainers:
    - name: init
      image: docker.io/library/busybox:1.36
      command: [sh, -c, "true"]
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
YAML
cat > "$COURSE_DIR/16/good.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: allowed-images, namespace: tenant-a}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile: {type: RuntimeDefault}
  initContainers:
    - name: init
      image: registry.k8s.io/pause:3.10
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
YAML
touch "$COURSE_DIR/17/audit.txt"
cat > "$COURSE_DIR/17/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: requiredlabels}
spec:
  crd:
    spec:
      names: {kind: RequiredLabels}
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels: {type: array, items: {type: string}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing labels: %v", [missing])
        }
YAML
cat > "$COURSE_DIR/17/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata: {name: tenant-cost-center}
spec:
  enforcementAction: dryrun
  match:
    namespaces: ["tenant-a"]
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters: {labels: ["cost-center"]}
YAML
cat > "$COURSE_DIR/18/sbom.json" <<'JSON'
{"spdxVersion":"SPDX-2.3","packages":[{"name":"demo","licenseConcluded":"NOASSERTION"}]}
JSON
cat > "$COURSE_DIR/18/pipeline-policy.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: verify-sbom}
spec:
  steps:
    - name: verify
      image: mikefarah/yq:4
      script: |-
        #!/bin/sh
        # TODO validate /workspace/sbom.json
YAML
cat > "$COURSE_DIR/19/usage.csv" <<'CSV'
sample,cpu_m,memory_mi
1,110,180
2,140,210
3,170,240
4,190,260
5,220,280
CSV
cat > "$COURSE_DIR/19/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: right-sized, namespace: tenant-a}
spec:
  replicas: 2
  selector: {matchLabels: {app: right-sized}}
  template:
    metadata: {labels: {app: right-sized}}
    spec:
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
          resources: {} # TODO
YAML
touch "$COURSE_DIR/19/calculation.txt" "$COURSE_DIR/20/report.md"
touch "$COURSE_DIR/.initialized"
echo "Platform APIs and Security lab ready: $COURSE_DIR"
