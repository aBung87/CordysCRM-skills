#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const SCRIPT_DIR = __dirname;
const SKILL_DIR = path.dirname(SCRIPT_DIR);
const ENV_FILE = path.join(SKILL_DIR, ".env");

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }
  for (const rawLine of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) {
      continue;
    }
    const [key, ...rest] = line.split("=");
    const value = rest.join("=").trim().replace(/^['"]|['"]$/g, "");
    if (!(key.trim() in process.env)) {
      process.env[key.trim()] = value;
    }
  }
}

loadEnvFile(ENV_FILE);

const config = {
  domain: (process.env.CORDYS_CRM_DOMAIN || "https://www.cordys.cn").replace(/\/+$/, ""),
  accessKey: process.env.CORDYS_ACCESS_KEY || "",
  secretKey: process.env.CORDYS_SECRET_KEY || "",
};

function die(message) {
  console.error(`Error: ${message}`);
  process.exit(1);
}

function checkKeys() {
  if (!config.accessKey) {
    die("CORDYS_ACCESS_KEY is not set");
  }
  if (!config.secretKey) {
    die("CORDYS_SECRET_KEY is not set");
  }
}

function buildUrl(targetPath) {
  if (targetPath.startsWith("http://") || targetPath.startsWith("https://")) {
    return targetPath;
  }
  return `${config.domain}${targetPath.startsWith("/") ? "" : "/"}${targetPath}`;
}

function isJsonLike(value) {
  return /^[\s]*[\[{]/.test(value || "");
}

function pagePayload(keyword = "") {
  return {
    current: 1,
    pageSize: 30,
    sort: {},
    combineSearch: { searchMode: "AND", conditions: [] },
    keyword,
    viewId: "ALL",
    filters: [],
  };
}

function payloadOrKeyword(value = "") {
  return isJsonLike(value) ? value : pagePayload(value);
}

async function apiRequest(method, targetPath, { query, body } = {}) {
  checkKeys();

  const url = new URL(buildUrl(targetPath));
  if (query) {
    const searchParams = new URLSearchParams(query.startsWith("?") ? query.slice(1) : query);
    for (const [key, value] of searchParams.entries()) {
      url.searchParams.append(key, value);
    }
  }

  let requestBody = undefined;
  if (body !== undefined && body !== null && body !== "") {
    requestBody = typeof body === "string" ? body : JSON.stringify(body);
  }

  const response = await fetch(url, {
    method: method.toUpperCase(),
    headers: {
      "X-Access-Key": config.accessKey,
      "X-Secret-Key": config.secretKey,
      "Content-Type": "application/json",
    },
    body: requestBody,
  });

  const text = await response.text();
  if (!response.ok) {
    die(`request failed: HTTP ${response.status} ${text}`);
  }
  return text;
}

function printUsage() {
  console.log(`cordys - Cordys CRM CLI

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
`);
}

async function main() {
  const [cmd, ...args] = process.argv.slice(2);

  if (!cmd || cmd === "help" || cmd === "-h" || cmd === "--help") {
    printUsage();
    return;
  }

  if (cmd === "crm") {
    const [subCmd, ...rest] = args;
    if (!subCmd) {
      die("crm requires a subcommand");
    }

    switch (subCmd) {
      case "view":
        if (rest.length < 1) {
          die("view requires a module");
        }
        console.log(await apiRequest("GET", `/${rest[0]}/view/list`, { query: rest[1] || "" }));
        return;
      case "get":
        if (rest.length < 2) {
          die("get requires <module> <id>");
        }
        console.log(await apiRequest("GET", `/${rest[0]}/${rest[1]}`));
        return;
      case "page":
        if (rest.length < 1) {
          die("page requires a module");
        }
        console.log(await apiRequest("POST", `/${rest[0]}/page`, { body: payloadOrKeyword(rest[1] || "") }));
        return;
      case "search":
        if (rest.length < 1) {
          die("search requires a module");
        }
        console.log(await apiRequest("POST", `/global/search/${rest[0]}`, { body: payloadOrKeyword(rest[1] || "") }));
        return;
      case "follow":
        if (rest.length < 2) {
          die("follow requires <plan|record> <module>");
        }
        if (!["plan", "record"].includes(rest[0])) {
          die("follow only supports plan or record");
        }
        console.log(await apiRequest("POST", `/${rest[1]}/follow/${rest[0]}/page`, { body: payloadOrKeyword(rest[2] || "") }));
        return;
      case "product":
        console.log(await apiRequest("POST", "/field/source/product", { body: payloadOrKeyword(rest[0] || "") }));
        return;
      case "contact":
        if (rest.length < 2) {
          die("contact requires <module> <id>");
        }
        console.log(await apiRequest("GET", `/${rest[0]}/contact/list/${rest[1]}`));
        return;
      case "org":
        console.log(await apiRequest("GET", "/department/tree"));
        return;
      case "members":
        if (rest.length < 1) {
          die("members requires a JSON body");
        }
        console.log(await apiRequest("POST", "/user/list", { body: rest[0] }));
        return;
      default:
        die(`unknown crm subcommand: ${subCmd}`);
    }
  }

  if (cmd === "raw") {
    if (args.length < 2) {
      die("raw requires <method> <path>");
    }
    const [method, targetPath, body = ""] = args;
    console.log(await apiRequest(method, targetPath, { body }));
    return;
  }

  die(`unknown command: ${cmd}`);
}

main().catch((error) => die(error instanceof Error ? error.message : String(error)));
