#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="${1:-}"
[ -n "$LAB_DIR" ] || {
  echo "usage: $0 <lab-directory>" >&2
  exit 2
}

LAB_DIR="$(cd "$LAB_DIR" && pwd)"
QUESTIONS="$LAB_DIR/domande.md"

fail() {
  echo "[ERR] $(basename "$LAB_DIR"): $*" >&2
  exit 1
}

for file in README.md domande.md lab-question-layout.sh; do
  [ -s "$LAB_DIR/$file" ] || fail "missing $file"
done

setup_count="$(
  find "$LAB_DIR" -maxdepth 1 -type f -name 'setup-*.sh' \
    ! -name '*-kind.sh' | wc -l
)"
[ "$setup_count" -eq 1 ] || fail "expected one primary setup script"

find "$LAB_DIR" -maxdepth 1 -type f -name 'setup-*-kind.sh' |
  grep -q . || fail "missing Kind wrapper"

question_count="$(
  awk '/^### Q[0-9]+ - / { count++ } END { print count + 0 }' "$QUESTIONS"
)"
[ "$question_count" -eq 20 ] ||
  fail "expected 20 ASCII-hyphen question headings, found $question_count"

for number in $(seq 1 20); do
  grep -q "^### Q${number} - " "$QUESTIONS" ||
    fail "missing or malformed Q$number heading"
done

grep -Eq '^## (Soluzioni|Tracce di soluzione)' "$QUESTIONS" ||
  fail "missing solution section"
grep -Eq 'course-[a-z0-9-]+|Percorso:' "$QUESTIONS" ||
  fail "questions do not identify a working path"
grep -Eqi 'verifica|verify|controlla|attendi' "$QUESTIONS" ||
  fail "questions do not contain verification criteria"
grep -Eqi '\*\*Tip|^Tip|Comandi.*utili|comando' "$QUESTIONS" ||
  fail "questions do not provide diagnostic guidance"

grep -q 'COURSE_DIR=' "$LAB_DIR"/setup-*.sh ||
  fail "setup does not expose COURSE_DIR"
grep -q 'LAB_FORCE=' "$LAB_DIR"/setup-*.sh ||
  fail "setup does not expose LAB_FORCE"
grep -q 'prepare_question_layout' "$LAB_DIR"/setup-*.sh ||
  fail "setup does not generate per-question material"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT
cp "$QUESTIONS" "$TMP_DIR/domande.md"

# shellcheck source=/dev/null
source "$LAB_DIR/lab-question-layout.sh"
prepare_question_layout "$TMP_DIR" "$TMP_DIR/domande.md"

for number in $(seq -w 1 20); do
  [ -s "$TMP_DIR/$number/QUESTION.md" ] || fail "Q$number extraction failed"
  [ -f "$TMP_DIR/$number/evidence.txt" ] || fail "Q$number evidence missing"
  if grep -Eq '^## (Soluzioni|Tracce di soluzione)' \
    "$TMP_DIR/$number/QUESTION.md"; then
    fail "Q$number leaked solutions"
  fi
done

echo "[OK] $(basename "$LAB_DIR") follows the common lab methodology"
