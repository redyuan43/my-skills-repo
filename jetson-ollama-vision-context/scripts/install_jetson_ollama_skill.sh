#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="jetson-ollama-vision-context"
SKILL_ROOT="${HOME}/.codex/skills"
MODEL="qwen3.5:latest"
CTX="32768"
KEEP_ALIVE="4h"
NUM_PARALLEL="1"
HOST_BIND="0.0.0.0:11434"
GPU_MEM_FRACTION="0.9"
DRY_RUN="0"
NO_PULL="0"

usage() {
  cat <<USAGE
用法:
  $(basename "$0") [选项]

选项:
  --skill-root <dir>      skill 安装目录 (默认: ~/.codex/skills)
  --model <name>          模型名 (默认: qwen3.5:latest)
  --ctx <num>             默认上下文 (默认: 32768)
  --keep-alive <dur>      模型保活时长 (默认: 4h)
  --num-parallel <num>    并发数 (默认: 1)
  --host-bind <addr>      Ollama 绑定地址 (默认: 0.0.0.0:11434)
  --no-pull               不执行模型拉取
  --dry-run               仅打印将执行的步骤，不落盘
  -h, --help              显示帮助
USAGE
}

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERR ] %s\n' "$*" >&2; exit 1; }

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY ] %s\n' "$*"
  else
    eval "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-root) SKILL_ROOT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --ctx) CTX="$2"; shift 2 ;;
    --keep-alive) KEEP_ALIVE="$2"; shift 2 ;;
    --num-parallel) NUM_PARALLEL="$2"; shift 2 ;;
    --host-bind) HOST_BIND="$2"; shift 2 ;;
    --no-pull) NO_PULL="1"; shift ;;
    --dry-run) DRY_RUN="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

[[ "$CTX" =~ ^[0-9]+$ ]] || die "--ctx 必须为正整数"
[[ "$NUM_PARALLEL" =~ ^[0-9]+$ ]] || die "--num-parallel 必须为正整数"

for c in bash mkdir cat chmod install sed systemctl sudo ollama curl; do
  command -v "$c" >/dev/null 2>&1 || die "缺少命令: $c"
done

SKILL_DIR="${SKILL_ROOT}/${SKILL_NAME}"
SCRIPTS_DIR="${SKILL_DIR}/scripts"
REFS_DIR="${SKILL_DIR}/references"
AGENTS_DIR="${SKILL_DIR}/agents"

log "安装 skill 到: ${SKILL_DIR}"
run_cmd "mkdir -p \"${SCRIPTS_DIR}\" \"${REFS_DIR}\" \"${AGENTS_DIR}\""

if [[ "$DRY_RUN" == "0" ]]; then
  cat > "${SKILL_DIR}/SKILL.md" <<'EOF'
---
name: jetson-ollama-vision-context
description: 在 Jetson 等共享显存/内存设备上配置和排查 Ollama 的上下文窗口，并验证 qwen3.5 的图片识别与性能指标。用于以下场景：模型显示 context 过小（如 4096）、怀疑模型不支持图片、需要在 16G 级设备上确定可稳定运行的 num_ctx、需要生成可复现的性能测试结果。
---

# Jetson Ollama Vision Context

## Quick Start

1. 检查模型能力与当前加载状态。

```bash
ollama show qwen3.5:latest
ollama ps
```

2. 使用脚本验证图片识别与性能。

```bash
scripts/ollama_vision_perf.sh --image "/abs/path/test.png" --model "qwen3.5:latest" --ctx 32768 --repeat 1
```

3. 使用脚本探测可用上下文区间。

```bash
scripts/ollama_context_probe.sh --model "qwen3.5:latest" --ctx-list "4096,8192,16384,24576,32768"
```

## Workflow

1. 先验证能力，不猜测。
- 运行 `ollama show <model>`，确认 `Capabilities` 是否包含 `vision`。
- 运行一次图片请求，确认 `done=true` 且 `message.content` 为图片内容描述。

2. 再做上下文探测。
- 从小到大递增 `num_ctx`，观察是否报错、是否触发 OOM、时延是否可接受。
- 记录 `ollama ps`、`free -m`、`tegrastats`（Jetson）作为证据。

3. 最后固化默认配置。
- 在 systemd 环境使用 `OLLAMA_CONTEXT_LENGTH`，不要使用 `OLLAMA_MAX_CONTEXT`。
- 配置后重启服务并复测。

## Critical Notes

- 在 Ollama 0.17.6，默认上下文由显存自动决策，Jetson 16G 常见默认是 `4096`。
- `qwen3.5:latest` 支持图片，但必须按 chat API 的 `messages[].images` 传 base64。
- 共享显存/内存设备上，高 `num_ctx` 可能触发 OOM。实测经验（Orin NX 16G）见 [references/jetson-findings.md](references/jetson-findings.md)。
- 若目标是超长上下文 + 多图，优先采用分块/RAG 或更小模型，而不是盲目拉满窗口。

