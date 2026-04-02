#!/usr/bin/env bash
set -euo pipefail

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/autocutsel.desktop"
DISPLAY_VALUE="${DISPLAY:-:0}"
XAUTHORITY_VALUE="${XAUTHORITY:-$HOME/.Xauthority}"

if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
  echo "[ERROR] 当前会话不是 X11：XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-<empty>}" >&2
  echo "[HINT] 这个脚本只适用于 X11 + Remmina 的剪贴板桥接问题。" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "[ERROR] 未找到 sudo，无法安装 autocutsel。" >&2
  exit 1
fi

if ! command -v autocutsel >/dev/null 2>&1; then
  echo "[INFO] 正在安装 autocutsel..."
  sudo apt-get install -y autocutsel
else
  echo "[INFO] autocutsel 已安装，跳过安装步骤。"
fi

mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Autocutsel Clipboard Bridge
Comment=Sync X11 PRIMARY selection and clipboard for Remmina and other X11 apps
Exec=/bin/sh -lc 'autocutsel -fork; autocutsel -selection PRIMARY -buttonup -fork'
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP

echo "[INFO] 已写入自启动文件：$AUTOSTART_FILE"

pkill -f 'autocutsel -selection PRIMARY -buttonup -fork' >/dev/null 2>&1 || true
pkill -f '^autocutsel -fork$' >/dev/null 2>&1 || true

DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" autocutsel -fork
DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" autocutsel -selection PRIMARY -buttonup -fork

echo "[INFO] 已在当前会话启动 autocutsel。"
echo "[INFO] DISPLAY=$DISPLAY_VALUE"
echo "[INFO] XAUTHORITY=$XAUTHORITY_VALUE"
echo
pgrep -af autocutsel || true
echo
echo "[NEXT] 现在请在 Remmina 里复制一段文本，再到本地应用里按 Ctrl+V 验证。"
