#!/usr/bin/env bash
set -euo pipefail

BATTERY_DIR="${1:-$PWD}"
BATTERY_NAME="${2:-$(basename "$BATTERY_DIR")}" 

if [[ ! -d "$BATTERY_DIR" ]]; then
  echo "[ERR] Directory non trovata: $BATTERY_DIR" >&2
  exit 1
fi

find_first_file() {
  local pattern="$1"
  local f
  f=$(find "$BATTERY_DIR" -maxdepth 1 -type f -name "$pattern" | sort | head -n 1 || true)
  echo "$f"
}

DOMANDE_FILE="$(find_first_file 'cnpe-domande*.md')"
if [[ -z "$DOMANDE_FILE" ]]; then
  DOMANDE_FILE="$(find_first_file 'cnpe-batteria-*.md')"
fi
if [[ -z "$DOMANDE_FILE" ]]; then
  DOMANDE_FILE="$(find_first_file '*domande*.md')"
fi

RISPOSTE_FILE="$(find_first_file 'cnpe-risposte*.md')"
if [[ -z "$RISPOSTE_FILE" ]]; then
  RISPOSTE_FILE="$(find_first_file '*risposte*.md')"
fi

extract_question_count() {
  local file="$1"
  local count=0
  local from_headers from_table

  if [[ -f "$file" ]]; then
    from_headers=$(grep -Eoi '^##[[:space:]]+Question[[:space:]]+[0-9]+' "$file" \
      | awk '{print $3}' \
      | sort -n \
      | tail -n 1 || true)

    from_table=$(grep -Eoi '\|[[:space:]]*Q[[:space:]]*[0-9]+' "$file" \
      | grep -Eo '[0-9]+' \
      | sort -n \
      | tail -n 1 || true)

    if [[ -n "$from_headers" ]]; then
      count="$from_headers"
    elif [[ -n "$from_table" ]]; then
      count="$from_table"
    fi
  fi

  echo "${count:-0}"
}

QUESTION_COUNT=0
if [[ -n "$DOMANDE_FILE" ]]; then
  QUESTION_COUNT="$(extract_question_count "$DOMANDE_FILE")"
fi

if [[ "$QUESTION_COUNT" -eq 0 && -n "$RISPOSTE_FILE" ]]; then
  QUESTION_COUNT="$(extract_question_count "$RISPOSTE_FILE")"
fi

if [[ "$QUESTION_COUNT" -le 0 ]]; then
  echo "[ERR] Non riesco a determinare il numero di domande in $BATTERY_DIR" >&2
  exit 1
fi

show_hint_for_question() {
  local q="$1"
  local file="$2"

  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "[INFO] File risposte non trovato"
    return
  fi

  awk -v q="$q" '
    BEGIN {in_q=0; shown=0}
    $0 ~ "^##[[:space:]]+Question[[:space:]]+" q "([[:space:]]|$)" {in_q=1; print; next}
    in_q && $0 ~ "^##[[:space:]]+Question[[:space:]]+[0-9]+" {exit}
    in_q {
      print
      shown++
      if (shown >= 30) {
        print "[...output troncato a 30 righe...]"
        exit
      }
    }
  ' "$file"
}

clear
printf '\n=== Valutazione %s ===\n' "$BATTERY_NAME"
printf 'Directory: %s\n' "$BATTERY_DIR"
printf 'Domande totali rilevate: %s\n' "$QUESTION_COUNT"
if [[ -n "$DOMANDE_FILE" ]]; then
  printf 'File domande: %s\n' "$(basename "$DOMANDE_FILE")"
fi
if [[ -n "$RISPOSTE_FILE" ]]; then
  printf 'File risposte: %s\n' "$(basename "$RISPOSTE_FILE")"
fi
printf '\nRegole input: y=corretta, n=errata, s=salta, h=mostra guida risposta\n\n'

correct=0
wrong=0
skipped=0

for ((i=1; i<=QUESTION_COUNT; i++)); do
  while true; do
    read -r -p "Q${i}/${QUESTION_COUNT} corretta? [y/n/s/h]: " ans
    ans="${ans,,}"
    case "$ans" in
      y|yes)
        ((correct+=1))
        break
        ;;
      n|no)
        ((wrong+=1))
        break
        ;;
      s|skip)
        ((skipped+=1))
        break
        ;;
      h|help)
        echo
        show_hint_for_question "$i" "$RISPOSTE_FILE"
        echo
        ;;
      *)
        echo "Input non valido. Usa y, n, s oppure h."
        ;;
    esac
  done
done

answered=$((correct + wrong + skipped))
if [[ "$answered" -eq 0 ]]; then
  percent=0
else
  percent=$((correct * 100 / QUESTION_COUNT))
fi

report_file="$BATTERY_DIR/score-${BATTERY_NAME}-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "Batteria: $BATTERY_NAME"
  echo "Directory: $BATTERY_DIR"
  echo "Totale domande: $QUESTION_COUNT"
  echo "Corrette: $correct"
  echo "Errate: $wrong"
  echo "Saltate: $skipped"
  echo "Punteggio: $percent%"
  echo "Data: $(date '+%F %T')"
} > "$report_file"

echo
echo "=== RISULTATO ==="
echo "Corrette: $correct/$QUESTION_COUNT"
echo "Errate:   $wrong"
echo "Saltate:  $skipped"
echo "Punteggio: $percent%"
echo "Report salvato in: $report_file"
