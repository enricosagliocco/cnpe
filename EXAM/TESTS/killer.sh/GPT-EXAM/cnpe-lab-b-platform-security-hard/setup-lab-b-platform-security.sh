#!/usr/bin/env bash
# =============================================================================
# CNPE Lab B — Platform APIs + Self-Service + Security Hard
#
# Versione corretta/robusta:
#   - Kubernetes default v1.32.0, compatibile con minikube 1.35.x
#   - Le CRD del lab vengono create PRIMA degli addon pesanti
#   - Tekton non blocca tutto il setup se le immagini sono lente
#   - wait più tolleranti e controlli finali espliciti
#
# Uso:
#   chmod +x setup-lab-b-platform-security-fixed.sh
#   ./setup-lab-b-platform-security-fixed.sh
#   ./setup-lab-b-platform-security-fixed.sh --cleanup
# =============================================================================

set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-cnpe-lab-b-platform-security}"
K8S_VERSION="${K8S_VERSION:-v1.32.0}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-12000}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

LAB_NS="platform"
TENANT_NS="tenant-a"
SEC_NS="security"
CI_NS="ci"

CALLER_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
fi

LAB_DIR="${LAB_DIR:-${CALLER_HOME}/course/lab-b-platform-security}"

info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[WARN] $*"; }
die(){ echo "[ERR] $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  warn "cleanup risorse lab"
  kubectl delete ns "$LAB_NS" "$TENANT_NS" "$SEC_NS" "$CI_NS" gatekeeper-system kyverno cert-manager tekton-pipelines tekton-pipelines-resolvers --ignore-not-found --timeout=240s 2>/dev/null || true

  kubectl delete crd \
    platformapps.platform.cnpe.io \
    databaseclaims.platform.cnpe.io \
    --ignore-not-found 2>/dev/null || true

  kubectl delete constrainttemplate \
    k8srequiredlabels \
    k8srequiredresources \
    k8sdisallowedimages \
    --ignore-not-found 2>/dev/null || true

  kubectl delete K8sRequiredLabels required-labels --ignore-not-found 2>/dev/null || true
  kubectl delete K8sRequiredResources required-resources --ignore-not-found 2>/dev/null || true
  kubectl delete K8sDisallowedImages disallowed-images --ignore-not-found 2>/dev/null || true

  kubectl delete clusterpolicy mutate-owner generate-deny-all --ignore-not-found 2>/dev/null || true
  kubectl delete clusterissuer platform-selfsigned --ignore-not-found 2>/dev/null || true

  rm -rf "$LAB_DIR"
  ok "cleanup completato"
  exit 0
}

[ "${1:-}" = "--cleanup" ] && cleanup

for c in minikube kubectl helm curl; do
  have "$c" || die "$c non trovato"
done

mkdir -p "$LAB_DIR"

info "start minikube profile=${PROFILE}, k8s=${K8S_VERSION}"
if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --cpus="$CPUS" \
    --memory="${MEMORY}mb" \
    --disk-size=50g \
    --kubernetes-version="$K8S_VERSION" \
    --force
else
  ok "minikube profile già attivo"
fi

export KUBECONFIG
KUBECONFIG="$(minikube kubeconfig --no-env -p "$PROFILE" 2>/dev/null || echo "$HOME/.kube/config")"
kubectl cluster-info >/dev/null

for ns in "$LAB_NS" "$TENANT_NS" "$SEC_NS" "$CI_NS"; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# =============================================================================
# 00 - CRD PlatformApp + DatabaseClaim
# Nota: PlatformApp è volutamente "broken": manca spec.size.
# Serve per la domanda Q1:
#   Aggiungi spec.size enum small/medium/large.
# =============================================================================

