#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[recover-vnc-xfce] %s\n' "$*"
}

die() {
  printf '[recover-vnc-xfce] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/recover_vnc_xfce.sh [options]

Options:
  --user USER                  Target desktop user. Default: sudo caller or current user
  --display :N                 VNC display number. Default: :1
  --geometry WxH               VNC geometry. Default: 1920x1080
  --depth N                    VNC color depth. Default: 24
  --terminal CMD               Default terminal helper. Default: gnome-terminal
  --browser CMD                Default browser helper. Default: chromium
  --set-multi-user-target      Set system default target to multi-user.target
  --disable-gdm                Disable and stop gdm3 if present
  --skip-package-reinstall     Skip apt reinstall step
  --skip-flatpak-chromium      Do not install/check Flatpak Chromium
  --help                       Show this help
EOF
}

TARGET_USER="${SUDO_USER:-${USER}}"
VNC_DISPLAY=":1"
VNC_GEOMETRY="1920x1080"
VNC_DEPTH="24"
TERMINAL_CMD="gnome-terminal"
BROWSER_CMD="chromium"
SET_MULTI_USER_TARGET=0
DISABLE_GDM=0
REINSTALL_PACKAGES=1
ENSURE_FLATPAK_CHROMIUM=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      TARGET_USER="${2:?missing value for --user}"
      shift 2
      ;;
    --display)
      VNC_DISPLAY="${2:?missing value for --display}"
      shift 2
      ;;
    --geometry)
      VNC_GEOMETRY="${2:?missing value for --geometry}"
      shift 2
      ;;
    --depth)
      VNC_DEPTH="${2:?missing value for --depth}"
      shift 2
      ;;
    --terminal)
      TERMINAL_CMD="${2:?missing value for --terminal}"
      shift 2
      ;;
    --browser)
      BROWSER_CMD="${2:?missing value for --browser}"
      shift 2
      ;;
    --set-multi-user-target)
      SET_MULTI_USER_TARGET=1
      shift
      ;;
    --disable-gdm)
      DISABLE_GDM=1
      shift
      ;;
    --skip-package-reinstall)
      REINSTALL_PACKAGES=0
      shift
      ;;
    --skip-flatpak-chromium)
      ENSURE_FLATPAK_CHROMIUM=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "run as root or via sudo"
getent passwd "$TARGET_USER" >/dev/null || die "user not found: $TARGET_USER"

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -d "$TARGET_HOME" ] || die "home directory not found: $TARGET_HOME"

VNC_PORT="590${VNC_DISPLAY#:}"
BACKUP_BASE="$TARGET_HOME/.config/vnc-xfce-recovery-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"
HOOK_DIR="$TARGET_HOME/.config/vnc-startup-hooks.d"
SERVICE_PATH="/etc/systemd/system/vncserver-headless.service"

run_as_user() {
  sudo -u "$TARGET_USER" -H "$@"
}

write_file_as_user() {
  local path="$1"
  local mode="$2"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$(dirname "$path")"
  install -m "$mode" -o "$TARGET_USER" -g "$TARGET_USER" "$tmp" "$path"
  rm -f "$tmp"
}

backup_path() {
  local src="$1"
  local rel="$2"
  if [ -e "$src" ] || [ -L "$src" ]; then
    install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$(dirname "$BACKUP_DIR/$rel")"
    mv "$src" "$BACKUP_DIR/$rel"
  fi
}

log "target user: $TARGET_USER"
log "target home: $TARGET_HOME"
log "display: $VNC_DISPLAY (port $VNC_PORT)"

if [ "$REINSTALL_PACKAGES" -eq 1 ]; then
  log "reinstalling dbus, selinux policy, tigervnc, and xfce packages"
  apt-get update
  apt-get install -y --reinstall \
    dbus \
    dbus-user-session \
    dbus-x11 \
    flatpak \
    gnome-terminal \
    policycoreutils \
    selinux-policy-default \
    selinux-utils \
    tigervnc-standalone-server \
    thunar \
    xfce4 \
    xfce4-goodies \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xfce4-terminal \
    xfdesktop4 \
    xfwm4
fi

[ -f /etc/selinux/default/contexts/dbus_contexts ] || die "/etc/selinux/default/contexts/dbus_contexts is still missing"

log "backing up existing user configuration into $BACKUP_DIR"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$BACKUP_DIR"
backup_path "$TARGET_HOME/.config/xfce4" ".config/xfce4"
backup_path "$TARGET_HOME/.cache/sessions" ".cache/sessions"
backup_path "$TARGET_HOME/.config/autostart" ".config/autostart"
backup_path "$TARGET_HOME/.config/xfce4/helpers.rc" ".config/xfce4/helpers.rc"
backup_path "$TARGET_HOME/.vnc/xstartup" ".vnc/xstartup"
backup_path "$TARGET_HOME/.vnc/config" ".vnc/config"
backup_path "$TARGET_HOME/.local/bin/chromium" ".local/bin/chromium"
backup_path "$TARGET_HOME/.local/share/applications/chromium.desktop" ".local/share/applications/chromium.desktop"