## Resources

- `scripts/ollama_vision_perf.sh`: 单图识别 + 性能统计（load/total/prompt/eval/token/s）+ 内存快照。
- `scripts/ollama_context_probe.sh`: 批量探测不同 `num_ctx` 的可用性。
- `references/jetson-findings.md`: Jetson 16G 的已验证参数与故障特征。
EOF

  cat > "${AGENTS_DIR}/openai.yaml" <<'EOF'
interface:
  display_name: "Jetson Ollama Vision Context"
  short_description: "在Jetson设备上配置Ollama上下文并验证Qwen3.5图片识别与性能"
  default_prompt: "在Jetson上排查Ollama上下文限制、验证qwen3.5读图并输出性能指标"
EOF

  cat > "${REFS_DIR}/jetson-findings.md" <<'EOF'
# Jetson Orin NX 16G Findings (Ollama 0.17.6 + qwen3.5:latest)

## Confirmed Facts

- `qwen3.5:latest` 能力包含 `vision`，支持图片输入。
- 仅在调用 `/api/chat` 且将图片放入 `messages[].images`（base64）时可触发视觉。
- 服务环境变量应使用 `OLLAMA_CONTEXT_LENGTH`；`OLLAMA_MAX_CONTEXT` 不生效。

## Context Observations

- `num_ctx=32768`：可成功，返回正常。
- `num_ctx=200000`：触发 OOM，`ollama.service` 被系统杀死并重启。
- 200K 失败日志特征：
  - `KvSize:200000`
  - `total memory size="17.6 GiB"`
  - `A process of this unit has been killed by the OOM killer`

## Practical Defaults for 16G Shared Memory

- 稳妥档：`8192 ~ 24576`
- 可尝试档：`32768`
- 高风险档：`>=65536`（依赖并发、系统负载、图像大小）

## Recommended Systemd Snippet

```ini
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=24576"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_KEEP_ALIVE=4h"
```

说明：
- 在 16G 设备先用 `OLLAMA_NUM_PARALLEL=1` 降低并发挤占。
- 若追求高 context，请优先降低并发和 keep-alive，再逐步提升 context。
EOF

  cat > "${SCRIPTS_DIR}/ollama_vision_perf.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HOST="http://127.0.0.1:11434"
MODEL="qwen3.5:latest"
IMAGE=""
PROMPT="请描述这张图片里有什么"
NUM_CTX="32768"
KEEP_ALIVE="4h"
REPEAT=1

usage() {
  cat <<USAGE
用法:
  $(basename "$0") --image "/abs/path/image.png" [选项]

选项:
  --model <name>        模型名 (默认: ${MODEL})
  --image <path>        图片路径 (必填)
  --prompt <text>       提示词 (默认: ${PROMPT})
  --ctx <num>           num_ctx (默认: ${NUM_CTX})
  --host <url>          Ollama 地址 (默认: ${HOST})
  --keep-alive <dur>    keep_alive (默认: ${KEEP_ALIVE})
  --repeat <n>          连续测试次数 (默认: ${REPEAT})
  -h, --help            显示帮助
USAGE
}

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "缺少命令: $c" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --ctx) NUM_CTX="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --keep-alive) KEEP_ALIVE="$2"; shift 2 ;;
    --repeat) REPEAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

require_cmd curl
require_cmd base64
require_cmd python3

if [[ -z "$IMAGE" ]]; then
  echo "错误: --image 必填" >&2
  usage
  exit 1
fi

if [[ ! -f "$IMAGE" ]]; then
  echo "错误: 图片不存在: $IMAGE" >&2
  exit 1
fi

if ! [[ "$NUM_CTX" =~ ^[0-9]+$ ]]; then
  echo "错误: --ctx 必须是整数" >&2
  exit 1
fi

if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || [[ "$REPEAT" -lt 1 ]]; then
  echo "错误: --repeat 必须是 >=1 的整数" >&2
  exit 1
fi

printf "== 测试配置 ==\n"
printf "host        : %s\n" "$HOST"
printf "model       : %s\n" "$MODEL"
printf "image       : %s\n" "$IMAGE"
printf "num_ctx     : %s\n" "$NUM_CTX"
printf "repeat      : %s\n" "$REPEAT"
printf "keep_alive  : %s\n" "$KEEP_ALIVE"
printf "prompt      : %s\n\n" "$PROMPT"

