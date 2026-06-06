#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-crossplane}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v helm >/dev/null || { echo "helm is required"; exit 1; }
if [ -e "$COURSE_DIR/.initialized" ] && [ "$LAB_FORCE" != "true" ]; then
  echo "$COURSE_DIR already initialized; use LAB_FORCE=true"; exit 1
fi

helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane \
  -n crossplane-system --create-namespace --wait
kubectl apply -f - <<'YAML'
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-patch-and-transform}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
YAML
kubectl create ns platform-team --dry-run=client -o yaml | kubectl apply -f - >/dev/null
mkdir -p "$COURSE_DIR"
for n in $(seq -w 1 20); do mkdir -p "$COURSE_DIR/$n"; done
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

cat > "$COURSE_DIR/base-xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: apps.platform.example.io}
spec:
  scope: TODO
  group: TODO
  names: {kind: TODO, plural: TODO}
  versions:
    - name: v1alpha1
      served: TODO
      referenceable: TODO
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec: {type: object, properties: {}} # TODO
YAML
for n in 01 02 03 15; do cp "$COURSE_DIR/base-xrd.yaml" "$COURSE_DIR/$n/xrd.yaml"; done
cat > "$COURSE_DIR/02/valid.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: App
metadata: {name: valid, namespace: platform-team}
spec: {image: nginx:1-alpine, replicas: 2, environment: dev}
YAML
cat > "$COURSE_DIR/02/invalid.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: App
metadata: {name: invalid, namespace: platform-team}
spec: {replicas: 0, environment: qa}
YAML

cat > "$COURSE_DIR/base-composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: app}
spec:
  compositeTypeRef: {apiVersion: platform.example.io/v1alpha1, kind: App}
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef: {name: function-patch-and-transform}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: app-config
            base:
              apiVersion: v1
              kind: ConfigMap
              metadata: {name: app-config}
              data: {}
            patches: [] # TODO
YAML
for n in $(seq -w 4 17); do cp "$COURSE_DIR/base-composition.yaml" "$COURSE_DIR/$n/composition.yaml"; done
cat > "$COURSE_DIR/base-xr.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: App
metadata: {name: demo, namespace: platform-team}
spec: {image: nginx:1-alpine, replicas: 2, environment: dev}
YAML
for n in $(seq -w 4 17); do cp "$COURSE_DIR/base-xr.yaml" "$COURSE_DIR/$n/xr.yaml"; done
cat > "$COURSE_DIR/11/missing-image.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: App
metadata: {name: missing-image, namespace: platform-team}
spec: {replicas: 2, environment: dev}
YAML
touch "$COURSE_DIR/11/result.txt"
cat > "$COURSE_DIR/16/environment.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata: {name: platform-defaults}
data: {region: eu-west, owner: platform}
YAML
cat > "$COURSE_DIR/18/function.yaml" <<'YAML'
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-auto-ready}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.6.5
YAML
cp "$COURSE_DIR/base-composition.yaml" "$COURSE_DIR/18/composition.yaml"

cat > "$COURSE_DIR/19/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: brokenapps.platform.example.io}
spec:
  scope: Namespaced
  group: platform.example.io
  names: {kind: BrokenApp, plural: brokenapps}
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          properties:
            spec: {properties: {image: {type: array}}}
YAML
cat > "$COURSE_DIR/19/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: broken-app}
spec:
  compositeTypeRef: {apiVersion: platform.example.io/v1alpha1, kind: WrongKind}
  mode: Pipeline
  pipeline:
    - step: patch
      functionRef: {name: wrong-function}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: config
            base: {apiVersion: v1, kind: ConfigMap, metadata: {name: broken}}
            patches:
              - {type: FromCompositeFieldPath, fromFieldPath: spec.wrong, toFieldPath: data.image}
YAML
cat > "$COURSE_DIR/19/xr.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: BrokenApp
metadata: {name: broken, namespace: platform-team}
spec: {image: nginx:1-alpine}
YAML
touch "$COURSE_DIR/19/report.md"

cat > "$COURSE_DIR/20/xrd.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: webservices.platform.example.io}
spec: {} # TODO
YAML
cat > "$COURSE_DIR/20/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: webservice}
spec: {} # TODO
YAML
cat > "$COURSE_DIR/20/xr.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: WebService
metadata: {name: checkout, namespace: platform-team}
spec: {image: nginx:1-alpine, replicas: 2, port: 8080, environment: prod}
YAML
rm "$COURSE_DIR/base-xrd.yaml" "$COURSE_DIR/base-composition.yaml" "$COURSE_DIR/base-xr.yaml"
touch "$COURSE_DIR/.initialized"
echo "Crossplane lab ready: $COURSE_DIR"