install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.vnc"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.config"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.config/autostart"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.local/bin"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.local/share/applications"
install -d -m 755 -o "$TARGET_USER" -g "$TARGET_USER" "$HOOK_DIR"

write_file_as_user "$TARGET_HOME/.local/bin/vnc-poststart-hooks.sh" 700 <<'EOF'
#!/usr/bin/env bash
set -eu

hook_dir="${HOME}/.config/vnc-startup-hooks.d"
log_file="${HOME}/.vnc/poststart-hooks.log"

sleep "${VNC_HOOK_DELAY:-8}"

[ -d "$hook_dir" ] || exit 0

for hook in "$hook_dir"/*; do
  [ -f "$hook" ] || continue
  [ -x "$hook" ] || continue
  "$hook" >>"$log_file" 2>&1 || true
done
EOF

write_file_as_user "$TARGET_HOME/.vnc/xstartup" 700 <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

"$HOME/.local/bin/vnc-poststart-hooks.sh" >"$HOME/.vnc/poststart-hooks-launch.log" 2>&1 &

exec startxfce4
EOF

write_file_as_user "$TARGET_HOME/.vnc/config" 600 <<EOF
extension = SELinux
EOF

write_file_as_user "$TARGET_HOME/.config/xfce4/helpers.rc" 644 <<EOF
TerminalEmulator=$TERMINAL_CMD
WebBrowser=$BROWSER_CMD
EOF

write_file_as_user "$TARGET_HOME/.local/bin/chromium" 755 <<'EOF'
#!/bin/sh
exec flatpak run org.chromium.Chromium "$@"
EOF

write_file_as_user "$TARGET_HOME/.local/share/applications/chromium.desktop" 644 <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium
Comment=Launch Flatpak Chromium
Exec=__TARGET_HOME__/.local/bin/chromium %U
Icon=chromium-browser
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF

sed -i "s|__TARGET_HOME__|$TARGET_HOME|g" "$TARGET_HOME/.local/share/applications/chromium.desktop"

if [ "$ENSURE_FLATPAK_CHROMIUM" -eq 1 ]; then
  log "ensuring Flatpak Chromium exists for $TARGET_USER"
  if ! run_as_user flatpak remotes --columns=name | grep -qx flathub; then
    run_as_user flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
  if ! run_as_user flatpak info org.chromium.Chromium >/dev/null 2>&1; then
    run_as_user flatpak install -y flathub org.chromium.Chromium
  fi
fi

if [ -x "$TARGET_HOME/.local/bin/vnc-audio-server-setup.sh" ]; then
  log "restoring vnc audio autostart"
  write_file_as_user "$TARGET_HOME/.config/autostart/vnc-audio-setup.desktop" 644 <<'EOF'
[Desktop Entry]
Type=Application
Name=VNC Audio Setup
Comment=Expose the VNC session audio sink over PulseAudio TCP
Exec=__TARGET_HOME__/.local/bin/vnc-audio-server-setup.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
  sed -i "s|__TARGET_HOME__|$TARGET_HOME|g" "$TARGET_HOME/.config/autostart/vnc-audio-setup.desktop"
fi

if [ -x /usr/bin/wechat ] || [ -f /usr/share/applications/wechat.desktop ]; then
  log "disabling wechat autostart override"
  write_file_as_user "$TARGET_HOME/.config/autostart/wechat.desktop" 644 <<'EOF'
[Desktop Entry]
Type=Application
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
EOF
fi

if [ "$SET_MULTI_USER_TARGET" -eq 1 ]; then
  log "setting default target to multi-user.target"
  systemctl set-default multi-user.target
fi

if [ "$DISABLE_GDM" -eq 1 ] && systemctl list-unit-files | grep -q '^gdm3\.service'; then
  log "disabling gdm3"
  systemctl disable --now gdm3 || true
fi

log "installing or refreshing vncserver-headless.service"
cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Persistent TigerVNC desktop on $VNC_DISPLAY for $TARGET_USER
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=$TARGET_HOME
PAMName=login
Environment=HOME=$TARGET_HOME
Environment=USER=$TARGET_USER
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill $VNC_DISPLAY >/dev/null 2>&1 || true'
ExecStart=/bin/sh -c '/usr/bin/vncserver $VNC_DISPLAY -localhost no -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -extension SELinux; status=\$?; [ "\$status" -eq 0 ] || [ "\$status" -eq 1 ]'
ExecStop=/usr/bin/vncserver -kill $VNC_DISPLAY

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vncserver-headless.service

sleep 3

log "verification"
run_as_user vncserver -list || true
ss -ltnp | grep ":$VNC_PORT" || true

cat <<EOF

Recovery completed.

Backup:
  $BACKUP_DIR

Hook directory:
  $HOOK_DIR

Connect:
  <host-ip>:$VNC_PORT

Notes:
  - A reboot may still be useful later because dbus package upgrades can print a reboot recommendation.
  - Future startup customizations should go into $HOOK_DIR as executable scripts.
EOF
