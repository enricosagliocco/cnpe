#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-platform-automation}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
INSTALL_TOOLS="${INSTALL_TOOLS:-true}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-platform-automation}"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.22.2}"
CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-2.3.1}"
TEKTON_VERSION="${TEKTON_VERSION:-v1.9.0}"
TEKTON_TRIGGERS_VERSION="${TEKTON_TRIGGERS_VERSION:-v0.33.0}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.1}"
KEDA_CHART_VERSION="${KEDA_CHART_VERSION:-2.18.1}"
CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      require kind
      if kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        info "Using existing kind cluster: $KIND_CLUSTER_NAME"
      else
        info "Creating three-node kind cluster: $KIND_CLUSTER_NAME"
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s --config - <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      if ! kubectl -n kube-system get daemonset calico-node >/dev/null 2>&1; then
        kubectl -n kube-system get daemonset kindnet >/dev/null 2>&1 &&
          die "Existing kind cluster uses kindnet; recreate $KIND_CLUSTER_NAME"
        info "Installing Calico ${CALICO_VERSION}"
        kubectl apply -f \
          "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
          >/dev/null
        kubectl -n kube-system rollout status daemonset/calico-node --timeout=300s
      fi
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        require minikube
        minikube start --nodes=2 --cpus=3 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a Kubernetes cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

install_tools() {
  info "Installing Gatekeeper ${GATEKEEPER_VERSION}"
  kubectl apply -f \
    "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml" \
    >/dev/null
  kubectl -n gatekeeper-system rollout status \
    deployment/gatekeeper-controller-manager --timeout=300s

  info "Installing Crossplane ${CROSSPLANE_VERSION}"
  helm repo add crossplane-stable https://charts.crossplane.io/stable \
    --force-update >/dev/null
  helm upgrade --install crossplane crossplane-stable/crossplane \
    --version "$CROSSPLANE_VERSION" \
    --namespace crossplane-system --create-namespace \
    --wait --timeout 8m >/dev/null
  kubectl apply -f - <<'YAML'
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
YAML
  kubectl wait --for=condition=Healthy \
    function/function-patch-and-transform --timeout=300s

  info "Installing Tekton Pipelines and Triggers"
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml" \
    >/dev/null
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/release.yaml" \
    >/dev/null
  kubectl apply -f \
    "https://infra.tekton.dev/tekton-releases/triggers/previous/${TEKTON_TRIGGERS_VERSION}/interceptors.yaml" \
    >/dev/null
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-pipelines-controller --timeout=300s
  kubectl -n tekton-pipelines rollout status \
    deployment/tekton-triggers-controller --timeout=300s

  info "Installing Metrics Server ${METRICS_SERVER_VERSION}"
  kubectl apply -f \
    "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" \
    >/dev/null
  if [ "$CLUSTER_PROVIDER" = "kind" ]; then
    kubectl -n kube-system patch deployment metrics-server --type json \
      -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
      >/dev/null 2>&1 || true
  fi
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=300s

  info "Installing KEDA ${KEDA_CHART_VERSION}"
  helm repo add kedacore https://kedacore.github.io/charts \
    --force-update >/dev/null
  helm upgrade --install keda kedacore/keda \
    --version "$KEDA_CHART_VERSION" \
    --namespace keda --create-namespace \
    --wait --timeout 5m >/dev/null
}

require kubectl
require helm
require curl
ensure_cluster

node_count="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"
[ "$node_count" -ge 2 ] || die "This lab requires at least two nodes"

if [ "$INSTALL_TOOLS" = "true" ]; then
  install_tools
else
  kubectl get crd constrainttemplates.templates.gatekeeper.sh >/dev/null
  kubectl get crd compositeresourcedefinitions.apiextensions.crossplane.io >/dev/null
  kubectl get crd eventlisteners.triggers.tekton.dev >/dev/null
  kubectl get crd scaledobjects.keda.sh >/dev/null
  kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null
fi

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  for ns in policy-apps platform-apps tekton-events observability \
    team-a team-b network-app network-client scheduling-lab helm-apps \
    storage-lab autoscaling-lab; do
    kubectl delete namespace "$ns" --ignore-not-found --wait=true
  done
  kubectl delete pv platform-local-pv --ignore-not-found
  kubectl delete storageclass platform-local --ignore-not-found
  kubectl delete constrainttemplate deploymentstandards --ignore-not-found
  kubectl delete deploymentstandards.constraints.gatekeeper.sh \
    deployment-standards --ignore-not-found
  kubectl delete composition webapp --ignore-not-found
  kubectl delete crd webapps.platform.cnpe.io --ignore-not-found
  rm -rf "$COURSE_DIR"
