#!/usr/bin/env bash
# =============================================================================
# CNPE Security & Policy Enforcement Real Lab
# Scenario: security-hard
#
# Focus:
#   - RBAC namespace/cross-namespace
#   - NetworkPolicy deny-all + allow mirato
#   - Gatekeeper ConstraintTemplate/Constraint
#   - Kyverno mutate/generate
#   - cert-manager selfsigned ClusterIssuer + Certificate
#   - Tekton pipeline security gate con scan/SBOM simulati ma reali come Task
#   - audit/compliance report
#
# Nota:
#   Questo lab evita Istio completo e Trivy Operator per restare stabile su Minikube.
#   Simula security scan/SBOM in Tekton con Task concrete che producono file/report.
#
# Uso:
#   chmod +x setup-security-real.sh
#   ./setup-security-real.sh
#   ./setup-security-real.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-security-real}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-10000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

NS_PAY="payments"
NS_CAT="catalog"
NS_SEC="security"
NS_CI="ci"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi
LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/security-real}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  kubectl delete ns "$NS_PAY" "$NS_CAT" "$NS_SEC" "$NS_CI" --ignore-not-found --timeout=180s 2>/dev/null || true
  kubectl delete ns gatekeeper-system kyverno cert-manager tekton-pipelines --ignore-not-found --timeout=240s 2>/dev/null || true
  kubectl delete constrainttemplate k8srequiredlabels k8srequiredcpulimits k8sdisallowedimages --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredLabels required-labels --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredCpuLimits required-cpu-limits --ignore-not-found 2>/dev/null || true
  kubectl delete K8sDisallowedImages disallowed-images --ignore-not-found 2>/dev/null || true
  kubectl delete clusterpolicy mutate-managed-by generate-deny-all-ns --ignore-not-found 2>/dev/null || true
  kubectl delete clusterissuer security-selfsigned --ignore-not-found 2>/dev/null || true
  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}
