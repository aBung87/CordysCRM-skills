#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${SKILL_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

CORDYS_CRM_DOMAIN="${CORDYS_CRM_DOMAIN:-https://www.cordys.cn}"
CORDYS_CRM_DOMAIN="${CORDYS_CRM_DOMAIN%/}"

die() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warning: $*" >&2
}

check_keys() {
  [[ -n "${CORDYS_ACCESS_KEY:-}" ]] || die "CORDYS_ACCESS_KEY is not set"
  [[ -n "${CORDYS_SECRET_KEY:-}" ]] || die "CORDYS_SECRET_KEY is not set"
}

python_cmd() {
  if command -v python >/dev/null 2>&1; then
    echo python
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import sys" >/dev/null 2>&1; then
      echo python3
      return
    fi
  fi
  die "python or python3 is required"
}

is_json_like() {
  [[ "${1:-}" =~ ^[[:space:]]*[\{\[] ]]
}

trusted_domain() {
  if [[ "$CORDYS_CRM_DOMAIN" =~ ^https?://([^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$CORDYS_CRM_DOMAIN"
  fi
}

validate_url() {
  local url="$1"
  local domain
  if [[ "$url" =~ ^https?://([^/]+) ]]; then
    domain="${BASH_REMATCH[1]}"
  else
    return 0
  fi

  local allowed_domain
  allowed_domain="$(trusted_domain)"
  [[ "$domain" == "$allowed_domain" || "$domain" == *".$allowed_domain" ]]
}

guard_untrusted_url() {
  local url="$1"
  if validate_url "$url"; then
    return 0
  fi

  local request_domain allowed_domain
  request_domain="$(echo "$url" | sed -E 's#^https?://([^/]+).*$#\1#')"
  allowed_domain="$(trusted_domain)"
  local message="target domain '$request_domain' does not match configured Cordys CRM domain '$allowed_domain'"

  if [[ "${CORDYS_ALLOW_UNTRUSTED:-0}" == "1" ]]; then
    warn "$message; continuing because CORDYS_ALLOW_UNTRUSTED=1"
    return 0
  fi

  die "$message; set CORDYS_ALLOW_UNTRUSTED=1 to bypass"
}

page_payload() {
  local keyword="${1:-}"
  "$(python_cmd)" - "$keyword" <<'PY'
import json
import sys

keyword = sys.argv[1] if len(sys.argv) > 1 else ""
print(json.dumps({
    "current": 1,
    "pageSize": 30,
    "sort": {},
    "combineSearch": {"searchMode": "AND", "conditions": []},
    "keyword": keyword,
    "viewId": "ALL",
    "filters": []
}, ensure_ascii=False))
PY
}

api_request() {
  local method="$1"
  local url="$2"
  local content_type="$3"
  shift 3

  check_keys

  curl -sS --fail-with-body -X "$method" "$url" \
    -H "X-Access-Key: ${CORDYS_ACCESS_KEY}" \
    -H "X-Secret-Key: ${CORDYS_SECRET_KEY}" \
    -H "Content-Type: ${content_type}" \
    "$@"
}

api() {
  api_request "$1" "$2" "application/json" "${@:3}"
}

crm_list() {
  local module="$1"
  local query="${2:-}"
  local url="${CORDYS_CRM_DOMAIN}/${module}/view/list"
  if [[ -n "$query" ]]; then
    url="${url}?${query#\?}"
  fi
  api GET "$url"
}

crm_get() {
  local module="$1"
  local resource_id="$2"
  api GET "${CORDYS_CRM_DOMAIN}/${module}/${resource_id}"
}

crm_contact() {
  local module="$1"
  local resource_id="$2"
  api GET "${CORDYS_CRM_DOMAIN}/${module}/contact/list/${resource_id}"
}

payload_or_keyword() {
  local value="${1:-}"
  if is_json_like "$value"; then
    printf '%s' "$value"
  else
    page_payload "$value"
  fi
}

crm_page() {
  local module="$1"
  shift || true
  local body
  body="$(payload_or_keyword "${1:-}")"
  api POST "${CORDYS_CRM_DOMAIN}/${module}/page" -d "$body"
}

crm_search() {
  local module="$1"
  shift || true
  local body
  body="$(payload_or_keyword "${1:-}")"
  api POST "${CORDYS_CRM_DOMAIN}/global/search/${module}" -d "$body"
}

crm_follow_page() {
  local kind="$1"
  local module="$2"
  local payload="${3:-}"
  [[ "$kind" == "plan" || "$kind" == "record" ]] || die "follow only supports plan or record"
  local body
  body="$(payload_or_keyword "$payload")"
  api POST "${CORDYS_CRM_DOMAIN}/${module}/follow/${kind}/page" -d "$body"
}

crm_product() {
  local body
  body="$(payload_or_keyword "${1:-}")"
  api POST "${CORDYS_CRM_DOMAIN}/field/source/product" -d "$body"
}

crm_org() {
  api GET "${CORDYS_CRM_DOMAIN}/department/tree"
}

crm_members() {
  local body="${1:-}"
  [[ -n "$body" ]] || die "members requires a JSON body"
  api POST "${CORDYS_CRM_DOMAIN}/user/list" -d "$body"
}

raw_api() {
  local method="$1"
  local path="$2"
  shift 2 || true
  local body="${1:-}"
  local url="$path"
  if [[ "$path" == http* ]]; then
    guard_untrusted_url "$path"
  else
    url="${CORDYS_CRM_DOMAIN}${path}"
  fi
  if [[ -n "$body" ]]; then
    api "$method" "$url" -d "$body"
  else
    api "$method" "$url"
  fi
}

usage() {
  cat <<'EOF'
cordys - Cordys CRM CLI

Usage:
  cordys crm view <module> [query]
  cordys crm get <module> <id>
  cordys crm page <module> [keyword|json]
  cordys crm search <module> [keyword|json]
  cordys crm follow <plan|record> <module> [keyword|json]
  cordys crm product [keyword|json]
  cordys crm contact <module> <id>
  cordys crm org
  cordys crm members <json>
  cordys raw <method> <path> [body]

Common modules:
  lead, account, contact, opportunity, contract, product
  pool/lead, pool/account, contract/payment-plan, contract/payment-record
  contract/business-title, invoice, opportunity/quotation
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
  crm)
    sub="${1:-}"
    shift || die "crm requires a subcommand"
    case "$sub" in
      view)
        [[ $# -ge 1 ]] || die "view requires a module"
        crm_list "$1" "${2:-}"
        ;;
      get)
        [[ $# -ge 2 ]] || die "get requires <module> <id>"
        crm_get "$1" "$2"
        ;;
      page)
        [[ $# -ge 1 ]] || die "page requires a module"
        crm_page "$1" "${2:-}"
        ;;
      search)
        [[ $# -ge 1 ]] || die "search requires a module"
        crm_search "$1" "${2:-}"
        ;;
      follow)
        [[ $# -ge 2 ]] || die "follow requires <plan|record> <module>"
        crm_follow_page "$1" "$2" "${3:-}"
        ;;
      product)
        crm_product "${1:-}"
        ;;
      contact)
        [[ $# -ge 2 ]] || die "contact requires <module> <id>"
        crm_contact "$1" "$2"
        ;;
      org)
        crm_org
        ;;
      members)
        crm_members "${1:-}"
        ;;
      *)
        die "unknown crm subcommand: ${sub}"
        ;;
    esac
    ;;
  raw)
    [[ $# -ge 2 ]] || die "raw requires <method> <path>"
    raw_api "$1" "$2" "${3:-}"
    ;;
  help|-h|--help|'')
    usage
    ;;
  *)
    die "unknown command: ${cmd}"
    ;;
esac