fi

mkdir -p "$COURSE_DIR"
for number in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$number"; done
for ns in policy-apps platform-apps tekton-events observability team-a team-b \
  network-app network-client scheduling-lab helm-apps storage-lab \
  autoscaling-lab; do
  kubectl create namespace "$ns" --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
done

# Q1-Q2 Gatekeeper
cat > "$COURSE_DIR/01/template.yaml" <<'YAML'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: deploymentstandards
spec:
  crd:
    spec:
      names:
        kind: DeploymentStandards
      validation:
        openAPIV3Schema:
          type: object
          properties:
            minReplicas:
              type: integer
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package deploymentstandards

        # TODO deny Deployment without metadata.labels.owner
        # TODO deny Deployment with replicas lower than minReplicas
YAML
cat > "$COURSE_DIR/01/constraint.yaml" <<'YAML'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DeploymentStandards
metadata:
  name: deployment-standards
spec:
  enforcementAction: deny
  match:
    namespaces: [] # TODO policy-apps
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters:
    minReplicas: 1 # TODO 2
YAML
cat > "$COURSE_DIR/01/invalid-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: policy-apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
YAML
touch "$COURSE_DIR/01/gatekeeper-check.txt"

# Q3-Q4 Crossplane
cat > "$COURSE_DIR/02/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: TODO
spec:
  scope: TODO
  group: TODO
  names:
    kind: TODO
    plural: TODO
  versions:
    - name: v1alpha1
      served: TODO
      referenceable: TODO
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties: {} # TODO image and replicas
YAML
cat > "$COURSE_DIR/02/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: webapp
spec:
  compositeTypeRef:
    apiVersion: platform.cnpe.io/v1alpha1
    kind: WebApp
  mode: Pipeline
  pipeline:
    - step: compose
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources: [] # TODO Deployment and Service
YAML
cat > "$COURSE_DIR/02/webapp.yaml" <<'YAML'
apiVersion: platform.cnpe.io/v1alpha1
kind: WebApp
metadata:
  name: storefront
  namespace: platform-apps
spec:
  image: nginx:1.27-alpine
  replicas: 2
YAML
touch "$COURSE_DIR/02/crossplane-check.txt"

# Q5-Q6 Tekton Triggers
cat > "$COURSE_DIR/03/pipeline.yaml" <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: webhook-build
  namespace: tekton-events
spec:
  params:
    - name: repository
      type: string
    - name: revision
      type: string
  tasks:
    - name: report
      taskSpec:
        params:
          - name: repository
          - name: revision
        steps:
          - name: report
            image: alpine:3.20
            script: |
              #!/bin/sh
              echo "repository=$(params.repository) revision=$(params.revision)"
      params:
        - name: repository
          value: $(params.repository)
        - name: revision
          value: $(params.revision)
YAML
cat > "$COURSE_DIR/03/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-trigger
  namespace: tekton-events
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tekton-trigger
  namespace: tekton-events
