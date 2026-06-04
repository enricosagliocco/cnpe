#!/usr/bin/env bash
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"

DRY_RUN=true
AUTO_CONFIRM=false

usage() {
  cat <<'EOF'
Uso:
  wipe_gitea_repos_orgs.sh --token <TOKEN> [--url <GITEA_URL>] [--execute] [--yes]

Opzioni:
  --token <TOKEN>   Token API Gitea (in alternativa variabile env GITEA_TOKEN)
  --url <URL>       Base URL Gitea (default: env GITEA_URL o http://192.168.1.56:3000/)
  --execute         Esegue davvero le DELETE (default: dry-run)
  --yes             Salta la richiesta di conferma interattiva (solo con --execute)
  -h, --help        Mostra questo help

Comportamento:
  1. Elimina tutti i repository personali dell'utente autenticato.
  2. Per ogni organization dell'utente:
  - elimina i repository dell'organization

Note:
  - In default e dry-run: stampa solo quello che verrebbe eliminato.
  - Richiede: curl, jq
EOF
}

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

err() {
  echo "[ERR] $*" >&2
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || { err "Comando mancante: $cmd"; exit 1; }
}

api_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url="${GITEA_URL%/}${path}"

if [[ -n "$data" ]]; then
    curl -fsS -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      "$url" \
      -d "$data"
  else
    curl -fsS -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      "$url"
  fi
}

api_status() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url="${GITEA_URL%/}${path}"

  if [[ -n "$data" ]]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      "$url" \
      -d "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      "$url"
  fi
}

confirm_execute() {
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  if [[ "$AUTO_CONFIRM" == true ]]; then
    return 0
  fi

  echo
  echo "ATTENZIONE: verranno eliminati repository e organization in modo irreversibile."
  read -r -p "Confermi? scrivi DELETE per procedere: " answer
  if [[ "$answer" != "DELETE" ]]; then
    err "Conferma non valida. Operazione annullata."
    exit 1
  fi
}

require_confirmation_guard() {
  if [[ "$DRY_RUN" == false && "${GITEA_WIPE_FORCE:-false}" != true ]]; then
    case "${GITEA_URL%/}" in
      http://192.168.1.56:3000|https://192.168.1.56:3000|http://gitea.local:3000|https://gitea.local:3000)
        ;;
      *)
        err "Esecuzione distruttiva consentita solo con GITEA_WIPE_FORCE=true oppure su URL autorizzati"
        exit 1
        ;;
    esac
  fi
}

delete_repo() {
  local owner="$1"
  local repo="$2"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] delete repo ${owner}/${repo}"
    return 0
  fi

  local code
  code="$(api_status DELETE "/api/v1/repos/${owner}/${repo}")"
  if [[ "$code" == "204" || "$code" == "200" ]]; then
    echo "[OK] deleted repo ${owner}/${repo}"
  else
    warn "delete repo ${owner}/${repo} failed (HTTP ${code})"
  fi
}

delete_paginated_repos_for_owner() {
  local owner="$1"
  local kind="$2"
  local page=1
  local per_page=50
  local json count

  while true; do
    if [[ "$kind" == "user" ]]; then
      json="$(api_request GET "/api/v1/user/repos?page=${page}&limit=${per_page}")"
      json="$(echo "$json" | jq --arg owner "$owner" '[.[] | select(.owner.login == $owner)]')"
    else
      json="$(api_request GET "/api/v1/orgs/${owner}/repos?page=${page}&limit=${per_page}")"
    fi

    count="$(echo "$json" | jq 'length')"
    if [[ "$count" -eq 0 ]]; then
      break
    fi

    while IFS= read -r repo_name; do
      [[ -z "$repo_name" ]] && continue
      delete_repo "$owner" "$repo_name"
    done < <(echo "$json" | jq -r '.[].name')

    page=$((page + 1))
  done
}

delete_user_orgs() {
  local page=1
  local per_page=50
  local json count

  while true; do
    json="$(api_request GET "/api/v1/user/orgs?page=${page}&limit=${per_page}")"
    count="$(echo "$json" | jq 'length')"
    if [[ "$count" -eq 0 ]]; then
      break
    fi

    while IFS= read -r org_name; do
      [[ -z "$org_name" ]] && continue
      log "Processing organization: ${org_name}"
      delete_paginated_repos_for_owner "$org_name" "org"
    done < <(echo "$json" | jq -r '.[].username')

    page=$((page + 1))
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --token)
        [[ $# -ge 2 ]] || { err "Manca il valore per --token"; exit 1; }
        GITEA_TOKEN="$2"
        shift 2
        ;;
      --url)
        [[ $# -ge 2 ]] || { err "Manca il valore per --url"; exit 1; }
        GITEA_URL="$2"
        shift 2
        ;;
      --execute)
        DRY_RUN=false
        shift
        ;;
      --yes)
        AUTO_CONFIRM=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Argomento non riconosciuto: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  require_confirmation_guard

  require_cmd curl
  require_cmd jq

  if [[ -z "$GITEA_TOKEN" ]]; then
    err "Token mancante. Usa --token oppure imposta GITEA_TOKEN"
    exit 1
  fi

  local me user_name
  me="$(api_request GET "/api/v1/user")"
  user_name="$(echo "$me" | jq -r '.login')"

  if [[ -z "$user_name" || "$user_name" == "null" ]]; then
    err "Impossibile risolvere l'utente autenticato"
    exit 1
  fi

  log "Gitea URL: ${GITEA_URL}"
  log "Authenticated as: ${user_name}"
  if [[ "$DRY_RUN" == true ]]; then
    log "Modalita: DRY-RUN"
  else
    log "Modalita: EXECUTE"
  fi

  confirm_execute

  log "Deleting personal repositories for ${user_name}"
  delete_paginated_repos_for_owner "$user_name" "user"

  log "Deleting organizations for ${user_name}"
  delete_user_orgs

  log "Completed"
}

main "$@"
