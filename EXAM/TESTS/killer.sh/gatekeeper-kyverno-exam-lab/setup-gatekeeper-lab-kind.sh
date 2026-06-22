#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CLUSTER_PROVIDER=kind
exec bash "$SCRIPT_DIR/setup-gatekeeper-lab.sh" "$@"