cat > "$LAB_DIR/00-crds-broken.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformapps.platform.cnpe.io
spec:
  group: platform.cnpe.io
  scope: Namespaced
  names:
    plural: platformapps
    singular: platformapp
    kind: PlatformApp
    shortNames:
    - papp
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              replicas:
                type: integer
              # BUG intenzionale per Q1:
              # manca spec.size:
              # size:
              #   type: string
              #   enum:
              #   - small
              #   - medium
              #   - large
              port:
                type: integer
          status:
            type: object
            properties:
              phase:
                type: string
              service:
                type: string
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databaseclaims.platform.cnpe.io
spec:
  group: platform.cnpe.io
  scope: Namespaced
  names:
    plural: databaseclaims
    singular: databaseclaim
    kind: DatabaseClaim
    shortNames:
    - dbclaim
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              engine:
                type: string
              storage:
                type: string
              databaseName:
                type: string
          status:
            type: object
            properties:
              phase:
                type: string
              secretName:
                type: string
    subresources:
      status: {}
YAML

# Applica subito le CRD, così la domanda Q1 funziona anche se addon successivi sono lenti.
kubectl apply -f "$LAB_DIR/00-crds-broken.yaml"
kubectl wait --for=condition=Established crd/platformapps.platform.cnpe.io --timeout=120s
kubectl wait --for=condition=Established crd/databaseclaims.platform.cnpe.io --timeout=120s
ok "CRD lab create"

# =============================================================================
# 01 - RBAC controller volutamente incompleto
# =============================================================================

cat > "$LAB_DIR/01-platform-controller-rbac-broken.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: platform-controller
  namespace: platform
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-controller
rules:
- apiGroups: ["platform.cnpe.io"]
  resources: ["platformapps", "databaseclaims"]
  verbs: ["get", "list", "watch"]
