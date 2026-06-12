#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-crd-openapi}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
LAB_SKIP_CLUSTER="${LAB_SKIP_CLUSTER:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-existing}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cnpe-crd-openapi}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

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
        kind create cluster --name "$KIND_CLUSTER_NAME" --wait 180s
      fi
      kubectl config use-context "kind-$KIND_CLUSTER_NAME" >/dev/null
      ;;
    minikube)
      if ! kubectl cluster-info >/dev/null 2>&1; then
        command -v minikube >/dev/null || die "minikube is required"
        minikube start --cpus=2 --memory=4096
      fi
      ;;
    *)
      die "unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER"
      ;;
  esac
}

write_starter() {
  local number="$1"
  local plural="$2"
  local singular="$3"
  local kind="$4"
  local short_name="$5"
  local directory="$COURSE_DIR/$number"

  mkdir -p "$directory"
  cat > "$directory/crd.yaml" <<YAML
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ${plural}.platform.killercoda.com
spec:
  group: platform.killercoda.com
  names:
    kind: ${kind}
    plural: ${plural}
    singular: ${singular}
    shortNames:
      - ${short_name}
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          # TODO: add the structural OpenAPI schema required by QUESTION.md
YAML

  cat > "$directory/valid.yaml" <<YAML
# TODO: create a valid ${kind} object as required by QUESTION.md.
YAML
  cat > "$directory/invalid.yaml" <<YAML
# TODO: create an invalid ${kind} object as required by QUESTION.md.
YAML
}

if [ -e "$COURSE_DIR/.initialized" ]; then
  [ "$LAB_FORCE" = "true" ] ||
    die "$COURSE_DIR already initialized; use LAB_FORCE=true"
  case "$COURSE_DIR" in
    ""|"/"|"$HOME")
      die "refusing to replace unsafe COURSE_DIR: $COURSE_DIR"
      ;;
  esac
  rm -rf -- "$COURSE_DIR"
fi

if [ "$LAB_SKIP_CLUSTER" != "true" ]; then
  command -v kubectl >/dev/null || die "kubectl is required"
  ensure_cluster
  kubectl create namespace exam --dry-run=client -o yaml |
    kubectl apply -f - >/dev/null
else
  info "Skipping cluster checks"
fi

mkdir -p "$COURSE_DIR"
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

write_starter 01 platformservices platformservice PlatformService ps
write_starter 02 appservices appservice AppService apps
write_starter 03 routeservices routeservice RouteService rts
write_starter 04 workerservices workerservice WorkerService ws
write_starter 05 accessprofiles accessprofile AccessProfile ap
write_starter 06 databaseservices databaseservice DatabaseService dbs
write_starter 07 teamconfigs teamconfig TeamConfig tc
write_starter 08 buildrequests buildrequest BuildRequest br
write_starter 09 pluginconfigs pluginconfig PluginConfig pc
write_starter 10 cachepolicies cachepolicy CachePolicy cp
write_starter 11 capacityplans capacityplan CapacityPlan cap
write_starter 12 serviceplans serviceplan ServicePlan sp
write_starter 13 projectrequests projectrequest ProjectRequest pr
write_starter 14 managedservices managedservice ManagedService ms
write_starter 15 catalogentries catalogentry CatalogEntry ce
write_starter 16 scalableapps scalableapp ScalableApp sa
write_starter 17 discoverableservices discoverableservice DiscoverableService ds
write_starter 18 releasechannels releasechannel ReleaseChannel rc
write_starter 19 brokenservices brokenservice BrokenService bs
write_starter 20 productionservices productionservice ProductionService prod

# Q1 mirrors the supplied exam-style question.
cat > "$COURSE_DIR/01/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: platformservices.platform.killercoda.com
spec:
  group: platform.killercoda.com
  names:
    kind: PlatformService
    plural: platformservices
    singular: platformservice
    shortNames:
      - ps
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          # ADD SCHEMA HERE
YAML
cat > "$COURSE_DIR/01/valid.yaml" <<'YAML'
apiVersion: platform.killercoda.com/v1
kind: PlatformService
metadata:
  name: checkout
  namespace: exam
spec:
  serviceName: checkout
  tier: silver
YAML
cat > "$COURSE_DIR/01/invalid.yaml" <<'YAML'
apiVersion: platform.killercoda.com/v1
kind: PlatformService
metadata:
  name: invalid-tier
  namespace: exam
spec:
  serviceName: invalid-tier
  tier: platinum
  replicas: 20
YAML

# Q18 starts with two versions and intentionally invalid storage settings.
cat > "$COURSE_DIR/18/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: releasechannels.platform.killercoda.com
spec:
  group: platform.killercoda.com
  names:
    kind: ReleaseChannel
    plural: releasechannels
    singular: releasechannel
    shortNames: [rc]
  scope: Namespaced
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
                channel:
                  type: string
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                channel:
                  type: string
YAML

# Q19 is deliberately non-structural and contains an invalid default.
cat > "$COURSE_DIR/19/crd.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: brokenservices.platform.killercoda.com
spec:
  group: platform.killercoda.com
  names:
    kind: BrokenService
    plural: brokenservices
    singular: brokenservice
    shortNames: [bs]
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          properties:
            spec:
              properties:
                replicas:
                  type: integer
                  default: invalid
YAML

# Q20 is a from-scratch final task.
cat > "$COURSE_DIR/20/crd.yaml" <<'YAML'
# TODO: create the complete ProductionService CRD.
YAML
cat > "$COURSE_DIR/20/valid.yaml" <<'YAML'
# TODO: create ProductionService/storefront in namespace exam.
YAML
cat > "$COURSE_DIR/20/invalid.yaml" <<'YAML'
# TODO: create a request that the final schema must reject.
YAML

source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"

info "CRD OpenAPI validation lab ready: $COURSE_DIR"
