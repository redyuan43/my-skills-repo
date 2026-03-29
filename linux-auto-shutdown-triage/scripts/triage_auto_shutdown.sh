#!/usr/bin/env bash
set -euo pipefail

SINCE=""
UNTIL=""
APPLY_SAFE=0
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

DISABLE_GNOME_AUTO_SUSPEND=0
DISABLE_GNOME_LID=0
DISABLE_GNOME_POWER_BUTTON=0
DISABLE_XFCE_POWER_BUTTON=0
ENABLE_PERSISTENT_JOURNAL=0
DISABLE_GDM=0
SET_DEFAULT_MULTI_USER=0

TARGET_UID=""
TARGET_RUNTIME_DIR=""
TARGET_BUS=""

usage() {
  cat <<'EOF'
Usage:
  triage_auto_shutdown.sh [options]

Options:
  --since "YYYY-MM-DD HH:MM:SS"   Limit journal view start time
  --until "YYYY-MM-DD HH:MM:SS"   Limit journal view end time
  --user USER                     Target live desktop user for gsettings checks
  --apply-safe-mitigations        Apply GNOME/XFCE/journald mitigations below
  --disable-gnome-auto-suspend    Set GNOME idle suspend actions to nothing/0
  --disable-gnome-lid             Set GNOME lid-close actions to nothing
  --disable-gnome-power-button    Set GNOME power button action to nothing
  --disable-xfce-power-button     Set XFCE power button action to 0 in xfconf and XML
  --enable-persistent-journal     Enable persistent journald storage
  --disable-gdm                   Disable and stop gdm.service
  --set-default-multi-user        Switch default target to multi-user.target
  -h, --help                      Show this help

Default behavior is read-only.
EOF
}

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  "$@" 2>/dev/null || true
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

refresh_target_session() {
  TARGET_UID="$(id -u "${TARGET_USER}" 2>/dev/null || true)"
  TARGET_RUNTIME_DIR=""
  TARGET_BUS=""

  if [[ -n "${TARGET_UID}" && -S "/run/user/${TARGET_UID}/bus" ]]; then
    TARGET_RUNTIME_DIR="/run/user/${TARGET_UID}"
    TARGET_BUS="unix:path=${TARGET_RUNTIME_DIR}/bus"
  fi
}

run_live_user_bus() {
  if [[ -z "${TARGET_BUS}" ]]; then
    return 1
  fi

  if [[ "$(id -un)" == "${TARGET_USER}" ]]; then
    env XDG_RUNTIME_DIR="${TARGET_RUNTIME_DIR}" DBUS_SESSION_BUS_ADDRESS="${TARGET_BUS}" "$@" 2>/dev/null || true
  else
    sudo -u "${TARGET_USER}" env XDG_RUNTIME_DIR="${TARGET_RUNTIME_DIR}" DBUS_SESSION_BUS_ADDRESS="${TARGET_BUS}" "$@" 2>/dev/null || true
  fi
}

set_live_gsettings() {
  if [[ -z "${TARGET_BUS}" ]]; then
    printf 'Skipped: no live session bus for user %s under /run/user/%s/bus\n' "${TARGET_USER}" "${TARGET_UID:-unknown}"
    return 1
  fi

  if [[ "$(id -un)" == "${TARGET_USER}" ]]; then
    env XDG_RUNTIME_DIR="${TARGET_RUNTIME_DIR}" DBUS_SESSION_BUS_ADDRESS="${TARGET_BUS}" gsettings set "$@"
  else
    sudo -u "${TARGET_USER}" env XDG_RUNTIME_DIR="${TARGET_RUNTIME_DIR}" DBUS_SESSION_BUS_ADDRESS="${TARGET_BUS}" gsettings set "$@"
  fi
}

show_session_topology() {
  run loginctl list-sessions --no-legend
  run bash -lc 'loginctl list-sessions --no-legend | while read -r sid _; do printf "\n## session %s\n" "${sid}"; loginctl show-session "${sid}" -p Name -p Service -p Type -p Class -p State -p Remote -p Display -p Seat; done'
  run sudo sed -n '1,160p' /etc/gdm3/custom.conf
  run systemctl is-enabled gdm.service
  run systemctl is-active gdm.service
  run systemctl is-enabled xrdp.service
  run systemctl is-active xrdp.service
  run systemctl is-enabled xrdp-sesman.service
  run systemctl is-active xrdp-sesman.service
  run bash -lc 'pgrep -a -f "gnome-shell|gsd-power|xfce4-session|xfce4-power-manager|xrdp|xrdp-sesman"'
}

