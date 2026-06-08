#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
checked=0

bash -n "$ROOT/lab-question-layout.sh"

fail() {
  printf '[FAIL] %s: %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

while IFS= read -r -d '' directory; do
  name="${directory##*/}"
  mapfile -d '' files < <(
    find "$directory" -maxdepth 1 -type f \
      \( -name 'domande.md' -o -name 'domande-alt.md' \) -print0
  )

  if [ "${#files[@]}" -ne 1 ]; then
    fail "$name" "atteso esattamente un file domande, trovati ${#files[@]}"
    continue
  fi

  file="${files[0]}"
  checked=$((checked + 1))

  head -n 1 "$file" | grep -Eq '^# .+' ||
    fail "$name" "titolo H1 mancante"
  grep -Eqi 'Scenario (creato|deployato)' "$file" ||
    fail "$name" "descrizione scenario mancante"
  grep -Eqi 'Vincol' "$file" ||
    fail "$name" "vincoli mancanti"

  mapfile -t numbers < <(
    sed -nE 's/^### Q([0-9]+) (–|-).*/\1/p' "$file"
  )
  if [ "${#numbers[@]}" -ne 20 ]; then
    fail "$name" "attese 20 domande, trovate ${#numbers[@]}"
  fi

  expected=1
  for number in "${numbers[@]}"; do
    if [ "$number" -ne "$expected" ]; then
      fail "$name" "attesa Q${expected}, trovata Q${number}"
      break
    fi
    expected=$((expected + 1))
  done

  grep -Eqi 'verifica finale|simulazione a tempo|incident finale' "$file" ||
    fail "$name" "verifica finale mancante"
  grep -Eq '```bash|kubectl|helm|flux|argocd|kyverno|tofu|git ' "$file" ||
    fail "$name" "verifica runtime mancante"
  grep -Rq 'prepare_question_layout' "$directory"/*.sh ||
    fail "$name" "setup non collegato al layout Q1-Q20"
  while IFS= read -r setup; do
    bash -n "$setup" ||
      fail "$name" "sintassi Bash non valida in ${setup##*/}"
  done < <(
    find "$directory" -maxdepth 1 -type f \
      \( -name 'setup-*.sh' -o -name 'cnpe-setup-part*.sh' \) | sort
  )

  printf '[OK]   %-34s %2d domande\n' "$name" "${#numbers[@]}"
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

printf '\nControllate %d cartelle.\n' "$checked"
if [ "$failures" -ne 0 ]; then
  printf 'Errori trovati: %d\n' "$failures" >&2
  exit 1
fi
printf 'Tutti i lab contengono esattamente 20 domande CNPE.\n'
