#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
checked=0

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

  if [ "${#files[@]}" -eq 0 ]; then
    fail "$name" "file domande mancante"
    continue
  fi
  if [ "${#files[@]}" -gt 1 ]; then
    fail "$name" "piu file domande trovati"
    continue
  fi

  file="${files[0]}"
  checked=$((checked + 1))

  head -n 1 "$file" | grep -Eq '^# .+' ||
    fail "$name" "titolo H1 mancante"
  grep -Eqi 'Scenario (creato|deployato)' "$file" ||
    fail "$name" "descrizione dello scenario mancante"
  grep -Eqi 'Vincol' "$file" ||
    fail "$name" "vincoli d'esame mancanti"

  mapfile -t numbers < <(
    sed -nE 's/^### Q([0-9]+) (–|-).*/\1/p' "$file"
  )
  if [ "${#numbers[@]}" -eq 0 ]; then
    fail "$name" "nessuna domanda numerata Qn"
    continue
  fi

  expected=1
  for number in "${numbers[@]}"; do
    if [ "$number" -ne "$expected" ]; then
      fail "$name" "numerazione non sequenziale: attesa Q${expected}, trovata Q${number}"
      break
    fi
    expected=$((expected + 1))
  done

  if ! grep -Eqi '^### (Q[0-9]+ .*(verifica finale|simulazione|incident finale)|Verifica finale)' "$file"; then
    fail "$name" "verifica finale o scenario conclusivo mancante"
  fi

  if ! grep -Eq '```bash|kubectl|helm|flux|argocd|kyverno|tofu|git ' "$file"; then
    fail "$name" "nessuna verifica runtime o comando operativo"
  fi

  printf '[OK]   %-34s %2d domande\n' "$name" "${#numbers[@]}"
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

printf '\nControllate %d cartelle.\n' "$checked"
if [ "$failures" -ne 0 ]; then
  printf 'Errori trovati: %d\n' "$failures" >&2
  exit 1
fi
printf 'Tutte le tracce rispettano la struttura CNPE prevista.\n'