show_gnome_settings() {
  if ! need_cmd gsettings; then
    printf 'gsettings not found\n'
    return
  fi

  printf 'Target user: %s\n' "${TARGET_USER}"
  printf 'Target uid: %s\n' "${TARGET_UID:-unknown}"

  printf '\n[shell]\n'
  run gsettings list-recursively org.gnome.settings-daemon.plugins.power
  run gsettings get org.gnome.desktop.session idle-delay

  if [[ -n "${TARGET_BUS}" ]]; then
    printf '\n[live-session-bus]\n'
    run_live_user_bus gsettings list-recursively org.gnome.settings-daemon.plugins.power
    run_live_user_bus gsettings get org.gnome.desktop.session idle-delay
  else
    printf '\nNo live session bus found for user %s under /run/user/%s/bus\n' "${TARGET_USER}" "${TARGET_UID:-unknown}"
  fi
}

while (($#)); do
  case "$1" in
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --until)
      UNTIL="${2:-}"
      shift 2
      ;;
    --user)
      TARGET_USER="${2:-}"
      shift 2
      ;;
    --apply-safe-mitigations)
      APPLY_SAFE=1
      shift
      ;;
    --disable-gnome-auto-suspend)
      DISABLE_GNOME_AUTO_SUSPEND=1
      shift
      ;;
    --disable-gnome-lid)
      DISABLE_GNOME_LID=1
      shift
      ;;
    --disable-gnome-power-button)
      DISABLE_GNOME_POWER_BUTTON=1
      shift
      ;;
    --disable-xfce-power-button)
      DISABLE_XFCE_POWER_BUTTON=1
      shift
      ;;
    --enable-persistent-journal)
      ENABLE_PERSISTENT_JOURNAL=1
      shift
      ;;
    --disable-gdm)
      DISABLE_GDM=1
      shift
      ;;
    --set-default-multi-user)
      SET_DEFAULT_MULTI_USER=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

refresh_target_session

if (( APPLY_SAFE )); then
  DISABLE_GNOME_AUTO_SUSPEND=1
  DISABLE_GNOME_LID=1
  DISABLE_GNOME_POWER_BUTTON=1
  DISABLE_XFCE_POWER_BUTTON=1
  ENABLE_PERSISTENT_JOURNAL=1
fi

section "Timeline"
run date
run uptime -s
run who -b
run bash -lc 'last -x | head -n 20'

section "Scheduled Tasks"
run systemctl list-timers --all --no-pager
run crontab -l
run sudo sed -n '1,200p' /etc/crontab
run sudo rg -n "shutdown|poweroff|reboot|systemctl (poweroff|reboot)" /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/systemd/system
run atq

section "Manual Shutdown Evidence"
run sudo rg -n "COMMAND=/usr/sbin/(shutdown|reboot)" /var/log/auth.log /var/log/auth.log.1
run rg -n "shutdown -h now|reboot" "${HOME}/.bash_history"

section "Session Topology"
show_session_topology

section "GNOME Power Settings"
show_gnome_settings

section "XFCE Power Settings"
if need_cmd xfconf-query; then
  run xfconf-query -c xfce4-power-manager -lv
else
  printf 'xfconf-query not found\n'
fi
run sed -n '1,120p' "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml"
run sudo sed -n '1,120p' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml

section "logind And Sleep"
run sudo sed -n '1,200p' /etc/systemd/logind.conf
run sudo rg -n "IdleAction|HandlePowerKey|HandleLidSwitch" /etc/systemd/logind.conf /etc/systemd/logind.conf.d
run sudo sed -n '1,200p' /etc/systemd/sleep.conf
run sudo rg -n "SuspendState|Hibernate|Sleep" /etc/systemd/sleep.conf /etc/systemd/sleep.conf.d

section "Persistent Journal"
run ls -ld /var/log/journal
run systemd-analyze cat-config systemd/journald.conf
run journalctl --list-boots

section "Keyword Search"
run sudo rg -n "shutdown|reboot|suspend|hibernate|power key|lid|watchdog|thermal|panic|oom" /var/log/syslog /var/log/kern.log /var/log/auth.log

