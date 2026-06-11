#!/usr/bin/env bash
set -euo pipefail

COURSE_DIR="${COURSE_DIR:-$HOME/course-crossplane}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_FORCE="${LAB_FORCE:-false}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-crossplane-lab}"
CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-2.3.1}"

die() { echo "[ERR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }

ensure_cluster() {
  case "$CLUSTER_PROVIDER" in
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
        command -v minikube >/dev/null || die "Minikube is required"
        minikube start --cpus=4 --memory=6144
      fi
      ;;
    existing)
      kubectl cluster-info >/dev/null 2>&1 ||
        die "kubectl cannot reach a cluster"
      ;;
    *) die "Unsupported CLUSTER_PROVIDER: $CLUSTER_PROVIDER" ;;
  esac
}

write_scenario() {
  local number="$1"
  local kind="$2"
  local plural="$3"
  local composition="$4"
  local field="$5"
  local annotation="$6"
  local child_name="$7"
  local directory="$COURSE_DIR/$number"

  mkdir -p "$directory"

  cat > "$directory/xrd.yaml" <<YAML
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: ${plural}.platform.example.com
spec:
  scope: Cluster
  group: platform.example.com
  names:
    kind: ${kind}
    plural: ${plural}
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                ${field}:
                  type: string
              required:
                - ${field}
YAML

  cat > "$directory/composition.yaml" <<YAML
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: ${composition}
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: ${kind}
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: namespace
            base:
              apiVersion: v1
              kind: Namespace
            patches:
              - fromFieldPath: metadata.name
                toFieldPath: metadata.name
              - fromFieldPath: spec.${field}
                toFieldPath: metadata.annotations[platform.example.com/${annotation}]
            readinessChecks:
              - type: None
          - name: configuration
            base:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: ${child_name}
              data: {}
            patches:
              - fromFieldPath: metadata.name
                toFieldPath: metadata.namespace
              - fromFieldPath: spec.${field}
                toFieldPath: data.${field}
            readinessChecks:
              - type: None
YAML
}

command -v kubectl >/dev/null || die "kubectl is required"
command -v helm >/dev/null || die "helm is required"
ensure_cluster

if [ -e "$COURSE_DIR/.initialized" ]; then
  if [ "$LAB_FORCE" != "true" ]; then
    die "$COURSE_DIR already initialized; use LAB_FORCE=true"
  fi
  case "$COURSE_DIR" in
    ""|"/"|"$HOME")
      die "Refusing to replace unsafe COURSE_DIR: $COURSE_DIR"
      ;;
  esac
  info "Replacing existing lab material in $COURSE_DIR"
  rm -rf -- "$COURSE_DIR"
fi

helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane \
  -n crossplane-system --create-namespace --version "$CROSSPLANE_VERSION" --wait

kubectl apply -f - <<'YAML'
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
YAML

info "Waiting for function-patch-and-transform (this can take 1-2 minutes)"
kubectl wait --for=condition=Healthy \
  function/function-patch-and-transform --timeout=300s

mkdir -p "$COURSE_DIR"
cp "$SCRIPT_DIR/domande.md" "$COURSE_DIR/domande.md"

write_scenario 01 TeamSpace teamspaces teamspace-composition \
  projectId project-id teamspace-config
write_scenario 02 ProjectSpace projectspaces projectspace-composition \
  owner owner project-config
write_scenario 03 EnvironmentSpace environmentspaces environmentspace-composition \
  environment environment environment-config
write_scenario 04 CostSpace costspaces costspace-composition \
  costCenter cost-center cost-config
write_scenario 05 ProductSpace productspaces productspace-composition \
  productId product-id product-config
write_scenario 06 TenantSpace tenantspaces tenantspace-composition \
  tenantId tenant-id tenant-config
write_scenario 07 ClusterSpace clusterspaces clusterspace-composition \
  clusterName cluster-name cluster-config
write_scenario 08 RegionSpace regionspaces regionspace-composition \
  region region region-config
write_scenario 09 AccountSpace accountspaces accountspace-composition \
  accountId account-id account-config
write_scenario 10 ApplicationSpace applicationspaces applicationspace-composition \
  applicationId application-id application-config
write_scenario 11 DomainSpace domainspaces domainspace-composition \
  domain domain domain-config
write_scenario 12 ServiceSpace servicespaces servicespace-composition \
  serviceOwner service-owner service-config
write_scenario 13 DataSpace dataspaces dataspace-composition \
  classification classification data-config
write_scenario 14 SecuritySpace securityspaces securityspace-composition \
  securityTier security-tier security-config
write_scenario 15 ComplianceSpace compliancespaces compliancespace-composition \
  policySet policy-set compliance-config
write_scenario 16 RuntimeSpace runtimespaces runtime-composition \
  runtime runtime runtime-config
write_scenario 17 ReleaseSpace releasespaces release-composition \
  releaseChannel release-channel release-config
write_scenario 18 ObservabilitySpace observabilityspaces observability-composition \
  monitoringProfile monitoring-profile observability-config
write_scenario 19 BackupSpace backupspaces backup-composition \
  backupPolicy backup-policy backup-config
write_scenario 20 PlatformSpace platformspaces platformspace-composition \
  platformOwner platform-owner platform-config

# Q1 mirrors the exam-style TeamSpace task with a NetworkPolicy.
cat > "$COURSE_DIR/01/composition.yaml" <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: teamspace-composition
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: TeamSpace
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: namespace
            base:
              apiVersion: v1
              kind: Namespace
            patches:
              - fromFieldPath: metadata.name
                toFieldPath: metadata.name
              - fromFieldPath: spec.projectId
                toFieldPath: metadata.annotations[platform.example.com/project-id]
            readinessChecks:
              - type: None
          - name: networkpolicy
            base:
              apiVersion: networking.k8s.io/v1
              kind: NetworkPolicy
              metadata:
                name: default-deny-ingress
              spec:
                podSelector: {}
                policyTypes:
                  - Ingress
            patches:
              - fromFieldPath: metadata.name
                toFieldPath: metadata.namespace
            readinessChecks:
              - type: None
YAML

source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md"
touch "$COURSE_DIR/.initialized"
echo "Crossplane lab ready: $COURSE_DIR"
