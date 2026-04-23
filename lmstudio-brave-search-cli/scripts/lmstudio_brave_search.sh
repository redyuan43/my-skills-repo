#!/usr/bin/env bash
set -euo pipefail

LMSTUDIO_DIR="${LMSTUDIO_DIR:-$HOME/.lmstudio}"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/github/my-skills-repo/lmstudio-brave-mcp-bootstrap}"
PROXY_URL="${ALL_PROXY:-socks5h://127.0.0.1:10808}"
COUNT="3"
API_KEY="${BRAVE_API_KEY:-}"
NO_RESTART="0"
MODEL_ID="${LMSTUDIO_MODEL_ID:-local-search-model}"
LMSTUDIO_API_BASE="${LMSTUDIO_API_BASE:-http://127.0.0.1:1234/v1}"
MAX_TOKENS="${LMSTUDIO_MAX_TOKENS:-100000}"

usage() {
  cat <<'EOF'
Usage:
  lmstudio_brave_search.sh status
  lmstudio_brave_search.sh ensure [--api-key KEY] [--proxy-url URL] [--no-restart]
  lmstudio_brave_search.sh restart
  lmstudio_brave_search.sh test [--count N]
  lmstudio_brave_search.sh search "query" [--count N]
  lmstudio_brave_search.sh ask "question" [--count N] [--model MODEL_ID] [--max-tokens N]
EOF
}

die() {
  printf '[lmstudio-brave-search] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[lmstudio-brave-search] %s\n' "$*"
}

credentials_file() {
  printf '%s/credentials/brave-search.env\n' "$LMSTUDIO_DIR"
}

read_existing_key() {
  local file
  file="$(credentials_file)"
  [ -f "$file" ] || return 0
  sed -n 's/^export BRAVE_API_KEY=//p; s/^BRAVE_API_KEY=//p' "$file" \
    | tail -n 1 \
    | tr -d "\"' "
}

read_existing_proxy() {
  local file
  file="$(credentials_file)"
  [ -f "$file" ] || return 0
  sed -n 's/^export ALL_PROXY=//p; s/^ALL_PROXY=//p' "$file" \
    | tail -n 1 \
    | tr -d "\"' "
}

has_real_key() {
  local key="${1:-}"
  [ -n "$key" ] && [ "$key" != "YOUR_BRAVE_API_KEY" ]
}

require_cmds() {
  for cmd in node npm curl python3; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing dependency: $cmd"
  done
}

ensure_config() {
  require_cmds

  local existing_key existing_proxy
  existing_key="$(read_existing_key || true)"
  existing_proxy="$(read_existing_proxy || true)"

  if ! has_real_key "$API_KEY"; then
    API_KEY="$existing_key"
  fi
  has_real_key "$API_KEY" || die "BRAVE_API_KEY is missing. Put it in $(credentials_file) or pass --api-key."

  if [ -n "$existing_proxy" ]; then
    PROXY_URL="$existing_proxy"
  fi

  [ -x "$BOOTSTRAP_DIR/scripts/install_lmstudio_brave_mcp.sh" ] || die "missing bootstrap script: $BOOTSTRAP_DIR/scripts/install_lmstudio_brave_mcp.sh"

  bash "$BOOTSTRAP_DIR/scripts/install_lmstudio_brave_mcp.sh" \
    --mode custom \
    --api-key "$API_KEY" \
    --proxy-url "$PROXY_URL"

  install_node_deps
  ensure_plugin_bridge

  if [ "$NO_RESTART" != "1" ]; then
    restart_lmstudio
  fi
}

install_node_deps() {
  local server_dir="$LMSTUDIO_DIR/mcp-servers/brave-search"
  [ -f "$server_dir/brave-lmstudio-mcp.mjs" ] || die "missing MCP server: $server_dir/brave-lmstudio-mcp.mjs"
  (
    cd "$server_dir"
    if [ ! -f package.json ]; then
      npm init -y >/dev/null
    fi
    if [ ! -d node_modules/@modelcontextprotocol/sdk ]; then
      npm install @modelcontextprotocol/sdk@latest
    fi
  )
}

