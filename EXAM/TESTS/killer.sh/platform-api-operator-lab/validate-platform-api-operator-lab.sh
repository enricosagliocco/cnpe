#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_VALIDATOR="$SCRIPT_DIR/../validate-lab-methodology.sh"

[ -f "$COMMON_VALIDATOR" ] || {
  echo "[ERR] common validator not found: $COMMON_VALIDATOR" >&2
  exit 1
}

exec bash "$COMMON_VALIDATOR" "$SCRIPT_DIR"
