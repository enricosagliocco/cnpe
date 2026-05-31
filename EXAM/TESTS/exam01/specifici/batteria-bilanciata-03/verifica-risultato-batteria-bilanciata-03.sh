#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BATTERY_NAME="$(basename "$SCRIPT_DIR")"
exec "$EXAM_ROOT/valuta-batteria.sh" "$SCRIPT_DIR" "$BATTERY_NAME"
