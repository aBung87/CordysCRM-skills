#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path
from urllib import parse, request
from urllib.error import HTTPError, URLError


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
ENV_FILE = SKILL_DIR / ".env"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_env_file(ENV_FILE)

CORDYS_CRM_DOMAIN = os.environ.get("CORDYS_CRM_DOMAIN", "https://www.cordys.cn").rstrip("/")
CORDYS_ACCESS_KEY = os.environ.get("CORDYS_ACCESS_KEY", "")
CORDYS_SECRET_KEY = os.environ.get("CORDYS_SECRET_KEY", "")


def die(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"Warning: {message}", file=sys.stderr)


def check_keys() -> None:
    if not CORDYS_ACCESS_KEY:
        die("CORDYS_ACCESS_KEY is not set")
    if not CORDYS_SECRET_KEY:
        die("CORDYS_SECRET_KEY is not set")


def trusted_domain() -> str:
    parsed = parse.urlparse(CORDYS_CRM_DOMAIN)
    domain = parsed.netloc or CORDYS_CRM_DOMAIN
    return domain.replace("http://", "").replace("https://", "").split("/", 1)[0]


def validate_url(url: str) -> bool:
    parsed = parse.urlparse(url)
    if not parsed.netloc:
        return True

    request_domain = parsed.netloc
    allowed_domain = trusted_domain()
    return request_domain == allowed_domain or request_domain.endswith(f".{allowed_domain}")


def guard_untrusted_url(url: str) -> None:
    if validate_url(url):
        return

    request_domain = parse.urlparse(url).netloc
    allowed_domain = trusted_domain()
    message = (
        f"target domain '{request_domain}' does not match configured "
        f"Cordys CRM domain '{allowed_domain}'"
    )

    if os.environ.get("CORDYS_ALLOW_UNTRUSTED", "0") == "1":
        warn(f"{message}; continuing because CORDYS_ALLOW_UNTRUSTED=1")
        return

    die(f"{message}; set CORDYS_ALLOW_UNTRUSTED=1 to bypass")


def build_url(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        guard_untrusted_url(path)
        return path
    if not path.startswith("/"):
        path = "/" + path
    return f"{CORDYS_CRM_DOMAIN}{path}"


def is_json_like(value: str) -> bool:
    stripped = value.lstrip()
    return stripped.startswith("{") or stripped.startswith("[")


def page_payload(keyword: str = "") -> dict:
    return {
        "current": 1,
        "pageSize": 30,
        "sort": {},
        "combineSearch": {
            "searchMode": "AND",
            "conditions": [],
        },
        "keyword": keyword,
        "viewId": "ALL",
        "filters": [],
    }


def parse_query(raw_query: str):
    query = raw_query.strip()
    if not query:
        return None
    return parse.parse_qsl(query.lstrip("?"), keep_blank_values=True)


def api_request(method: str, path: str, params=None, data=None, content_type: str = "application/json") -> str:
    check_keys()

    url = build_url(path)
    if params:
        query = parse.urlencode(params)
        separator = "&" if "?" in url else "?"
        url = f"{url}{separator}{query}"

    body = None
    if data is not None:
        if isinstance(data, bytes):
            body = data
        elif isinstance(data, (dict, list)):
            body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        else:
            body = str(data).encode("utf-8")

    headers = {
        "X-Access-Key": CORDYS_ACCESS_KEY,
        "X-Secret-Key": CORDYS_SECRET_KEY,
        "Content-Type": content_type,
    }

    req = request.Request(url=url, data=body, headers=headers, method=method.upper())

    try:
        with request.urlopen(req) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, errors="replace")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        die(f"request failed: HTTP {exc.code} {detail}")
    except URLError as exc:
        die(f"request failed: {exc}")


def payload_or_keyword(value: str) -> dict | str:
    value = value or ""
    return value if is_json_like(value) else page_payload(value)


def crm_list(module: str, query: str = "") -> str:
    return api_request("GET", f"/{module}/view/list", params=parse_query(query))


def crm_get(module: str, resource_id: str) -> str:
    return api_request("GET", f"/{module}/{resource_id}")


def crm_contact(module: str, resource_id: str) -> str:
    return api_request("GET", f"/{module}/contact/list/{resource_id}")


def crm_page(module: str, payload: str = "") -> str:
    return api_request("POST", f"/{module}/page", data=payload_or_keyword(payload))


def crm_search(module: str, payload: str = "") -> str:
    return api_request("POST", f"/global/search/{module}", data=payload_or_keyword(payload))


def crm_follow_page(kind: str, module: str, payload: str = "") -> str:
    if kind not in {"plan", "record"}:
        die("follow only supports plan or record")
    return api_request("POST", f"/{module}/follow/{kind}/page", data=payload_or_keyword(payload))


def crm_product(payload: str = "") -> str:
    return api_request("POST", "/field/source/product", data=payload_or_keyword(payload))


def crm_org() -> str:
    return api_request("GET", "/department/tree")


def crm_members(payload: str) -> str:
    if not payload:
        die("members requires a JSON body")
    return api_request("POST", "/user/list", data=payload)


def raw_api(method: str, path: str, body: str = "") -> str:
    return api_request(method, path, data=body or None)


def print_usage() -> None:
    print(
        """cordys - Cordys CRM CLI

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

Examples:
  cordys crm page lead
  cordys crm search account "Acme"
  cordys crm get contract 123
  cordys raw GET /settings/fields?module=account
  cordys raw POST /lead/page '{"current":1,"pageSize":30}'
"""
    )


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        print_usage()
        raise SystemExit(1)

    cmd = argv[1]
    args = argv[2:]

    if cmd in {"help", "-h", "--help"}:
        print_usage()
        return

    if cmd == "crm":
        if not args:
            die("crm requires a subcommand")
        sub_cmd = args[0]
        rest = args[1:]

        if sub_cmd == "view":
            if not rest:
                die("view requires a module")
            print(crm_list(rest[0], rest[1] if len(rest) > 1 else ""))
            return

        if sub_cmd == "get":
            if len(rest) < 2:
                die("get requires <module> <id>")
            print(crm_get(rest[0], rest[1]))
            return

        if sub_cmd == "page":
            if not rest:
                die("page requires a module")
            print(crm_page(rest[0], " ".join(rest[1:])))
            return

        if sub_cmd == "search":
            if not rest:
                die("search requires a module")
            print(crm_search(rest[0], " ".join(rest[1:])))
            return

        if sub_cmd == "follow":
            if len(rest) < 2:
                die("follow requires <plan|record> <module>")
            print(crm_follow_page(rest[0], rest[1], " ".join(rest[2:])))
            return

        if sub_cmd == "product":
            print(crm_product(" ".join(rest)))
            return

        if sub_cmd == "contact":
            if len(rest) < 2:
                die("contact requires <module> <id>")
            print(crm_contact(rest[0], rest[1]))
            return

        if sub_cmd == "org":
            print(crm_org())
            return

        if sub_cmd == "members":
            print(crm_members(" ".join(rest)))
            return

        die(f"unknown crm subcommand: {sub_cmd}")

    if cmd == "raw":
        if len(args) < 2:
            die("raw requires <method> <path>")
        method = args[0]
        path = args[1]
        body = " ".join(args[2:])
        print(raw_api(method, path, body))
        return

    die(f"unknown command: {cmd}")


if __name__ == "__main__":
    main(sys.argv)