for i in $(seq 1 "$REPEAT"); do
  B64_FILE=$(mktemp)
  PAYLOAD_FILE=$(mktemp)
  RESP_FILE=$(mktemp)

  cleanup() {
    rm -f "$B64_FILE" "$PAYLOAD_FILE" "$RESP_FILE"
  }
  trap cleanup EXIT

  base64 -w 0 "$IMAGE" > "$B64_FILE"

  printf '{"model":"%s","stream":false,"keep_alive":"%s","options":{"num_ctx":%s},"messages":[{"role":"user","content":"' "$MODEL" "$KEEP_ALIVE" "$NUM_CTX" > "$PAYLOAD_FILE"
  printf '%s' "$PROMPT" >> "$PAYLOAD_FILE"
  printf '","images":["' >> "$PAYLOAD_FILE"
  cat "$B64_FILE" >> "$PAYLOAD_FILE"
  printf '"]}]}' >> "$PAYLOAD_FILE"

  START_MS=$(date +%s%3N)
  HTTP_CODE=$(curl -sS "$HOST/api/chat" \
    -H "Content-Type: application/json" \
    -d @"$PAYLOAD_FILE" \
    -o "$RESP_FILE" \
    -w "%{http_code}")
  END_MS=$(date +%s%3N)
  WALL_MS=$((END_MS - START_MS))

  printf -- "---- Run %s ----\n" "$i"
  printf "http_code           : %s\n" "$HTTP_CODE"
  printf "wall_time_ms        : %s\n" "$WALL_MS"

  python3 - "$RESP_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
except Exception as e:
    print(f"parse_error         : {e}")
    sys.exit(0)

if 'error' in d:
    print(f"api_error           : {d['error']}")
    sys.exit(0)

def ns_to_s(v):
    if not isinstance(v, int) or v <= 0:
        return "n/a"
    return f"{v / 1e9:.3f}s"

def tps(tokens, ns):
    if not isinstance(tokens, int) or not isinstance(ns, int) or ns <= 0:
        return "n/a"
    return f"{tokens / (ns / 1e9):.2f} tok/s"

msg = d.get('message', {}).get('content', '')
msg = msg.replace('\n', ' ').strip()
if len(msg) > 140:
    msg = msg[:140] + '...'

print(f"done                : {d.get('done')}")
print(f"answer_preview      : {msg}")
print(f"total_duration      : {ns_to_s(d.get('total_duration'))}")
print(f"load_duration       : {ns_to_s(d.get('load_duration'))}")
print(f"prompt_eval_count   : {d.get('prompt_eval_count', 'n/a')}")
print(f"prompt_eval_duration: {ns_to_s(d.get('prompt_eval_duration'))}")
print(f"eval_count          : {d.get('eval_count', 'n/a')}")
print(f"eval_duration       : {ns_to_s(d.get('eval_duration'))}")
print(f"prompt_speed        : {tps(d.get('prompt_eval_count'), d.get('prompt_eval_duration'))}")
print(f"decode_speed        : {tps(d.get('eval_count'), d.get('eval_duration'))}")
PY

  if command -v tegrastats >/dev/null 2>&1; then
    TG_LINE=$(timeout 2 tegrastats 2>/dev/null | head -n 1 || true)
    if [[ -n "$TG_LINE" ]]; then
      printf "tegrastats          : %s\n" "$TG_LINE"
    else
      printf "tegrastats          : n/a\n"
    fi
  else
    printf "tegrastats          : n/a\n"
  fi

  AVAIL_MEM=$(free -m | awk '/Mem:/ {print $7 " MB"}')
  printf "mem_available       : %s\n\n" "$AVAIL_MEM"

  cleanup
  trap - EXIT
done
EOF

  cat > "${SCRIPTS_DIR}/ollama_context_probe.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HOST="http://127.0.0.1:11434"
MODEL="qwen3.5:latest"
CTX_LIST="4096,8192,16384,24576,32768"
PROMPT="只回复OK"

usage() {
  cat <<USAGE
用法:
  $(basename "$0") [选项]

选项:
  --model <name>       模型名 (默认: ${MODEL})
  --ctx-list <csv>     上下文列表，逗号分隔 (默认: ${CTX_LIST})
  --host <url>         Ollama 地址 (默认: ${HOST})
  --prompt <text>      测试提示词 (默认: ${PROMPT})
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --ctx-list) CTX_LIST="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

command -v curl >/dev/null || { echo "缺少 curl" >&2; exit 1; }
command -v python3 >/dev/null || { echo "缺少 python3" >&2; exit 1; }

echo "model: $MODEL"
echo "ctx_list: $CTX_LIST"

IFS=',' read -r -a LIST <<< "$CTX_LIST"

