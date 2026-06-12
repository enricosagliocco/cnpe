#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

bash "$SCRIPT_DIR/../validate-lab-methodology.sh" "$SCRIPT_DIR"

COURSE_DIR="$TMP_DIR/course-crossplane"
export COURSE_DIR
LAB_SKIP_INSTALL=true bash "$SCRIPT_DIR/setup-crossplane-lab.sh" >/dev/null

fail() {
  echo "[ERR] $*" >&2
  exit 1
}

[ "$(find "$COURSE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 20 ] ||
  fail "expected 20 scenario directories"

for number in $(seq -w 1 20); do
  directory="$COURSE_DIR/$number"
  [ -s "$directory/QUESTION.md" ] || fail "missing Q$number"
  [ -f "$directory/xrd.yaml" ] || fail "missing Q$number xrd.yaml"
  [ -f "$directory/composition.yaml" ] ||
    fail "missing Q$number composition.yaml"
  [ -f "$directory/xr.yaml" ] || fail "missing Q$number xr.yaml"
done

for number in 02 08 12 18; do
  grep -q 'scope: Namespaced' "$COURSE_DIR/$number/xrd.yaml" ||
    fail "Q$number must be namespaced"
done

grep -q 'composition-restricted.yaml' "$COURSE_DIR/13/QUESTION.md" ||
  fail "Q13 selection exercise missing"
grep -q 'environment: test' "$COURSE_DIR/03/invalid-xr.yaml" ||
  fail "Q3 invalid XR fixture missing"
grep -q 'name: v1beta1' "$COURSE_DIR/04/xrd.yaml" ||
  fail "Q4 must provide both API versions"
grep -q 'region:' "$COURSE_DIR/07/xrd.yaml" ||
  fail "Q7 schema must expose spec.region"
grep -q 'function-does-not-exist' "$COURSE_DIR/14/composition-broken.yaml" ||
  fail "Q14 broken composition missing"
grep -q 'name: securityspace-broken' "$COURSE_DIR/14/xr.yaml" ||
  fail "Q14 XR must select the broken composition"
grep -q 'TODO: define the cluster-scoped TeamSpace' "$COURSE_DIR/01/xrd.yaml" ||
  fail "Q1 must start from an empty XRD"
grep -q 'TODO: define the ProductSpace' "$COURSE_DIR/05/composition.yaml" ||
  fail "Q5 must start from an empty Composition"
grep -q 'TODO: define the PlatformSpace' "$COURSE_DIR/20/xrd.yaml" ||
  fail "Q20 must start from an empty XRD"
grep -q 'type: FromCompositeFieldPath' "$COURSE_DIR/01/composition.yaml" ||
  fail "generated compositions must use explicit FromCompositeFieldPath"
grep -q 'type: ToCompositeFieldPath' "$COURSE_DIR/11/QUESTION.md" ||
  fail "Q11 must focus on ToCompositeFieldPath"
grep -q 'kind: BackupPlan' "$COURSE_DIR/19/composition.yaml" ||
  fail "Q19 mismatched composite kind missing"
grep -q 'fromFieldPath: spec.retention' "$COURSE_DIR/19/composition.yaml" ||
  fail "Q19 required invalid patch missing"
grep -q '^spec: {}' "$COURSE_DIR/19/xr.yaml" ||
  fail "Q19 XR must omit backupPolicy"
if grep -q '^## Tracce di soluzione' "$COURSE_DIR/20/QUESTION.md"; then
  fail "Q20 question leaked the solution section"
fi

echo "[OK] Crossplane lab generated and validated in isolation"