ensure_plugin_bridge() {
  local plugin_dir="$LMSTUDIO_DIR/extensions/plugins/mcp/brave-search"
  mkdir -p "$plugin_dir"
  python3 - "$plugin_dir/mcp-bridge-config.json" "$LMSTUDIO_DIR/bin/brave-lmstudio-mcp.sh" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
command = sys.argv[2]
path.write_text(json.dumps({"command": command, "args": []}, indent=2) + "\n", encoding="utf-8")
PY
}

restart_lmstudio() {
  local pids
  pids="$(pgrep -f '^/home/admin/.local/bin/lmstudio --no-sandbox$' || true)"
  if [ -n "$pids" ]; then
    log "stopping LM Studio: $pids"
    kill -TERM $pids || true
    for _ in $(seq 1 20); do
      pgrep -f '^/home/admin/.local/bin/lmstudio --no-sandbox$' >/dev/null || break
      sleep 0.5
    done
  fi

  local display="${DISPLAY:-:10.0}"
  log "starting LM Studio on DISPLAY=$display"
  nohup env DISPLAY="$display" XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    /home/admin/.local/bin/lmstudio --no-sandbox >/tmp/lmstudio-restart.log 2>&1 &
  sleep 8
  pgrep -af '^/home/admin/.local/bin/lmstudio --no-sandbox$' || die "LM Studio did not start; see /tmp/lmstudio-restart.log"
}

mcp_call() {
  local query="$1"
  local count="$2"
  node - "$query" "$count" "$LMSTUDIO_DIR/bin/brave-lmstudio-mcp.sh" <<'NODE'
const { spawn } = require("child_process");
const query = process.argv[2];
const count = Number(process.argv[3] || 3);
const command = process.argv[4];
const child = spawn(command, [], { stdio: ["pipe", "pipe", "pipe"] });
let buffer = "";
let nextId = 1;
const pending = new Map();
const timeout = setTimeout(() => {
  console.error("timeout waiting for MCP response");
  child.kill("SIGTERM");
  process.exit(2);
}, 30000);

function send(method, params) {
  const id = nextId++;
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  return new Promise((resolve) => pending.set(id, resolve));
}

child.stdout.on("data", (chunk) => {
  buffer += chunk.toString();
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});
child.stderr.on("data", (chunk) => process.stderr.write(chunk));

(async () => {
  await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "lmstudio-brave-search-cli", version: "1.0.0" },
  });
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} }) + "\n");
  const tools = await send("tools/list", {});
  const names = (tools.result?.tools || []).map((tool) => tool.name).filter((name) => name.startsWith("brave_"));
  console.log("TOOLS " + names.join(","));
  const result = await send("tools/call", {
    name: "brave_web_search",
    arguments: { query, count },
  });
  const text = (result.result?.content || []).map((item) => item.text || "").join("\n");
  console.log("SEARCH_RESULT " + text.replace(/\s+/g, " ").slice(0, 2000));
  clearTimeout(timeout);
  child.kill("SIGTERM");
})();
NODE
}

ask_local_model() {
  local question="$1"
  local count="$2"
  node - "$question" "$count" "$LMSTUDIO_DIR/bin/brave-lmstudio-mcp.sh" "$LMSTUDIO_API_BASE" "$MODEL_ID" "$MAX_TOKENS" <<'NODE'
const { spawn } = require("child_process");
const question = process.argv[2];
const count = Number(process.argv[3] || 5);
const command = process.argv[4];
const apiBase = process.argv[5].replace(/\/$/, "");
const model = process.argv[6];
const maxTokens = Number(process.argv[7] || 100000);

async function callMcpSearch(query, count) {
  const child = spawn(command, [], { stdio: ["pipe", "pipe", "pipe"] });
  let buffer = "";
  let nextId = 1;
  const pending = new Map();
  const timeout = setTimeout(() => {
    console.error("timeout waiting for MCP response");
    child.kill("SIGTERM");
    process.exit(2);
  }, 30000);

  function send(method, params) {
    const id = nextId++;
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    return new Promise((resolve) => pending.set(id, resolve));
  }

  child.stdout.on("data", (chunk) => {
    buffer += chunk.toString();
    let idx;
    while ((idx = buffer.indexOf("\n")) >= 0) {
      const line = buffer.slice(0, idx).trim();
      buffer = buffer.slice(idx + 1);
      if (!line) continue;
      let msg;
      try { msg = JSON.parse(line); } catch { continue; }
      if (msg.id && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
      }
    }
  });
  child.stderr.on("data", (chunk) => {
    const text = chunk.toString();
    if (!text.includes("running on stdio")) process.stderr.write(text);
  });

  await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "lmstudio-brave-search-cli", version: "1.0.0" },
  });
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} }) + "\n");
  const result = await send("tools/call", {
    name: "brave_web_search",
    arguments: { query, count },
  });
  clearTimeout(timeout);
  child.kill("SIGTERM");
  return (result.result?.content || []).map((item) => item.text || "").join("\n");
}

