#!/usr/bin/env bash
set -euo pipefail

ARGO_ROLLOUTS_VERSION="${ARGO_ROLLOUTS_VERSION:-v1.9.0}"
COURSE_DIR="${COURSE_DIR:-$HOME/course-argo-rollouts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-argo-rollouts-lab}"
LAB_NAMESPACE="${LAB_NAMESPACE:-argo-rollouts-lab}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
    kind)
      command -v kind >/dev/null || die "kind is required"
      if ! kind get clusters 2>/dev/null | grep -Fxq "$KIND_CLUSTER_NAME"; then
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

command -v kubectl >/dev/null || die "kubectl is required"
ensure_cluster
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi
if [ "$LAB_FORCE" = "true" ]; then
  kubectl delete namespace "$LAB_NAMESPACE" --ignore-not-found --wait=true
  rm -rf "$COURSE_DIR"
fi

info "Installing Argo Rollouts ${ARGO_ROLLOUTS_VERSION}"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argo-rollouts -f \
  "https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml" >/dev/null
kubectl -n argo-rollouts rollout status deployment/argo-rollouts --timeout=300s
kubectl create namespace "$LAB_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done

cat > "$COURSE_DIR/01/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: basic-api
  namespace: argo-rollouts-lab
spec:
  replicas: 3
  selector: {} # TODO app=basic-api
  template:
    metadata:
      labels: {} # TODO matching label
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
  strategy:
    canary: {}
YAML

cat > "$COURSE_DIR/02/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: stepped-api
  namespace: argo-rollouts-lab
spec:
  replicas: 5
  selector:
    matchLabels:
      app: stepped-api
  template:
    metadata:
      labels:
        app: stepped-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      steps: [] # TODO 20, pause 10s, 50, manual pause, 100
YAML

cat > "$COURSE_DIR/03/services.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: canary-stable
  namespace: argo-rollouts-lab
spec:
  selector:
    app: canary-api
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: canary-preview
  namespace: argo-rollouts-lab
spec:
  selector:
    app: canary-api
  ports:
    - port: 80
      targetPort: 80
YAML
cat > "$COURSE_DIR/03/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-api
  namespace: argo-rollouts-lab
spec:
  replicas: 4
  selector:
    matchLabels:
      app: canary-api
  template:
    metadata:
      labels:
        app: canary-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      stableService: TODO
      canaryService: TODO
      steps:
        - setWeight: 25
        - pause: {}
YAML

for q in 04 05 06; do
  cp "$COURSE_DIR/03/services.yaml" "$COURSE_DIR/$q/services.yaml"
  cp "$COURSE_DIR/03/rollout.yaml" "$COURSE_DIR/$q/rollout.yaml"
  touch "$COURSE_DIR/$q/evidence.txt"
done

cat > "$COURSE_DIR/07/services.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-active
  namespace: argo-rollouts-lab
spec:
  selector:
    app: bluegreen-api
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-preview
  namespace: argo-rollouts-lab
spec:
  selector:
    app: bluegreen-api
  ports:
    - port: 80
      targetPort: 80
YAML
cat > "$COURSE_DIR/07/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bluegreen-api
  namespace: argo-rollouts-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bluegreen-api
  template:
    metadata:
      labels:
        app: bluegreen-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    blueGreen:
      activeService: TODO
      previewService: TODO
      autoPromotionEnabled: true # TODO false
      scaleDownDelaySeconds: 0 # TODO 30
YAML
for q in 08 09; do
  cp "$COURSE_DIR/07/services.yaml" "$COURSE_DIR/$q/services.yaml"
  cp "$COURSE_DIR/07/rollout.yaml" "$COURSE_DIR/$q/rollout.yaml"
  touch "$COURSE_DIR/$q/evidence.txt"
done

cat > "$COURSE_DIR/10/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: preview-check
  namespace: argo-rollouts-lab
spec:
  metrics:
    - name: smoke
      successCondition: result == 0
      provider:
        job:
          spec:
            template:
              spec:
                restartPolicy: Never
                containers:
                  - name: check
                    image: alpine:3.20
                    command: [sh, -c]
                    args: ["exit 0"]
YAML
cp "$COURSE_DIR/07/services.yaml" "$COURSE_DIR/10/services.yaml"
cat > "$COURSE_DIR/10/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: analyzed-bluegreen
  namespace: argo-rollouts-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: analyzed-bluegreen
  template:
    metadata:
      labels:
        app: analyzed-bluegreen
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    blueGreen:
      activeService: bluegreen-active
      previewService: bluegreen-preview
      autoPromotionEnabled: false
      prePromotionAnalysis: {} # TODO preview-check
YAML

cp "$COURSE_DIR/10/analysis-template.yaml" "$COURSE_DIR/11/analysis-template.yaml"
cp "$COURSE_DIR/10/rollout.yaml" "$COURSE_DIR/11/rollout.yaml"
cp "$COURSE_DIR/07/services.yaml" "$COURSE_DIR/11/services.yaml"

cat > "$COURSE_DIR/12/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: background-check
  namespace: argo-rollouts-lab
