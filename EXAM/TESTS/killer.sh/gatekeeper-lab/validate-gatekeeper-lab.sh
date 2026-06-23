#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  echo "[ERR] $*" >&2
  exit 1
}

[ -f "$SCRIPT_DIR/README.md" ] || fail "README.md missing"
[ -f "$SCRIPT_DIR/domande.md" ] || fail "domande.md missing"
[ -f "$SCRIPT_DIR/setup-gatekeeper-lab.sh" ] || fail "setup-gatekeeper-lab.sh missing"
[ -f "$SCRIPT_DIR/lab-question-layout.sh" ] || fail "lab-question-layout.sh missing"

question_count="$(awk '/^### Q[0-9]+ - / { count++ } END { print count + 0 }' "$SCRIPT_DIR/domande.md")"
[ "$question_count" -eq 20 ] || fail "expected 20 questions, found $question_count"

solution_count="$(awk '/^### Soluzione Q[0-9]+ - / { count++ } END { print count + 0 }' "$SCRIPT_DIR/domande.md")"
[ "$solution_count" -eq 20 ] || fail "expected 20 solution headings, found $solution_count"

for number in $(seq -w 1 20); do
  grep -q "COURSE_DIR/$number" "$SCRIPT_DIR/setup-gatekeeper-lab.sh" ||
    fail "setup script does not appear to create starter files for Q$number"
done

bash -n "$SCRIPT_DIR/setup-gatekeeper-lab.sh"
bash -n "$SCRIPT_DIR/lab-question-layout.sh"
bash -n "$SCRIPT_DIR/setup-gatekeeper-lab-kind.sh"

echo "[OK] gatekeeper lab structure looks good"
