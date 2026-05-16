#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  run_video_link_analysis_publisher.sh VIDEO_URL [options]

Options:
  --repo PATH              video-analyzer repo path (default: /home/ivan/github/video-analyzer)
  --profile NAME           runtime profile (default: local_lan)
  --analysis-mode MODE     auto|long-talk-fast|fast|balanced|deep (default: auto)
  --run-name NAME          operation run name (default: operation-manual)
  --run-dir PATH           existing run directory; required with --skip-operation
  --operation-extra ARGS   extra args passed to tools/run_operation_manual_from_url.sh
  --skip-operation         reuse --run-dir and skip URL analysis
  --skip-multidoc          skip tools/run_multidoc_analysis.sh
  --skip-deep-v2           skip illustrated chapter deep report v2 generation
  --skip-export            skip tools/export_video_docs.sh
  --skip-images            skip Baoyu prompt preparation
  -h, --help               show help
EOF
}

url="${1:-}"
if [[ "${url}" == "-h" || "${url}" == "--help" || -z "${url}" ]]; then
  usage
  exit 2
fi
shift

repo="/home/ivan/github/video-analyzer"
profile="local_lan"
analysis_mode="auto"
run_name="operation-manual"
run_dir=""
operation_extra=()
skip_operation=0
skip_multidoc=0
skip_export=0
skip_images=0
skip_deep_v2=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --profile)
      profile="$2"
      shift 2
      ;;
    --analysis-mode)
      analysis_mode="$2"
      shift 2
      ;;
    --run-name)
      run_name="$2"
      shift 2
      ;;
    --run-dir)
      run_dir="$2"
      shift 2
      ;;
    --operation-extra)
      # shellcheck disable=SC2206
      extra_parts=($2)
      operation_extra+=("${extra_parts[@]}")
      shift 2
      ;;
    --skip-operation)
      skip_operation=1
      shift
      ;;
    --skip-multidoc)
      skip_multidoc=1
      shift
      ;;
    --skip-deep-v2)
      skip_deep_v2=1
      shift
      ;;
    --skip-export)
      skip_export=1
      shift
      ;;
    --skip-images)
      skip_images=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

repo="$(realpath "$repo")"
cd "$repo"

if [[ -f "$repo/tools/operation_manual_no_proxy_env.sh" ]]; then
  # Keep LAN/Tailscale model services off local proxy routes.
  source "$repo/tools/operation_manual_no_proxy_env.sh"
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
log_dir="$repo/tmp/video-link"
mkdir -p "$log_dir"
main_log="$log_dir/run_${timestamp}.log"

probe_duration_seconds() {
  local proxy_args=()
  if timeout 1 bash -c '</dev/tcp/127.0.0.1/10808' 2>/dev/null; then
    proxy_args=(--proxy "http://127.0.0.1:10808")
  fi
  yt-dlp --dump-single-json --skip-download --no-playlist "${proxy_args[@]}" "$url" 2>/dev/null \
    | python3 -c 'import json, sys; data=json.load(sys.stdin); value=data.get("duration") or 0; print(int(float(value)))' 2>/dev/null \
    || true
}

resolve_analysis_mode() {
  case "$analysis_mode" in
    auto|long-talk-fast|fast|balanced|deep)
      ;;
    *)
      echo "Unknown analysis mode: $analysis_mode" >&2
      exit 2
      ;;
  esac

  if [[ "$analysis_mode" != "auto" ]]; then
    echo "$analysis_mode"
    return
  fi

  local duration
  duration="$(probe_duration_seconds)"
  if [[ "$duration" =~ ^[0-9]+$ ]] && [[ "$duration" -ge 2700 ]]; then
    echo "long-talk-fast"
    return
  fi
  if [[ "$duration" =~ ^[0-9]+$ ]] && [[ "$duration" -gt 0 ]]; then
    echo "balanced"
    return
  fi
  echo "[operation] could not detect video duration for auto mode; using balanced" >&2
  echo "balanced"
}

if [[ "$skip_operation" -eq 0 ]]; then
  resolved_mode="$(resolve_analysis_mode)"
  echo "[operation] starting URL analysis mode=$resolved_mode"
  operation_cmd=()
  case "$resolved_mode" in
    long-talk-fast)
      operation_cmd=(tools/run_long_talk_fast_from_url.sh "$url" --run-name "$run_name")
      ;;
    fast|balanced|deep)
      operation_cmd=(
        tools/run_operation_manual_from_url.sh "$url"
        --profile "$profile"
        --run-name "$run_name"
        --pipeline-mode "$resolved_mode"
      )
      ;;
  esac
  operation_cmd+=("${operation_extra[@]}")
  set +e
  "${operation_cmd[@]}" 2>&1 | tee "$main_log"
  status=${PIPESTATUS[0]}
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "Operation manual stage failed. Log: $main_log" >&2
    exit "$status"
  fi
  run_dir="$(awk -F': ' '/^\[done\] run_dir: /{value=$2} END{print value}' "$main_log")"
fi

if [[ -z "$run_dir" ]]; then
  echo "--run-dir is required when --skip-operation is used or run_dir was not detected" >&2
  exit 2
fi
run_dir="$(realpath "$run_dir")"
echo "RUN_DIR=$run_dir"

if [[ "$skip_multidoc" -eq 0 ]]; then
  echo "[multidoc] generating knowledge_notes, deep_report, and review"
  tools/run_multidoc_analysis.sh "$run_dir" --profile "$profile"
fi

if [[ "$skip_deep_v2" -eq 0 ]]; then
  echo "[deep-v2] generating illustrated chapter report and review"
  python3 tools/generate_chapter_deep_report.py "$run_dir" \
    --profile "$profile" \
    --deep-v2 \
    --no-final-synthesis \
    --no-format-markdown-final
fi

if [[ "$skip_export" -eq 0 ]]; then
  echo "[export] generating PDFs and long PNGs"
  LONGPNG_VIEWPORT_SIZE="${LONGPNG_VIEWPORT_SIZE:-1600,1000}" \
    LONGPNG_NO_MARGIN="${LONGPNG_NO_MARGIN:-1}" \
    LONGPNG_CONTENT_PADDING="${LONGPNG_CONTENT_PADDING:-16}" \
    tools/export_video_docs.sh "$run_dir"
fi

if [[ "$skip_images" -eq 0 ]]; then
  echo "[images] preparing Baoyu image prompts"
  "$HOME/.codex/skills/video-link/scripts/prepare_baoyu_image_prompts.py" "$run_dir"
fi

echo "[done] RUN_DIR=$run_dir"
echo "[done] log=$main_log"
