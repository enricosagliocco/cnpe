#!/usr/bin/env bash
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://192.168.1.56:3000/}"
GITEA_TOKEN="${GITEA_TOKEN:-d2fcd54b7a8e2762920d929bfd4456db208659e4}"

DRY_RUN=true
AUTO_CONFIRM=false

usage() {
  cat <<'EOF'
Usage:
  wipe_gitea_repos_orgs.sh --token <TOKEN> [--url <GITEA_URL>] [--execute] [--yes]

Options:
  --token <TOKEN>   Gitea API token (or env GITEA_TOKEN)
  --url <URL>       Gitea base URL (default: env GITEA_URL)
  --execute         Execute DELETE requests (default: dry-run)
  --yes             Skip interactive confirmation (only with --execute)
  -h, --help        Show help
EOF
}

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
err() { echo "[ERR]  $*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }
}

api_request() {
  local method="$1" path="$2" data="${3:-}" url="${GITEA_URL%/}${path}"
  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" "$url" -d "$data"
  else
    curl -fsS -X "$method" -H "Authorization: token ${GITEA_TOKEN}" "$url"
  fi
}

api_status() {
  local method="$1" path="$2" data="${3:-}" url="${GITEA_URL%/}${path}"
  if [[ -n "$data" ]]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" "$url" -d "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" -H "Authorization: token ${GITEA_TOKEN}" "$url"
  fi
}

confirm_execute() {
  [[ "$DRY_RUN" == true ]] && return 0
  [[ "$AUTO_CONFIRM" == true ]] && return 0
  read -r -p "Type DELETE to continue: " answer
  [[ "$answer" == "DELETE" ]] || { err "Invalid confirmation"; exit 1; }
}

delete_repo() {
  local owner="$1" repo="$2"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] delete repo ${owner}/${repo}"
    return 0
  fi
  local code
  code="$(api_status DELETE "/api/v1/repos/${owner}/${repo}")"
  [[ "$code" == "204" || "$code" == "200" ]] && echo "[OK] deleted ${owner}/${repo}" || warn "failed ${owner}/${repo} (HTTP ${code})"
}

delete_paginated_repos_for_owner() {
  local owner="$1" kind="$2" page=1 per_page=50 json count
  while true; do
    if [[ "$kind" == "user" ]]; then
      json="$(api_request GET "/api/v1/user/repos?page=${page}&limit=${per_page}")"
      json="$(echo "$json" | jq --arg owner "$owner" '[.[] | select(.owner.login == $owner)]')"
    else
      json="$(api_request GET "/api/v1/orgs/${owner}/repos?page=${page}&limit=${per_page}")"
    fi
    count="$(echo "$json" | jq 'length')"
    [[ "$count" -eq 0 ]] && break
    while IFS= read -r repo_name; do
      [[ -z "$repo_name" ]] && continue
      delete_repo "$owner" "$repo_name"
    done < <(echo "$json" | jq -r '.[].name')
    page=$((page + 1))
  done
}

delete_user_orgs() {
  local page=1 per_page=50 json count
  while true; do
    json="$(api_request GET "/api/v1/user/orgs?page=${page}&limit=${per_page}")"
    count="$(echo "$json" | jq 'length')"
    [[ "$count" -eq 0 ]] && break
    while IFS= read -r org_name; do
      [[ -z "$org_name" ]] && continue
      log "Processing org: ${org_name}"
      delete_paginated_repos_for_owner "$org_name" "org"
    done < <(echo "$json" | jq -r '.[].username')
    page=$((page + 1))
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --token) GITEA_TOKEN="$2"; shift 2 ;;
      --url) GITEA_URL="$2"; shift 2 ;;
      --execute) DRY_RUN=false; shift ;;
      --yes) AUTO_CONFIRM=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_cmd curl
  require_cmd jq
  [[ -n "$GITEA_TOKEN" ]] || { err "Missing token"; exit 1; }

  local me user_name
  me="$(api_request GET "/api/v1/user")"
  user_name="$(echo "$me" | jq -r '.login')"
  [[ -n "$user_name" && "$user_name" != "null" ]] || { err "Cannot resolve auth user"; exit 1; }

  log "Gitea URL: ${GITEA_URL}"
  log "Authenticated as: ${user_name}"
  log "Mode: $([[ "$DRY_RUN" == true ]] && echo DRY-RUN || echo EXECUTE)"

  confirm_execute
  delete_paginated_repos_for_owner "$user_name" "user"
  delete_user_orgs
  log "Completed"
}

main "$@"
