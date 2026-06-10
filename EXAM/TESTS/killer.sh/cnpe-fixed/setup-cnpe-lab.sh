#!/usr/bin/env bash
# ============================================================
#  CNPE Full Lab Setup  –  entrypoint
#  Usage:
#    export GITEA_URL="http://192.168.1.56:3000/"
#    export GITEA_TOKEN="d2fcd54b7a8e2762920d929bfd4456db208659e4"
#    export GITEA_ORG="organization"
#    chmod +x setup-cnpe-lab.sh && ./setup-cnpe-lab.sh
# ============================================================
set -euo pipefail

export GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
export GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"
export GITEA_ORG="${GITEA_ORG:-organization}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
banner() { echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"; \
           echo -e "${BOLD}${GREEN}║  $*${NC}"; \
           echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}\n"; }

banner "CNPE Lab Setup starting"
echo "  GITEA_URL   = ${GITEA_URL}"
echo "  GITEA_TOKEN = ${GITEA_TOKEN:0:8}..."
echo "  GITEA_ORG   = ${GITEA_ORG}"
echo ""

for part in \
  "${SCRIPT_DIR}/cnpe-setup-part1.sh" \
  "${SCRIPT_DIR}/cnpe-setup-part2.sh" \
  "${SCRIPT_DIR}/cnpe-setup-part3.sh"; do
  if [ -f "$part" ]; then
    bash "$part"
  else
    echo "WARNING: $part not found – skipping"
  fi
done

CALLER_HOME="${SUDO_USER:+$(getent passwd "$SUDO_USER" | cut -d: -f6)}"
CALLER_HOME="${CALLER_HOME:-$HOME}"
COURSE_DIR="${COURSE_DIR:-${CALLER_HOME}/course}"
mkdir -p "$COURSE_DIR"
cp "${SCRIPT_DIR}/domande.md" "${COURSE_DIR}/domande.md"
source "$SCRIPT_DIR/lab-question-layout.sh"
prepare_question_layout "$COURSE_DIR" "$COURSE_DIR/domande.md" plain

banner "All done!"
