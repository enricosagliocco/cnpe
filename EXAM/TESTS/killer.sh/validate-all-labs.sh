#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_VALIDATION="${FULL_VALIDATION:-false}"

for lab_dir in "$SCRIPT_DIR"/*-lab "$SCRIPT_DIR"/cnpe-gaps-*; do
  [ -d "$lab_dir" ] || continue
  lab_name="$(basename "$lab_dir")"

  if [ "$FULL_VALIDATION" = "true" ]; then
    validator="$lab_dir/validate-$lab_name.sh"
    [ -f "$validator" ] || {
      echo "[ERR] missing validator: $validator" >&2
      exit 1
    }
    bash "$validator"
  else
    bash "$SCRIPT_DIR/validate-lab-methodology.sh" "$lab_dir"
  fi
done

echo "[OK] all labs passed validation"