[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl helm curl; do have "$c" || die "$c non trovato"; done
mkdir -p "$LAB_DIR"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=45g \
    --kubernetes-version="$K8S_VERSION" \
    --force
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

info "install Gatekeeper"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --wait \
  --timeout=300s \
  --set validatingWebhookConfiguration.timeoutSeconds=15

info "install Kyverno"
kubectl create ns kyverno --dry-run=client -o yaml | kubectl apply -f -
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --wait \
  --timeout=300s

info "install cert-manager"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl -n cert-manager wait --for=condition=Available deployment --all --timeout=300s

info "install Tekton Pipelines"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl -n tekton-pipelines wait --for=condition=Available deployment --all --timeout=300s

for ns in "$NS_PAY" "$NS_CAT" "$NS_SEC" "$NS_CI"; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

cat > "$LAB_DIR/00-apps.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: payments
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog-settings
  namespace: catalog
data:
  feature: "enabled"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: payments
  labels:
    app: postgres
    owner: dba
    environment: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        owner: dba
        environment: prod
    spec:
      containers:
      - name: pg
        image: postgres:16-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: app
        - name: POSTGRES_DB
          value: appdb
        ports:
        - containerPort: 5432
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: payments
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: payments
  labels:
    app: payments-api
    # BUG: manca owner/environment per policy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      serviceAccountName: app-reader
      containers:
      - name: api
        image: nginx:latest
        ports:
        - containerPort: 80
        # BUG: manca limits.cpu
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: payments-api
  namespace: payments
spec:
  type: NodePort
  selector:
    app: payments-api
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30083
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: catalog
  labels:
    app: frontend
    owner: web
    environment: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        owner: web
        environment: prod
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
YAML

cat > "$LAB_DIR/01-rbac-broken.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader-pods
  namespace: payments
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
# BUG: mancano list/watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-pods
  namespace: payments
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: payments
roleRef:
  kind: Role
  name: app-reader-pods
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: catalog-config-reader
  namespace: catalog
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
# BUG: mancano list/watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: catalog-config-reader
  namespace: catalog
subjects:
# BUG: subject namespace errato
- kind: ServiceAccount
  name: app-reader
  namespace: catalog
roleRef:
  kind: Role
  name: catalog-config-reader
  apiGroup: rbac.authorization.k8s.io
YAML

cat > "$LAB_DIR/02-networkpolicy-broken.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payments-deny-all
  namespace: payments
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  # BUG: manca Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-postgres
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: payments-api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    # BUG: porta sbagliata
    - protocol: TCP
      port: 5433
YAML

cat > "$LAB_DIR/03-gatekeeper-broken.yaml" <<'YAML'
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
  name: k8srequiredcpulimits
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredCpuLimits
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredcpulimits

      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        c := input.review.object.spec.containers[_]
        not c.resources.limits.cpu
        msg := sprintf("container %v missing cpu limit", [c.name])
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
            forbidden:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sdisallowedimages

      violation[{"msg": msg}] {
        input.review.kind.kind == "Pod"
        c := input.review.object.spec.containers[_]
        endswith(c.image, "latest")
        msg := sprintf("image %v not allowed", [c.image])
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: required-labels
spec:
  enforcementAction: dryrun
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - payments
  parameters:
    labels:
    - owner
    - environment
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredCpuLimits
metadata:
  name: required-cpu-limits
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - payments
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowedImages
metadata:
  name: disallowed-images
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - payments
  parameters:
    forbidden:
    - latest
    - docker.io/library/*
YAML

cat > "$LAB_DIR/04-kyverno-broken.yaml" <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-managed-by
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: add-managed-by
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          # BUG: namespace errato
          - payment
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            managed-by: kyverno
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-deny-all-ns
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: generate-deny-all
    match:
      any:
      - resources:
          kinds:
          - Namespace
          selector:
            matchLabels:
              # BUG: domanda chiederà team-*; qui usa label che non esiste
              security: managed
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: deny-all
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      data:
        spec:
          podSelector: {}
          policyTypes:
          - Ingress
          - Egress
YAML

cat > "$LAB_DIR/05-certmanager-broken.yaml" <<'YAML'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: security-selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: payments-tls
  namespace: security
spec:
  secretName: payments-tls
  dnsNames:
  - payments-api.payments.svc.cluster.local
  issuerRef:
    # BUG: nome issuer sbagliato
    name: wrong-selfsigned
    kind: ClusterIssuer
YAML

cat > "$LAB_DIR/06-tekton-security-broken.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline
  namespace: ci
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: fake-trivy-scan
  namespace: ci
spec:
  params:
  - name: image
    type: string
  results:
  - name: critical-count
  - name: report-path
  steps:
  - name: scan
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      mkdir -p /tekton/results
      if echo "$(params.image)" | grep -q "latest"; then
        echo 2 | tee "$(results.critical-count.path)"
        echo '{"image":"'"$(params.image)"'","critical":2}' > /tmp/trivy-report.json
      else
        echo 0 | tee "$(results.critical-count.path)"
        echo '{"image":"'"$(params.image)"'","critical":0}' > /tmp/trivy-report.json
      fi
      cat /tmp/trivy-report.json
      echo /tmp/trivy-report.json | tee "$(results.report-path.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: generate-sbom
  namespace: ci
spec:
  params:
  - name: image
    type: string
  results:
  - name: sbom-path
  steps:
  - name: sbom
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      cat > /tmp/sbom.json <<EOF
      {"bomFormat":"CycloneDX","specVersion":"1.5","metadata":{"component":{"name":"$(params.image)"}}}
      EOF
      cat /tmp/sbom.json
      echo /tmp/sbom.json | tee "$(results.sbom-path.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: cosign-verify
  namespace: ci
spec:
  params:
  - name: image
    type: string
  results:
  - name: verified
  steps:
  - name: verify
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      # Simulazione: podinfo verificata, altre immagini no.
      if echo "$(params.image)" | grep -q "podinfo"; then
        echo true | tee "$(results.verified.path)"
      else
        echo false | tee "$(results.verified.path)"
      fi
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: deploy-safe
  namespace: ci
spec:
  params:
  - name: image
    type: string
  - name: critical-count
    type: string
  steps:
  - name: deploy
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      # BUG: deploy parte sempre, anche con critical > 0
      echo "deploying $(params.image) with critical=$(params.critical-count)"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: secure-delivery
  namespace: ci
spec:
  params:
  - name: image
    type: string
    default: nginx:latest
  tasks:
  - name: scan
    taskRef:
      name: fake-trivy-scan
    params:
    - name: image
      value: $(params.image)
  - name: sbom
    taskRef:
      name: generate-sbom
    params:
    - name: image
      value: $(params.image)
  - name: verify
    taskRef:
      name: cosign-verify
    params:
    - name: image
      value: $(params.image)
  - name: deploy
    taskRef:
      name: deploy-safe
    runAfter:
    - scan
    # BUG: dovrebbe dipendere anche da sbom/verify o usare condizioni nel task.
    params:
    - name: image
      value: $(params.image)
    - name: critical-count
      value: $(tasks.scan.results.critical-count)
---
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: secure-delivery-
  namespace: ci
spec:
  serviceAccountName: pipeline
  pipelineRef:
    name: secure-delivery
  params:
  - name: image
    value: nginx:latest
YAML

cat > "$LAB_DIR/07-test-manifests.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: valid-app
  namespace: payments
  labels:
    app: valid-app
    owner: team-a
    environment: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: valid-app
  template:
    metadata:
      labels:
        app: valid-app
        owner: team-a
        environment: prod
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        resources:
          limits:
            cpu: 500m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: invalid-latest
  namespace: payments
  labels:
    app: invalid-latest
    owner: team-a
    environment: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: invalid-latest
  template:
    metadata:
      labels:
        app: invalid-latest
        owner: team-a
        environment: prod
    spec:
      containers:
      - name: web
        image: nginx:latest
        resources:
          limits:
            cpu: 500m
            memory: 128Mi
YAML

kubectl apply -f "$LAB_DIR/00-apps.yaml"
kubectl apply -f "$LAB_DIR/01-rbac-broken.yaml"
kubectl apply -f "$LAB_DIR/02-networkpolicy-broken.yaml"

# Gatekeeper CRDs need time after Helm install
kubectl apply -f "$LAB_DIR/03-gatekeeper-broken.yaml"
sleep 10
for ct in k8srequiredlabels k8srequiredcpulimits k8sdisallowedimages; do
  kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/"$ct" --timeout=180s || true
done

kubectl apply -f "$LAB_DIR/04-kyverno-broken.yaml"
kubectl apply -f "$LAB_DIR/05-certmanager-broken.yaml"
kubectl apply -f "$LAB_DIR/06-tekton-security-broken.yaml"

cat > "$LAB_DIR/README.txt" <<EOF
Scenario: security-real
Namespaces:
  payments
  catalog
  security
  ci

NodePort payments-api:
  http://$(minikube -p "$PROFILE" ip 2>/dev/null):30083

File:
  /course/security-real/00-apps.yaml
  /course/security-real/01-rbac-broken.yaml
  /course/security-real/02-networkpolicy-broken.yaml
  /course/security-real/03-gatekeeper-broken.yaml
  /course/security-real/04-kyverno-broken.yaml
  /course/security-real/05-certmanager-broken.yaml
  /course/security-real/06-tekton-security-broken.yaml
  /course/security-real/07-test-manifests.yaml
EOF

kubectl get ns payments catalog security ci
kubectl -n payments get deploy,svc,networkpolicy
kubectl -n ci get task,pipeline
kubectl get constrainttemplate 2>/dev/null || true
kubectl get clusterpolicy 2>/dev/null || true
ok "Security real lab pronto: $LAB_DIR"
