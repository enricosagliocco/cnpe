#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-resource-governance}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
NAMESPACE="resource-governance"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  die "$COURSE_DIR already initialized; use LAB_FORCE=true"
fi

if [ "$LAB_FORCE" = "true" ]; then
  info "Removing previously generated files"
  rm -rf "$COURSE_DIR"
fi

mkdir -p "$COURSE_DIR/q01"

cat > "$COURSE_DIR/q01/base-resources.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: resource-governance
---
apiVersion: v1
kind: LimitRange
metadata:
  name: container-policy
  namespace: resource-governance
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 300m
        memory: 256Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: 500m
        memory: 512Mi
      maxLimitRequestRatio:
        cpu: "4"
        memory: "2"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-budget
  namespace: resource-governance
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "5"
    services: "2"
    configmaps: "3"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-settings
  namespace: resource-governance
data:
  mode: stable
---
apiVersion: v1
kind: Service
metadata:
  name: platform-api
  namespace: resource-governance
spec:
  selector:
    app: platform-api
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: worker-headless
  namespace: resource-governance
spec:
  clusterIP: None
  selector:
    app: batch
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-api
  namespace: resource-governance
spec:
  replicas: 2
  selector:
    matchLabels:
      app: platform-api
  template:
    metadata:
      labels:
        app: platform-api
    spec:
      containers:
        - name: api
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args:
            - netexec
            - --http-port=8080
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 400m
              memory: 512Mi
YAML

cat > "$COURSE_DIR/q01/defaulted-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: defaulted-pod
  namespace: resource-governance
  labels:
    app: defaulted-pod
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
YAML

cat > "$COURSE_DIR/q01/oversized-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: oversized-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 600m
          memory: 64Mi
        limits:
          cpu: 700m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/q01/burst-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: burst-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/q01/below-minimum-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: below-minimum-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 25m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/q01/multi-container-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
  namespace: resource-governance
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 128Mi
    - name: sidecar
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 300m
          memory: 128Mi
YAML

cat > "$COURSE_DIR/q01/missing-limit-pod.yaml" <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: missing-limit-pod
  namespace: resource-governance
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
YAML

cat > "$COURSE_DIR/q01/batch-worker.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-worker
  namespace: resource-governance
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: batch-worker
  template:
    metadata:
      labels:
        app: batch-worker
    spec:
      containers:
        - name: worker
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: 300m
              memory: 192Mi
            limits:
              cpu: 500m
              memory: 384Mi
YAML

cat > "$COURSE_DIR/q01/broken-rollout.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diagnostic-worker
  namespace: resource-governance
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: diagnostic-worker
  template:
    metadata:
      labels:
        app: diagnostic-worker
    spec:
      containers:
        - name: worker
          image: nginx:1.27-alpine
YAML

cat > "$COURSE_DIR/q01/temporary-settings.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: temporary-settings
  namespace: resource-governance
data:
  purpose: temporary
YAML

cat > "$COURSE_DIR/q01/worker-settings.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-settings
  namespace: resource-governance
data:
  concurrency: "2"
YAML

cat > "$COURSE_DIR/q01/extra-service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: batch-worker
  namespace: resource-governance
spec:
  selector:
    app: batch-worker
  ports:
    - port: 80
      targetPort: 80
YAML

for number in $(seq -w 2 20); do
  mkdir -p "$COURSE_DIR/q$number"
  cp "$COURSE_DIR/q01/"*.yaml "$COURSE_DIR/q$number/"
done

for number in $(seq -w 1 20); do
  directory="$COURSE_DIR/q$number"
  touch "$directory/evidence.txt"
  cat > "$directory/create-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
kubectl apply -f base-resources.yaml
kubectl -n resource-governance rollout status deployment/platform-api --timeout=120s
SCRIPT
  cat > "$directory/remove-resources.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace resource-governance --ignore-not-found --wait=true
SCRIPT
  chmod +x "$directory/create-resources.sh" "$directory/remove-resources.sh"
done

cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md" q-prefixed
touch "$COURSE_DIR/.initialized"

info "ResourceQuota and LimitRange files ready: $COURSE_DIR"
info "No cluster resources were created by this generator"