function compactSearchJson(raw) {
  try {
    const data = JSON.parse(raw);
    const results = data.web?.results || data.news?.results || [];
    return results.slice(0, count).map((item, index) => ({
      index: index + 1,
      title: item.title,
      url: item.url,
      age: item.page_age,
      description: item.description,
      source: item.profile?.long_name || item.profile?.name,
    }));
  } catch {
    return raw.slice(0, 6000);
  }
}

async function callLmStudio(question, evidence) {
  const system = [
    "你是运行在本机 LM Studio 中的本地大模型。",
    "你必须基于给定的 Brave 搜索材料回答；如果材料不足，要明确说明。",
    "回答要用中文，区分事实、推断和不确定性。",
    "如果涉及市场或投资，只做风险分析，不给个性化投资建议。",
    "最终答案必须写在最后的普通 content 中，不要只停留在 reasoning_content。",
    "结尾列出关键来源链接。",
  ].join("\n");
  const user = `用户问题：${question}\n\nBrave 搜索材料 JSON：\n${JSON.stringify(evidence, null, 2)}`;
  const response = await fetch(`${apiBase}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      temperature: 0.2,
      max_tokens: maxTokens,
      stream: false,
    }),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`LM Studio API failed: ${response.status} ${text}`);
  }
  const data = await response.json();
  return data.choices?.[0]?.message?.content || JSON.stringify(data);
}

(async () => {
  const raw = await callMcpSearch(question, count);
  const evidence = compactSearchJson(raw);
  const answer = await callLmStudio(question, evidence);
  console.log(answer.trim());
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
NODE
}

status() {
  local key
  key="$(read_existing_key || true)"
  if has_real_key "$key"; then
    printf 'key=present len=%s sha256=%s\n' "${#key}" "$(printf '%s' "$key" | sha256sum | cut -c1-12)"
  else
    printf 'key=missing_or_placeholder\n'
  fi
  printf 'credentials=%s\n' "$(credentials_file)"
  printf 'mcp_json=%s/mcp.json\n' "$LMSTUDIO_DIR"
  printf 'wrapper=%s/bin/brave-lmstudio-mcp.sh\n' "$LMSTUDIO_DIR"
  printf 'server=%s/mcp-servers/brave-search/brave-lmstudio-mcp.mjs\n' "$LMSTUDIO_DIR"
}

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 1; }
shift || true

query=""
while [ $# -gt 0 ]; do
  case "$1" in
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --proxy-url)
      PROXY_URL="${2:-}"
      shift 2
      ;;
    --count)
      COUNT="${2:-3}"
      shift 2
      ;;
    --model)
      MODEL_ID="${2:-}"
      shift 2
      ;;
    --max-tokens)
      MAX_TOKENS="${2:-100000}"
      shift 2
      ;;
    --no-restart)
      NO_RESTART="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$query" ]; then
        query="$1"
      else
        query="$query $1"
      fi
      shift
      ;;
  esac
done

case "$cmd" in
  status)
    status
    ;;
  ensure)
    ensure_config
    ;;
  restart)
    restart_lmstudio
    ;;
  test)
    mcp_call "LM Studio official documentation" "$COUNT"
    ;;
  search)
    [ -n "$query" ] || die "search requires a query"
    mcp_call "$query" "$COUNT"
    ;;
  ask)
    [ -n "$query" ] || die "ask requires a question"
    ask_local_model "$query" "$COUNT"
    ;;
  *)
    usage
    exit 1
    ;;
esac
