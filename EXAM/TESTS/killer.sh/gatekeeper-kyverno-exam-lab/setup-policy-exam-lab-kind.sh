#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER_PROVIDER=kind \
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-policy-exam-lab}" \
  "$SCRIPT_DIR/setup-policy-exam-lab.sh" "$@"