# BUG intenzionale: mancano i permessi su status:
# - apiGroups: ["platform.cnpe.io"]
#   resources: ["platformapps/status", "databaseclaims/status"]
#   verbs: ["get", "patch", "update"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "patch"]
- apiGroups: [""]
  resources: ["services", "secrets"]
  verbs: ["get", "list", "create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-controller
subjects:
- kind: ServiceAccount
  name: platform-controller
  namespace: platform
roleRef:
  kind: ClusterRole
  name: platform-controller
  apiGroup: rbac.authorization.k8s.io
YAML

# =============================================================================
# 02 - Claims volutamente incomplete
# =============================================================================

cat > "$LAB_DIR/02-claims-broken.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: PlatformApp
metadata:
  name: selfservice-api
  namespace: tenant-a
spec:
  image: nginx:latest
  replicas: 1
  port: 80
  # BUG intenzionale: manca size quando Q1 lo aggiunge allo schema.
---
apiVersion: platform.cnpe.io/v1alpha1
kind: DatabaseClaim
metadata:
  name: appdb
  namespace: tenant-a
spec:
  engine: mysql
  storage: 1Gi
  databaseName: appdb
YAML

# =============================================================================
# 03 - Controller Job volutamente incompleto
# =============================================================================

cat > "$LAB_DIR/03-controller-job-broken.yaml" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: reconcile-platformapps
  namespace: platform
spec:
  template:
    spec:
      serviceAccountName: platform-controller
      restartPolicy: Never
      containers:
      - name: reconcile
        image: bitnami/kubectl:1.32
        command: [sh, -c]
        args:
        - |
          set -eu
          for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
            for app in $(kubectl -n "$ns" get platformapps.platform.cnpe.io -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
              image=$(kubectl -n "$ns" get platformapp "$app" -o jsonpath='{.spec.image}')
              replicas=$(kubectl -n "$ns" get platformapp "$app" -o jsonpath='{.spec.replicas}')
              port=$(kubectl -n "$ns" get platformapp "$app" -o jsonpath='{.spec.port}')

              cat <<EOF | kubectl apply -f -
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: $app
            namespace: $ns
            labels:
              app: $app
              owner: platform
              environment: dev
          spec:
            replicas: $replicas
            selector:
              matchLabels:
                app: $app
            template:
              metadata:
                labels:
                  app: $app
                  owner: platform
                  environment: dev
              spec:
                containers:
                - name: app
                  image: $image
                  ports:
                  - containerPort: $port
                  resources:
                    requests:
                      cpu: 50m
                      memory: 64Mi
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: $app
            namespace: $ns
          spec:
            selector:
              app: $app
            ports:
            - port: $port
              targetPort: $port
          EOF

              # BUG intenzionale: status non aggiornato.
            done
          done
YAML

kubectl apply -f "$LAB_DIR/01-platform-controller-rbac-broken.yaml"
kubectl apply -f "$LAB_DIR/02-claims-broken.yaml"
kubectl apply -f "$LAB_DIR/03-controller-job-broken.yaml"

# =============================================================================
# Addon: Gatekeeper
# =============================================================================

info "install Gatekeeper"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --wait \
  --timeout=600s \
  --set validatingWebhookConfiguration.timeoutSeconds=15

# =============================================================================
# Addon: Kyverno
# =============================================================================

info "install Kyverno"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait \
  --timeout=600s

# =============================================================================
# Addon: cert-manager
# =============================================================================

info "install cert-manager"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager --timeout=600s
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-cainjector --timeout=600s
kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-webhook --timeout=600s

# =============================================================================
# Addon: Tekton
# =============================================================================

info "install Tekton"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Non usare "deployment --all" con set -e, perché se il pull immagini è lento
# il lab si interrompe e non applica più le CRD/esercizi.
for dep in tekton-pipelines-controller tekton-pipelines-webhook tekton-events-controller; do
  if kubectl -n tekton-pipelines wait --for=condition=Available "deployment/${dep}" --timeout=900s; then
    ok "Tekton deployment ${dep} Available"
  else
    warn "Tekton deployment ${dep} non ancora Available; continuo comunque il setup"
  fi
done

# =============================================================================
# 04 - Gatekeeper policies volutamente problematiche
# =============================================================================

cat > "$LAB_DIR/04-security-policy-broken.yaml" <<'YAML'
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
        msg := sprintf("missing label %v", [required])
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
        c := input.review.object.spec.template.spec.containers[_]
        not c.resources.limits.cpu
        msg := sprintf("missing cpu limit %v", [c.name])
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
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sdisallowedimages

      violation[{"msg": msg}] {
        input.review.kind.kind == "Deployment"
        c := input.review.object.spec.template.spec.containers[_]
        endswith(c.image, "latest")
        msg := sprintf("latest not allowed: %v", [c.image])
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
    namespaces:
    - tenant-a
  parameters:
    labels: ["owner", "environment"]
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: required-resources
spec:
  enforcementAction: deny
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces:
    - tenant-a
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
    namespaces:
    - tenant-a
YAML

kubectl apply -f "$LAB_DIR/04-security-policy-broken.yaml"

sleep 10
for ct in k8srequiredlabels k8srequiredresources k8sdisallowedimages; do
  kubectl wait --for=jsonpath='{.status.created}'=true constrainttemplate/"$ct" --timeout=180s || true
done

# =============================================================================
# 05 - Kyverno + cert-manager volutamente problematici
# =============================================================================

cat > "$LAB_DIR/05-kyverno-cert-tekton-broken.yaml" <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-owner
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: add-owner
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["tenant-b"]
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            owner: platform
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-deny-all
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: generate-netpol
    match:
      any:
      - resources:
          kinds: ["Namespace"]
          selector:
            matchLabels:
              create-netpol: "true"
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: deny-all
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      data:
        spec:
          podSelector: {}
          policyTypes: ["Ingress", "Egress"]
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: platform-selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: platform-api-tls
  namespace: security
spec:
  secretName: platform-api-tls
  dnsNames:
  - platform-api.platform.svc.cluster.local
  issuerRef:
    name: wrong-issuer
    kind: ClusterIssuer
YAML

kubectl apply -f "$LAB_DIR/05-kyverno-cert-tekton-broken.yaml"

# =============================================================================
# 06 - Tekton security pipeline volutamente problematica
# =============================================================================

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
  name: scan-image
  namespace: ci
spec:
  params:
  - name: image
    type: string
  results:
  - name: critical
  steps:
  - name: scan
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      if echo "$(params.image)" | grep -q "latest"; then
        echo 3 | tee "$(results.critical.path)"
      else
        echo 0 | tee "$(results.critical.path)"
      fi
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
  - name: sbom
  steps:
  - name: sbom
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      echo '{"bomFormat":"CycloneDX","image":"$(params.image)"}' | tee /tmp/sbom.json
      echo /tmp/sbom.json | tee "$(results.sbom.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: deploy-gate
  namespace: ci
spec:
  params:
  - name: critical
    type: string
  steps:
  - name: gate
    image: alpine:3.20
    script: |
      #!/bin/sh
      set -eu
      # BUG intenzionale: non fallisce con critical > 0.
      echo "critical=$(params.critical)"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: platform-security
  namespace: ci
spec:
  params:
  - name: image
    type: string
    default: nginx:latest
  tasks:
  - name: scan
    taskRef:
      name: scan-image
    params:
    - name: image
      value: $(params.image)
  - name: sbom
    taskRef:
      name: generate-sbom
    params:
    - name: image
      value: $(params.image)
  - name: deploy-gate
    taskRef:
      name: deploy-gate
    runAfter:
    - scan
    params:
    - name: critical
      value: $(tasks.scan.results.critical)
---
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: platform-security-
  namespace: ci
spec:
  serviceAccountName: pipeline
  pipelineRef:
    name: platform-security
  params:
  - name: image
    value: nginx:latest
YAML

# Applica Tekton task/pipeline solo se la CRD Task esiste.
if kubectl get crd tasks.tekton.dev >/dev/null 2>&1; then
  kubectl apply -f "$LAB_DIR/06-tekton-security-broken.yaml" || warn "Tekton CR apply fallita; controlla webhook/pods Tekton"
else
  warn "CRD tasks.tekton.dev non trovata; salto 06-tekton-security-broken.yaml"
fi

# =============================================================================
# README
# =============================================================================

cat > "$LAB_DIR/README.txt" <<EOF
CNPE Lab B — Platform APIs + Security

Namespaces:
  platform
  tenant-a
  security
  ci

Files:
  $LAB_DIR/00-crds-broken.yaml
  $LAB_DIR/01-platform-controller-rbac-broken.yaml
  $LAB_DIR/02-claims-broken.yaml
  $LAB_DIR/03-controller-job-broken.yaml
  $LAB_DIR/04-security-policy-broken.yaml
  $LAB_DIR/05-kyverno-cert-tekton-broken.yaml
  $LAB_DIR/06-tekton-security-broken.yaml

Q1:
  kubectl get crd platformapps.platform.cnpe.io
  kubectl edit crd platformapps.platform.cnpe.io

Aggiungere sotto:
  spec.versions[0].schema.openAPIV3Schema.properties.spec.properties

  size:
    type: string
    enum:
    - small
    - medium
    - large
EOF

# =============================================================================
# Final checks
# =============================================================================

echo
info "CHECK CRD platform"
kubectl get crd platformapps.platform.cnpe.io databaseclaims.platform.cnpe.io

echo
info "CHECK custom resources"
kubectl -n tenant-a get platformapp,databaseclaim || true

echo
info "CHECK addons"
kubectl get pods -n gatekeeper-system || true
kubectl get pods -n kyverno || true
kubectl get pods -n cert-manager || true
kubectl get pods -n tekton-pipelines || true

echo
info "CHECK policy resources"
kubectl get constrainttemplate 2>/dev/null || true
kubectl get clusterpolicy 2>/dev/null || true

echo
ok "Lab B pronto: $LAB_DIR"
echo
echo "Per Q1:"
echo "  kubectl edit crd platformapps.platform.cnpe.io"
echo "  kubectl get crd platformapps.platform.cnpe.io -o yaml | grep -A10 size"
