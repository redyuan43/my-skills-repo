#!/usr/bin/env bash
set -euo pipefail

USER_AGENT="${LMSTUDIO_UA:-Mozilla/5.0}"
INSTALL_ROOT="${LMSTUDIO_INSTALL_ROOT:-$HOME/.local/opt/lmstudio}"
BIN_LINK="${LMSTUDIO_BIN_LINK:-$HOME/.local/bin/lmstudio}"
DESKTOP_FILE="${LMSTUDIO_DESKTOP_FILE:-$HOME/.local/share/applications/lmstudio.desktop}"
EXTRA_ARGS="${LMSTUDIO_EXTRA_ARGS:---no-sandbox}"
KEEP_VERSIONS=2

usage() {
  cat <<'EOF'
用法:
  lmstudio_auto_update.sh status
  lmstudio_auto_update.sh check
  lmstudio_auto_update.sh update
  lmstudio_auto_update.sh prune [--keep N]
  lmstudio_auto_update.sh rewrite-desktop
  lmstudio_auto_update.sh install-user-timer
  lmstudio_auto_update.sh uninstall-user-timer
  lmstudio_auto_update.sh help

环境变量:
  LMSTUDIO_INSTALL_ROOT   自定义 AppImage 安装目录
  LMSTUDIO_BIN_LINK       自定义 lmstudio 软链路径
  LMSTUDIO_DESKTOP_FILE   自定义桌面启动器路径
  LMSTUDIO_EXTRA_ARGS     启动器附加参数，默认 --no-sandbox
  LMSTUDIO_UA             自定义下载时的 User-Agent
EOF
}

log() {
  printf '[lmstudio-auto-updater] %s\n' "$*"
}

die() {
  printf '[lmstudio-auto-updater] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)
      printf 'x64\n'
      ;;
    aarch64|arm64)
      printf 'arm64\n'
      ;;
    *)
      die "暂不支持的架构: ${machine}"
      ;;
  esac
}

current_path() {
  if [ -L "$BIN_LINK" ] || [ -e "$BIN_LINK" ]; then
    readlink -f "$BIN_LINK"
    return 0
  fi

  if command -v lmstudio >/dev/null 2>&1; then
    readlink -f "$(command -v lmstudio)"
    return 0
  fi

  return 1
}