for C in "${LIST[@]}"; do
  C="$(echo "$C" | xargs)"
  [[ -z "$C" ]] && continue
  [[ "$C" =~ ^[0-9]+$ ]] || { echo "skip invalid ctx: $C"; continue; }

  PAYLOAD=$(printf '{"model":"%s","stream":false,"keep_alive":"4h","options":{"num_ctx":%s},"messages":[{"role":"user","content":"%s"}]}' "$MODEL" "$C" "$PROMPT")
  RESP_FILE=$(mktemp)
  HTTP_CODE=$(curl -sS "$HOST/api/chat" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    -o "$RESP_FILE" \
    -w "%{http_code}")

  echo "--- num_ctx=$C ---"
  echo "http_code: $HTTP_CODE"
  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "status: fail"
    echo "error : http $HTTP_CODE"
    if [[ -s "$RESP_FILE" ]]; then
      head -c 300 "$RESP_FILE"; echo
    fi
    rm -f "$RESP_FILE"
    continue
  fi

  python3 - "$RESP_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    resp = f.read()
try:
    d = json.loads(resp)
except Exception as e:
    print('parse_error:', e)
    raise SystemExit(0)

if 'error' in d:
    print('status: fail')
    print('error :', d.get('error'))
else:
    print('status:', 'ok' if d.get('done') else 'unknown')
    print('total :', f"{d.get('total_duration', 0)/1e9:.3f}s" if isinstance(d.get('total_duration'), int) else 'n/a')
    print('load  :', f"{d.get('load_duration', 0)/1e9:.3f}s" if isinstance(d.get('load_duration'), int) else 'n/a')
PY
  rm -f "$RESP_FILE"

  if command -v ollama >/dev/null 2>&1; then
    ollama ps | sed -n '1,3p'
  fi
  if command -v free >/dev/null 2>&1; then
    free -m | awk '/Mem:/ {print "mem_available: "$7" MB"}'
  fi
done
EOF

  chmod +x "${SCRIPTS_DIR}/ollama_vision_perf.sh" "${SCRIPTS_DIR}/ollama_context_probe.sh"
else
  warn "dry-run: 跳过写入 skill 文件。"
fi

log "写入 Ollama systemd 覆盖配置。"
OVERRIDE_FILE="/etc/systemd/system/ollama.service.d/override.conf"
if [[ "$DRY_RUN" == "0" ]]; then
  run_cmd "sudo mkdir -p \"/etc/systemd/system/ollama.service.d\""
  if sudo test -f "$OVERRIDE_FILE"; then
    BACKUP="${OVERRIDE_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    run_cmd "sudo cp \"$OVERRIDE_FILE\" \"$BACKUP\""
    log "已备份旧配置: ${BACKUP}"
  fi

  TMP_OVERRIDE=$(mktemp)
  cat > "$TMP_OVERRIDE" <<EOF
[Service]
Environment="OLLAMA_HOST=${HOST_BIND}"
Environment="OLLAMA_KEEP_ALIVE=${KEEP_ALIVE}"
Environment="OLLAMA_CONTEXT_LENGTH=${CTX}"
Environment="OLLAMA_NUM_PARALLEL=${NUM_PARALLEL}"
Environment="OLLAMA_GPU_MEM_FRACTION=${GPU_MEM_FRACTION}"
EOF
  run_cmd "sudo install -m 0644 \"$TMP_OVERRIDE\" \"$OVERRIDE_FILE\""
  rm -f "$TMP_OVERRIDE"

  run_cmd "sudo systemctl daemon-reload"
  run_cmd "sudo systemctl restart ollama"
else
  run_cmd "sudo mkdir -p \"/etc/systemd/system/ollama.service.d\""
  run_cmd "sudo install -m 0644 \"<generated override.conf>\" \"$OVERRIDE_FILE\""
  run_cmd "sudo systemctl daemon-reload"
  run_cmd "sudo systemctl restart ollama"
fi

if [[ "$NO_PULL" == "0" ]]; then
  log "拉取模型: ${MODEL}"
  run_cmd "ollama pull \"${MODEL}\""
else
  warn "已跳过模型拉取。"
fi

log "执行最小验收。"
if [[ "$DRY_RUN" == "0" ]]; then
  run_cmd "systemctl is-active ollama"
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:11434/api/version" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  curl -fsS "http://127.0.0.1:11434/api/version" >/dev/null 2>&1 || die "Ollama API 未在 30 秒内就绪。"
  run_cmd "curl -s http://127.0.0.1:11434/api/chat -H \"Content-Type: application/json\" -d '{\"model\":\"${MODEL}\",\"stream\":false,\"messages\":[{\"role\":\"user\",\"content\":\"只回复OK\"}]}' | sed -n '1,2p'"
  run_cmd "ollama ps"
else
  run_cmd "systemctl is-active ollama"
  run_cmd "curl -s http://127.0.0.1:11434/api/chat -H \"Content-Type: application/json\" -d '{...}'"
  run_cmd "ollama ps"
fi

cat <<EOF

安装完成。
- Skill 路径: ${SKILL_DIR}
- 默认模型: ${MODEL}
- 默认上下文: ${CTX}
- 默认保活: ${KEEP_ALIVE}

前端调用地址:
- http://127.0.0.1:11434

EOF