rules:
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns"]
    verbs: ["create"]
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["triggerbindings", "triggertemplates"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tekton-trigger
  namespace: tekton-events
subjects:
  - kind: ServiceAccount
    name: tekton-trigger
    namespace: tekton-events
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tekton-trigger
YAML
cat > "$COURSE_DIR/03/triggers.yaml" <<'YAML'
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: git-push
  namespace: tekton-events
spec:
  params:
    - name: repository
      value: TODO
    - name: revision
      value: TODO
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: git-push
  namespace: tekton-events
spec:
  params:
    - name: repository
    - name: revision
  resourcetemplates: [] # TODO PipelineRun
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: git-push
  namespace: tekton-events
spec:
  serviceAccountName: tekton-trigger
  triggers:
    - name: main-push
      interceptors: [] # TODO CEL body.ref main
      bindings:
        - ref: git-push
      template:
        ref: git-push
YAML
cat > "$COURSE_DIR/03/payload-main.json" <<'JSON'
{"ref":"refs/heads/main","after":"abc123","repository":{"name":"portal"}}
JSON
cat > "$COURSE_DIR/03/payload-feature.json" <<'JSON'
{"ref":"refs/heads/feature","after":"def456","repository":{"name":"portal"}}
JSON
kubectl apply -f "$COURSE_DIR/03/pipeline.yaml" >/dev/null
touch "$COURSE_DIR/03/tekton-check.txt"

# Q7-Q8 OpenTelemetry Collector
cat > "$COURSE_DIR/04/collector-config.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector
  namespace: observability
data:
  config.yaml: |
    receivers: {} # TODO otlp grpc/http
    processors: {} # TODO batch
    exporters: {} # TODO debug
    service:
      pipelines: {} # TODO traces
YAML
cat > "$COURSE_DIR/04/collector.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: observability
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:0.134.0
          args: ["--config=/etc/otel/config.yaml"]
          ports:
            - {name: otlp-grpc, containerPort: 4317}
            - {name: otlp-http, containerPort: 4318}
          volumeMounts:
            - {name: config, mountPath: /etc/otel}
      volumes:
        - name: config
          configMap:
            name: otel-collector
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: observability
spec:
  selector:
    app: otel-collector
  ports:
    - {name: otlp-grpc, port: 4317, targetPort: 4317}
    - {name: otlp-http, port: 4318, targetPort: 4318}
YAML
cat > "$COURSE_DIR/04/telemetrygen-job.yaml" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: telemetrygen
  namespace: observability
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: telemetrygen
          image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.134.0
          args:
            - traces
            - --otlp-endpoint=otel-collector:4317
            - --otlp-insecure
            - --service=checkout
            - --traces=20
YAML
touch "$COURSE_DIR/04/otel-check.txt"

# Q9-Q10 RBAC
cat > "$COURSE_DIR/05/rbac.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: release-bot
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: release-bot
  namespace: team-a
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list"] # TODO update and patch web only
  # TODO pods and pods/log read-only
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: release-bot
  namespace: team-a
subjects:
  - kind: ServiceAccount
    name: release-bot
    namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: release-bot
YAML
for app in web worker; do
  kubectl -n team-a create deployment "$app" --image=nginx:1.27-alpine \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
touch "$COURSE_DIR/05/rbac-check.txt"

# Q11-Q12 NetworkPolicy
kubectl label namespace network-client access=frontend --overwrite >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: network-app
spec:
  replicas: 1
  selector:
    matchLabels: {app: backend}
  template:
    metadata:
      labels: {app: backend}
    spec:
      containers:
        - name: server
          image: python:3.12-alpine
          command: ["python", "-m", "http.server", "8080"]
          ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: network-app
spec:
  selector: {app: backend}
  ports: [{port: 8080, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: network-client
  labels: {app: frontend}
spec:
  containers:
    - name: client
      image: curlimages/curl:8.11.1
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: intruder
  namespace: network-client
  labels: {app: intruder}
spec:
  containers:
    - name: client
      image: curlimages/curl:8.11.1
      command: ["sh", "-c", "sleep 3600"]
YAML
cat > "$COURSE_DIR/06/networkpolicy.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-default-deny
  namespace: network-app
spec:
  podSelector:
    matchLabels: {app: backend}
  policyTypes: [Ingress]
  ingress: [] # TODO frontend only on 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: client-egress
  namespace: network-client
spec:
  podSelector:
    matchLabels: {app: frontend}
  policyTypes: [Egress]
  egress: [] # TODO DNS and backend only
YAML
kubectl apply -f "$COURSE_DIR/06/networkpolicy.yaml" >/dev/null
touch "$COURSE_DIR/06/network-check.txt"

# Q13-Q14 Scheduling
workers=($(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'))
[ "${#workers[@]}" -ge 1 ] || workers=($(kubectl get nodes -o name | sed 's#node/##'))
dedicated_node="${workers[0]}"
kubectl label node "$dedicated_node" workload.cnpe.io/tier=dedicated --overwrite >/dev/null
kubectl taint node "$dedicated_node" dedicated=platform:NoSchedule --overwrite >/dev/null
cat > "$COURSE_DIR/07/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-api
  namespace: scheduling-lab
spec:
  replicas: 2
  selector:
    matchLabels: {app: platform-api}
  template:
    metadata:
      labels: {app: platform-api}
    spec:
      tolerations: [] # TODO dedicated=platform:NoSchedule
      affinity: {} # TODO required node affinity and preferred pod anti-affinity
      containers:
        - name: api
          image: nginx:1.27-alpine
YAML
printf '%s\n' "$dedicated_node" > "$COURSE_DIR/07/node.txt"
touch "$COURSE_DIR/07/scheduling-check.txt"

# Q15-Q16 Helm
mkdir -p "$COURSE_DIR/08/app-chart/templates"
cat > "$COURSE_DIR/08/app-chart/Chart.yaml" <<'YAML'
apiVersion: v2
name: app-chart
description: CNPE Helm exercise
type: application
version: 0.1.0
appVersion: "1.27.3"
YAML
cat > "$COURSE_DIR/08/app-chart/values.yaml" <<'YAML'
replicaCount: 2
image:
  repository: nginx
  tag: 1.27.3-alpine
service:
  port: 80
YAML
cat > "$COURSE_DIR/08/app-chart/templates/_helpers.tpl" <<'TPL'
{{- define "app-chart.labels" -}}
app.kubernetes.io/name: TODO
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
TPL
cat > "$COURSE_DIR/08/app-chart/templates/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: portal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portal
  template:
    metadata:
      labels:
        app: portal
    spec:
      containers:
        - name: portal
          image: nginx:latest
          ports:
            - containerPort: 80
YAML
cat > "$COURSE_DIR/08/app-chart/templates/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  selector:
    app: portal
  ports:
    - port: 80
      targetPort: 80
YAML
touch "$COURSE_DIR/08/helm-check.txt"

# Q17-Q18 Storage
storage_node="$dedicated_node"
cat > "$COURSE_DIR/09/storage.yaml" <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: platform-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate # TODO
reclaimPolicy: Delete # TODO
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: platform-local-pv
spec:
  capacity: {storage: 2Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: platform-local
  local:
    path: /tmp/platform-automation-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: [TODO_NODE]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: storage-lab
spec:
  accessModes: [] # TODO
  storageClassName: TODO
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-writer
  namespace: storage-lab
spec:
  tolerations:
    - key: dedicated
      operator: Equal
      value: platform
      effect: NoSchedule
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - {name: data, mountPath: /data}
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data
YAML
printf '%s\n' "$storage_node" > "$COURSE_DIR/09/node.txt"
touch "$COURSE_DIR/09/storage-check.txt"

# Q19-Q20 HPA and KEDA
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: autoscaling-lab
spec:
  replicas: 1
  selector:
    matchLabels: {app: api}
  template:
    metadata:
      labels: {app: api}
    spec:
      containers:
        - name: api
          image: registry.k8s.io/hpa-example:latest
          resources:
            requests: {cpu: 100m, memory: 32Mi}
            limits: {cpu: 500m, memory: 64Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: autoscaling-lab
spec:
  selector: {app: api}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: autoscaling-lab
spec:
  replicas: 1
  selector:
    matchLabels: {app: worker}
  template:
    metadata:
      labels: {app: worker}
    spec:
      containers:
        - name: worker
          image: registry.k8s.io/hpa-example:latest
          resources:
            requests: {cpu: 100m, memory: 32Mi}
            limits: {cpu: 500m, memory: 64Mi}
YAML
cat > "$COURSE_DIR/10/hpa.yaml" <<'YAML'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
  namespace: autoscaling-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: wrong-api
  minReplicas: 2
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 90
YAML
cat > "$COURSE_DIR/10/scaledobject.yaml" <<'YAML'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker
  namespace: autoscaling-lab
spec:
  scaleTargetRef:
    name: TODO
  minReplicaCount: 0
  maxReplicaCount: 1
  pollingInterval: 30
  cooldownPeriod: 300
  triggers: [] # TODO cpu utilization 40
YAML
cat > "$COURSE_DIR/10/load-generator.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  namespace: autoscaling-lab
spec:
  containers:
    - name: load
      image: busybox:1.36
      command:
        - sh
        - -c
        - while true; do wget -q -O- http://api; done
YAML
touch "$COURSE_DIR/10/autoscaling-check.txt"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "Platform Automation Lab ready: $COURSE_DIR"
info "Tekton EventListener test: port-forward its generated Service, then POST the payload files"
