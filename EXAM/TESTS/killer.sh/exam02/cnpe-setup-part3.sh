#!/usr/bin/env bash
# ============================================================
# CNPE Exam02 - Part 3 (Q15-Q20)
# Focus: Platform APIs and Self-Service Capabilities
# ============================================================
set -euo pipefail

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  CALLER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  CALLER_HOME="${HOME}"
fi
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course/exam02}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}  $*"; }
section() { echo -e "\n${BOLD}${GREEN}══ $* ══${NC}\n"; }

mkdir -p "${COURSE_DIR}"/{15,16,17,18,19,20}

section "15. Q15 - CRD Version Upgrade"
cat > "${COURSE_DIR}/15/crd-appclaims.yaml" <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: appclaims.platform.killer.sh
spec:
  group: platform.killer.sh
  names:
    kind: AppClaim
    plural: appclaims
    singular: appclaim
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
                tier:
                  type: string
EOF

section "16. Q16 - Self-Service API with Composition"
helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace \
  --wait --timeout=300s >/dev/null 2>&1 || true

cat > "${COURSE_DIR}/16/xrd.yaml" <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xredis.platform.killer.sh
spec:
  group: platform.killer.sh
  names:
    kind: XRedis
    plural: xredis
  claimNames:
    kind: RedisClaim
    plural: redisclaims
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
                size:
                  type: string
EOF

cat > "${COURSE_DIR}/16/composition.yaml" <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xredis-default
spec:
  compositeTypeRef:
    apiVersion: platform.killer.sh/v1alpha1
    kind: XRedis
  resources:
    - name: redis-sts
      base:
        apiVersion: apps/v1
        kind: StatefulSet
        metadata:
          name: redis
        spec:
          serviceName: redis
          replicas: 1
          selector:
            matchLabels:
              app: redis
          template:
            metadata:
              labels:
                app: redis
            spec:
              containers:
                - name: redis
                  image: redis:7-alpine
EOF

section "17. Q17 - Namespace Provisioning API"
cat > "${COURSE_DIR}/17/template-namespaceclaim.yaml" <<'EOF'
apiVersion: platform.killer.sh/v1alpha1
kind: NamespaceClaim
metadata:
  name: team-foo
spec:
  owner: foo
  quotaProfile: small
EOF

section "18. Q18 - Helm as Self-Service"
mkdir -p "${COURSE_DIR}/18/chart-retake/templates"
cat > "${COURSE_DIR}/18/chart-retake/Chart.yaml" <<'EOF'
apiVersion: v2
name: chart-retake
description: Retake self-service chart
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF
cat > "${COURSE_DIR}/18/chart-retake/templates/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: retake-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: retake-app
  template:
    metadata:
      labels:
        app: retake-app
    spec:
      containers:
        - name: app
          image: nginx:1-alpine
EOF

section "19. Q19 - Quota Profiles"
kubectl create ns selfservice-a --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/19/quota-small.yaml" <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: small
  namespace: selfservice-a
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
EOF

section "20. Q20 - API Contract Validation"
cat > "${COURSE_DIR}/20/contract-checklist.md" <<'EOF'
Checklist:
- Versioning policy for CRDs (served/storage)
- Backward compatibility for existing claims
- Validation schema completeness
- Upgrade plan with dry-run and rollback
EOF

success "Exam02 Part3 ready at ${COURSE_DIR}"