spec:
  metrics:
    - name: health
      interval: 10s
      count: 5
      successCondition: result == 0
      provider:
        job:
          spec:
            template:
              spec:
                restartPolicy: Never
                containers:
                  - name: check
                    image: alpine:3.20
                    command: [sh, -c]
                    args: ["exit 0"]
YAML
cat > "$COURSE_DIR/12/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: background-api
  namespace: argo-rollouts-lab
spec:
  replicas: 5
  selector:
    matchLabels:
      app: background-api
  template:
    metadata:
      labels:
        app: background-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      analysis: {} # TODO template and startingStep 1
      steps:
        - setWeight: 20
        - pause:
            duration: 10s
        - setWeight: 60
        - pause: {}
YAML

cat > "$COURSE_DIR/13/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: metric-lab
  namespace: argo-rollouts-lab
spec:
  metrics:
    - name: exit-code
      count: 1 # TODO 3
      interval: 5s
      failureLimit: 0 # TODO 1
      successCondition: TODO
      provider:
        job:
          spec:
            template:
              spec:
                restartPolicy: Never
                containers:
                  - name: metric
                    image: alpine:3.20
                    command: [sh, -c]
                    args: ["exit 0"]
YAML

cat > "$COURSE_DIR/14/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: argument-check
  namespace: argo-rollouts-lab
spec:
  args:
    - name: service-name
    - name: target-version
  metrics:
    - name: show-arguments
      provider:
        job:
          spec:
            template:
              spec:
                restartPolicy: Never
                containers:
                  - name: check
                    image: alpine:3.20
                    command: [echo]
                    args: ["{{args.service-name}} {{args.target-version}}"]
YAML
cat > "$COURSE_DIR/14/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: argument-api
  namespace: argo-rollouts-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: argument-api
  template:
    metadata:
      labels:
        app: argument-api
        version: v1
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      steps:
        - setWeight: 20
        - analysis:
            templates:
              - templateName: argument-check
            args: [] # TODO service-name and target-version from fieldRef
YAML

cat > "$COURSE_DIR/15/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: inconclusive-check
  namespace: argo-rollouts-lab
spec:
  metrics:
    - name: uncertain
      interval: 10s
      count: 5
      successCondition: result == 0
      failureCondition: result > 1
      failureLimit: 0 # TODO
      inconclusiveLimit: 0 # TODO
      provider:
        job:
          spec:
            template:
              spec:
                restartPolicy: Never
                containers:
                  - name: check
                    image: alpine:3.20
                    command: [sh, -c]
                    args: ["exit 1"]
YAML

cat > "$COURSE_DIR/16/experiment.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Experiment
metadata:
  name: api-comparison
  namespace: argo-rollouts-lab
spec:
  duration: 30s # TODO 2m
  templates: [] # TODO baseline and canary, one replica each
  analyses: [] # TODO optional analysis
YAML

cat > "$COURSE_DIR/17/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: anti-affinity-api
  namespace: argo-rollouts-lab
spec:
  replicas: 4
  selector:
    matchLabels:
      app: anti-affinity-api
  template:
    metadata:
      labels:
        app: anti-affinity-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      antiAffinity: {} # TODO preferredDuringSchedulingIgnoredDuringExecution
      steps:
        - setWeight: 50
        - pause: {}
YAML

cat > "$COURSE_DIR/18/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scaling-api
  namespace: argo-rollouts-lab
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scaling-api
  template:
    metadata:
      labels:
        app: scaling-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      abortScaleDownDelaySeconds: 0 # TODO
      scaleDownDelayRevisionLimit: 0 # TODO
      dynamicStableScale: false # TODO
      steps:
        - setWeight: 50
        - pause: {}
YAML

cat > "$COURSE_DIR/19/services.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: broken-stable
  namespace: argo-rollouts-lab
spec:
  selector:
    app: another-app
  ports:
    - port: 80
YAML
cat > "$COURSE_DIR/19/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: broken-api
  namespace: argo-rollouts-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: broken-api
  template:
    metadata:
      labels:
        app: wrong-label
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      stableService: missing-service
      canaryService: broken-stable
YAML
touch "$COURSE_DIR/19/report.md"

cat > "$COURSE_DIR/20/services.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: final-stable
  namespace: argo-rollouts-lab
spec:
  selector:
    app: final-api
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: final-canary
  namespace: argo-rollouts-lab
spec:
  selector:
    app: final-api
  ports:
    - port: 80
      targetPort: 80
YAML
cat > "$COURSE_DIR/20/analysis-template.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: final-analysis
  namespace: argo-rollouts-lab
spec:
  metrics: [] # TODO background health metric
YAML
cat > "$COURSE_DIR/20/rollout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: final-api
  namespace: argo-rollouts-lab
spec:
  replicas: 10
  selector:
    matchLabels:
      app: final-api
  template:
    metadata:
      labels:
        app: final-api
    spec:
      containers:
        - name: api
          image: nginx:1.27-alpine
  strategy:
    canary:
      stableService: TODO
      canaryService: TODO
      analysis: {} # TODO
      steps: [] # TODO 10, 30, 60, manual pause, 100
YAML
touch "$COURSE_DIR/20/final-report.md"

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
info "Argo Rollouts lab ready: $COURSE_DIR"
info "Status: kubectl -n $LAB_NAMESPACE get rollouts"