extract_version_from_name() {
  local path base
  path="${1:-}"
  base="$(basename "$path")"
  if [[ "$base" =~ ^LM-Studio-([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)-(x64|arm64)\.(AppImage|deb)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

assert_appimage_layout() {
  local path
  path="$(current_path || true)"
  [ -n "$path" ] || die "没有发现可用的 lmstudio 安装"
  [[ "$path" == *.AppImage ]] || die "当前 lmstudio 不是 AppImage 安装形态: ${path}"
}

latest_redirect_url() {
  local arch url
  arch="$(detect_arch)"
  url="https://lmstudio.ai/download/latest/linux/${arch}?format=AppImage"
  curl -A "$USER_AGENT" -fsSLI "$url" | tr -d '\r' | awk 'tolower($1)=="location:"{print $2; exit}'
}

latest_checksum() {
  local arch
  arch="$(detect_arch)"
  python3 - "$arch" <<'PY'
import re
import sys
import urllib.request

arch = sys.argv[1]
req = urllib.request.Request(
    "https://lmstudio.ai/download",
    headers={"User-Agent": "Mozilla/5.0"},
)
html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "ignore")
match = re.search(
    r'linuxInstallerSha512ByArch.*?x64.*?appImageSha512.*?([0-9a-f]{128}).*?arm64.*?appImageSha512.*?([0-9a-f]{128})',
    html,
    re.S,
)
if not match:
    sys.exit(0)
print(match.group(1 if arch == "x64" else 2))
PY
}

latest_metadata() {
  local url base version checksum arch
  arch="$(detect_arch)"
  url="$(latest_redirect_url)"
  [ -n "$url" ] || die "无法获取 LM Studio 最新下载地址"
  base="$(basename "$url")"
  version="$(extract_version_from_name "$base" || true)"
  checksum="$(latest_checksum || true)"
  printf 'arch=%s\n' "$arch"
  printf 'url=%s\n' "$url"
  printf 'filename=%s\n' "$base"
  printf 'version=%s\n' "$version"
  printf 'sha512=%s\n' "$checksum"
}

status_cmd() {
  local path version
  if ! path="$(current_path)"; then
    log "installed=false"
    printf 'bin_link=%s\n' "$BIN_LINK"
    return 0
  fi

  version="$(extract_version_from_name "$path" || true)"
  log "installed=true"
  printf 'bin_link=%s\n' "$BIN_LINK"
  printf 'resolved_path=%s\n' "$path"
  printf 'install_root=%s\n' "$INSTALL_ROOT"
  printf 'desktop_file=%s\n' "$DESKTOP_FILE"
  printf 'current_version=%s\n' "$version"
  printf 'detected_arch=%s\n' "$(detect_arch)"
  printf 'launch_extra_args=%s\n' "$EXTRA_ARGS"
  printf 'layout=%s\n' "$( [[ "$path" == *.AppImage ]] && printf 'appimage' || printf 'other' )"
}

check_cmd() {
  local path current latest url checksum arch update_available
  arch="$(detect_arch)"
  path="$(current_path || true)"
  current="$(extract_version_from_name "${path:-}" || true)"
  url="$(latest_redirect_url)"
  latest="$(extract_version_from_name "$url" || true)"
  checksum="$(latest_checksum || true)"
  update_available=false
  if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
    update_available=true
  fi

  printf 'arch=%s\n' "$arch"
  printf 'current_path=%s\n' "$path"
  printf 'current_version=%s\n' "$current"
  printf 'latest_url=%s\n' "$url"
  printf 'latest_version=%s\n' "$latest"
  printf 'latest_sha512=%s\n' "$checksum"
  printf 'update_available=%s\n' "$update_available"
}

ensure_dirs() {
  mkdir -p "$INSTALL_ROOT" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP_FILE")"
}

verify_sha512() {
  local file expected actual
  file="$1"
  expected="$2"
  if [ -z "$expected" ]; then
    log "未取到官方 SHA-512，跳过校验"
    return 0
  fi

  if command -v sha512sum >/dev/null 2>&1; then
    actual="$(sha512sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 512 "$file" | awk '{print $1}')"
  else
    die "缺少 sha512sum 或 shasum，无法校验下载文件"
  fi

  [ "$actual" = "$expected" ] || die "SHA-512 校验失败: expected=${expected} actual=${actual}"
}

write_desktop_file() {
  local exec_cmd
  exec_cmd="${BIN_LINK}"
  if [ -n "$EXTRA_ARGS" ]; then
    exec_cmd="${exec_cmd} ${EXTRA_ARGS}"
  fi

  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LM Studio
Comment=Discover, download, and run local LLMs
Exec=${exec_cmd} %U
TryExec=${BIN_LINK}
Terminal=false
Categories=Development;Utility;
StartupNotify=true
EOF

  sync_desktop_shortcuts
}

sync_desktop_shortcuts() {
  local desktop_dir file
  for desktop_dir in "$HOME/Desktop" "$HOME/桌面"; do
    [ -d "$desktop_dir" ] || continue
    while IFS= read -r file; do
      cp -f "$DESKTOP_FILE" "$file"
      chmod +x "$file"
      log "synced_shortcut=${file}"
    done < <(find "$desktop_dir" -maxdepth 1 -type f \( -name '*LM Studio*.desktop' -o -name 'lmstudio*.desktop' -o -name '*lmstudio*.desktop' \) 2>/dev/null)
  done
}

rewrite_desktop_cmd() {
  ensure_dirs
  write_desktop_file
  log "desktop_rewritten=${DESKTOP_FILE}"
}

update_cmd() {
  local current url filename version checksum tmpdir tmpfile target
  assert_appimage_layout
  current="$(current_path)"
  url="$(latest_redirect_url)"
  filename="$(basename "$url")"
  version="$(extract_version_from_name "$filename" || true)"
  checksum="$(latest_checksum || true)"
  target="${INSTALL_ROOT}/${filename}"

  if [ -e "$target" ] && [ "$current" = "$target" ]; then
    log "当前已经是最新版本: ${version}"
    return 0
  fi

  ensure_dirs
  tmpdir="$(mktemp -d -t lmstudio-update.XXXXXX)"
  tmpfile="${tmpdir}/${filename}"
  trap 'rm -rf "$tmpdir"' EXIT

  log "downloading=${url}"
  curl -A "$USER_AGENT" -fL --progress-bar "$url" -o "$tmpfile"
  chmod +x "$tmpfile"
  verify_sha512 "$tmpfile" "$checksum"
  mv -f "$tmpfile" "$target"
  chmod +x "$target"
  ln -sfn "$target" "$BIN_LINK"
  write_desktop_file

  log "updated_to=${target}"
  log "previous=${current}"
  rm -rf "$tmpdir"
  trap - EXIT
}

prune_cmd() {
  local keep="$KEEP_VERSIONS"
  while [ $# -gt 0 ]; do
    case "$1" in
      --keep)
        keep="${2:-}"
        shift 2
        ;;
      *)
        die "未知参数: $1"
        ;;
    esac
  done

  ensure_dirs
  mapfile -t files < <(find "$INSTALL_ROOT" -maxdepth 1 -type f -name 'LM-Studio-*-*.AppImage' -printf '%T@ %p\n' | sort -nr | awk '{print $2}')
  if [ "${#files[@]}" -le "$keep" ]; then
    log "无需清理，现有版本数=${#files[@]} keep=${keep}"
    return 0
  fi

  local idx current
  current="$(current_path || true)"
  for (( idx=keep; idx<${#files[@]}; idx++ )); do
    if [ "${files[$idx]}" = "$current" ]; then
      log "跳过当前正在使用的版本: ${files[$idx]}"
      continue
    fi
    log "removing=${files[$idx]}"
    rm -f "${files[$idx]}"
  done
}

user_systemd_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
}

install_user_timer_cmd() {
  local dir service timer script_path
  dir="$(user_systemd_dir)"
  script_path="$(readlink -f "$0")"
  mkdir -p "$dir"
  service="${dir}/lmstudio-auto-update.service"
  timer="${dir}/lmstudio-auto-update.timer"

  cat >"$service" <<EOF
[Unit]
Description=Update LM Studio AppImage for current user

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash ${script_path} update
EOF

  cat >"$timer" <<'EOF'
[Unit]
Description=Run LM Studio AppImage updater daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now lmstudio-auto-update.timer
  log "installed_user_timer=true"
}

uninstall_user_timer_cmd() {
  local dir
  dir="$(user_systemd_dir)"
  systemctl --user disable --now lmstudio-auto-update.timer >/dev/null 2>&1 || true
  rm -f "${dir}/lmstudio-auto-update.timer" "${dir}/lmstudio-auto-update.service"
  systemctl --user daemon-reload
  log "installed_user_timer=false"
}

main() {
  need_cmd curl
  need_cmd python3
  case "${1:-help}" in
    status)
      shift
      status_cmd "$@"
      ;;
    check)
      shift
      check_cmd "$@"
      ;;
    update)
      shift
      update_cmd "$@"
      ;;
    prune)
      shift
      prune_cmd "$@"
      ;;
    rewrite-desktop)
      shift
      rewrite_desktop_cmd "$@"
      ;;
    install-user-timer)
      shift
      install_user_timer_cmd "$@"
      ;;
    uninstall-user-timer)
      shift
      uninstall_user_timer_cmd "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      die "未知子命令: ${1}"
      ;;
  esac
}

main "$@"
