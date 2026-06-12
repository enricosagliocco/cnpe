#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

bash "$SCRIPT_DIR/../validate-lab-methodology.sh" "$SCRIPT_DIR"

export COURSE_DIR="$TMP_DIR/course-crd-openapi"
export LAB_SKIP_CLUSTER=true
bash "$SCRIPT_DIR/setup-crd-openapi-validation-lab.sh" >/dev/null

fail() {
  echo "[ERR] $*" >&2
  exit 1
}

[ "$(find "$COURSE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 20 ] ||
  fail "expected 20 scenario directories"

for number in $(seq -w 1 20); do
  directory="$COURSE_DIR/$number"
  [ -s "$directory/QUESTION.md" ] || fail "missing Q$number"
  [ -f "$directory/crd.yaml" ] || fail "missing Q$number crd.yaml"
  [ -f "$directory/valid.yaml" ] || fail "missing Q$number valid.yaml"
  [ -f "$directory/invalid.yaml" ] || fail "missing Q$number invalid.yaml"
  [ -f "$directory/evidence.txt" ] || fail "missing Q$number evidence.txt"
done

grep -q 'name: platformservices.platform.killercoda.com' \
  "$COURSE_DIR/01/crd.yaml" || fail "Q1 CRD template mismatch"
grep -q '# ADD SCHEMA HERE' "$COURSE_DIR/01/crd.yaml" ||
  fail "Q1 schema placeholder missing"
grep -q 'storage: true' "$COURSE_DIR/18/crd.yaml" ||
  fail "Q18 version fixture missing"
[ "$(grep -c 'storage: true' "$COURSE_DIR/18/crd.yaml")" -eq 2 ] ||
  fail "Q18 must start with two storage versions"
grep -q 'default: invalid' "$COURSE_DIR/19/crd.yaml" ||
  fail "Q19 invalid default missing"
grep -q 'TODO: create the complete ProductionService' \
  "$COURSE_DIR/20/crd.yaml" || fail "Q20 must start empty"
if grep -q '^## Tracce di soluzione' "$COURSE_DIR/20/QUESTION.md"; then
  fail "Q20 question leaked solutions"
fi

echo "[OK] CRD OpenAPI validation lab generated and validated"