if [[ -n "${SINCE}" || -n "${UNTIL}" ]]; then
  section "Journal Window"
  journal_args=()
  [[ -n "${SINCE}" ]] && journal_args+=(--since "${SINCE}")
  [[ -n "${UNTIL}" ]] && journal_args+=(--until "${UNTIL}")
  run journalctl "${journal_args[@]}"
fi

if (( DISABLE_GNOME_AUTO_SUSPEND || DISABLE_GNOME_LID || DISABLE_GNOME_POWER_BUTTON || DISABLE_XFCE_POWER_BUTTON || ENABLE_PERSISTENT_JOURNAL || DISABLE_GDM || SET_DEFAULT_MULTI_USER )); then
  section "Apply Mitigations"
fi

if (( DISABLE_GNOME_AUTO_SUSPEND )); then
  if set_live_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing \
    && set_live_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 \
    && set_live_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing \
    && set_live_gsettings org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0; then
    printf 'Applied: GNOME idle suspend disabled via live session bus\n'
  fi
fi

if (( DISABLE_GNOME_LID )); then
  if set_live_gsettings org.gnome.settings-daemon.plugins.power lid-close-ac-action nothing \
    && set_live_gsettings org.gnome.settings-daemon.plugins.power lid-close-battery-action nothing; then
    printf 'Applied: GNOME lid close actions disabled via live session bus\n'
  fi
fi

if (( DISABLE_GNOME_POWER_BUTTON )); then
  if set_live_gsettings org.gnome.settings-daemon.plugins.power power-button-action nothing; then
    printf 'Applied: GNOME power button action disabled via live session bus\n'
  fi
fi

if (( DISABLE_XFCE_POWER_BUTTON )); then
  if need_cmd xfconf-query; then
    xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/power-button-action -n -t int -s 0 2>/dev/null \
      || xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/power-button-action -s 0
  fi
  if [[ -f "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" ]]; then
    perl -0pi -e 's#<property name="power-button-action" type="empty"/>#<property name="power-button-action" type="int" value="0"/>#g; s#<property name="power-button-action" type="uint" value="[0-9]+"/>#<property name="power-button-action" type="uint" value="0"/>#g; s#<property name="power-button-action" type="int" value="[0-9]+"/>#<property name="power-button-action" type="int" value="0"/>#g' "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml"
  fi
  if [[ -f /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml ]]; then
    sudo perl -0pi -e 's#<property name="power-button-action" type="uint" value="[0-9]+"/>#<property name="power-button-action" type="uint" value="0"/>#g; s#<property name="power-button-action" type="int" value="[0-9]+"/>#<property name="power-button-action" type="int" value="0"/>#g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
  fi
  printf 'Applied: XFCE power button action disabled\n'
fi

if (( ENABLE_PERSISTENT_JOURNAL )); then
  sudo install -d -m 0755 /etc/systemd/journald.conf.d
  printf '%s\n' '[Journal]' 'Storage=persistent' | sudo tee /etc/systemd/journald.conf.d/99-persistent.conf >/dev/null
  sudo install -d -m 2755 -o root -g systemd-journal /var/log/journal
  sudo systemctl restart systemd-journald
  printf 'Applied: persistent journald enabled\n'
fi

if (( DISABLE_GDM )); then
  sudo systemctl disable --now gdm.service
  printf 'Applied: gdm.service disabled and stopped\n'
fi

if (( SET_DEFAULT_MULTI_USER )); then
  sudo systemctl set-default multi-user.target
  printf 'Applied: default target set to multi-user.target\n'
fi

if (( DISABLE_GNOME_AUTO_SUSPEND || DISABLE_GNOME_LID || DISABLE_GNOME_POWER_BUTTON || DISABLE_XFCE_POWER_BUTTON || ENABLE_PERSISTENT_JOURNAL || DISABLE_GDM || SET_DEFAULT_MULTI_USER )); then
  refresh_target_session
  section "Post-Change Verification"
  show_gnome_settings
  run bash -lc 'xfconf-query -c xfce4-power-manager -lv | rg "power-button-action"'
  run journalctl --list-boots
  run systemctl is-active gdm.service
  run systemctl is-enabled gdm.service
  run systemctl get-default
fi
