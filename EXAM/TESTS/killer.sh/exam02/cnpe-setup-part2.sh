#!/usr/bin/env bash
# ============================================================
# CNPE Exam02 - Part 2 (Q8-Q14)
# Focus: Security and Policy Enforcement
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

mkdir -p "${COURSE_DIR}"/{8,9,10,11,12,13,14}

section "8. Q8 - Gatekeeper Constraint Fix"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --wait --timeout=300s >/dev/null 2>&1 || true

cat > "${COURSE_DIR}/8/constrainttemplate.yaml" <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabelsretake
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabelsRetake
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
        package k8srequiredlabelsretake
        violation[{"msg": msg}] {
          input.review.kind.kind == "Pod"
          required := input.parameters.labels[_]
          not input.review.object.metadata.labels[required]
          msg := sprintf("TODO missing label: %v", [required])
        }
EOF

section "9. Q9 - Kyverno Mutate Policy"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --wait --timeout=300s >/dev/null 2>&1 || true

cat > "${COURSE_DIR}/9/security-check.yaml" <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: security-check-retake
spec:
  rules:
    - name: add-audit-pending
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(audit): pending
EOF

section "10. Q10 - Pod Security Admission"
kubectl create ns secure-legacy --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label ns secure-legacy pod-security.kubernetes.io/enforce=baseline --overwrite >/dev/null

cat > "${COURSE_DIR}/10/insecure-pod.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: secure-legacy
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        privileged: true
EOF

section "11. Q11 - RBAC Minimal Permissions"
kubectl create ns secure-rbac --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/11/rbac.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deploy-reader
  namespace: secure-rbac
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deploy-reader
  namespace: secure-rbac
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deploy-reader
  namespace: secure-rbac
subjects:
  - kind: ServiceAccount
    name: deploy-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deploy-reader
EOF

section "12. Q12 - NetworkPolicy Egress Tightening"
kubectl create ns secure-net --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/12/netpol.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: secure-net
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress: []
EOF

section "13. Q13 - Secret Handling"
kubectl create ns secure-secrets --dry-run=client -o yaml | kubectl apply -f - >/dev/null
cat > "${COURSE_DIR}/13/secret-bad.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: secure-secrets
stringData:
  username: admin
  password: TODO-ROTATE-ME
EOF

section "14. Q14 - Image Policy and Signing"
cat > "${COURSE_DIR}/14/image-policy.md" <<'EOF'
Tasks:
- Block :latest tags using policy
- Allow only signed images from trusted registry
- Validate running workloads and produce remediation list
EOF

success "Exam02 Part2 ready at ${COURSE_DIR}"
