#!/usr/bin/env bash
set -euo pipefail

SINCE=""
UNTIL=""
APPLY_SAFE=0
DISABLE_GNOME_AUTO_SUSPEND=0
DISABLE_GNOME_LID=0
DISABLE_GNOME_POWER_BUTTON=0
DISABLE_XFCE_POWER_BUTTON=0
ENABLE_PERSISTENT_JOURNAL=0

usage() {
  cat <<'EOF'
Usage:
  triage_auto_shutdown.sh [options]

Options:
  --since "YYYY-MM-DD HH:MM:SS"   Limit journal view start time
  --until "YYYY-MM-DD HH:MM:SS"   Limit journal view end time
  --apply-safe-mitigations        Apply all mitigations below
  --disable-gnome-auto-suspend    Set GNOME idle suspend actions to nothing/0
  --disable-gnome-lid             Set GNOME lid-close actions to nothing
  --disable-gnome-power-button    Set GNOME power button action to nothing
  --disable-xfce-power-button     Set XFCE power button action to 0 in xfconf and XML
  --enable-persistent-journal     Enable persistent journald storage
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
run last -x | head -n 20

section "Scheduled Tasks"
run systemctl list-timers --all --no-pager
run crontab -l
run sudo sed -n '1,200p' /etc/crontab
run sudo rg -n "shutdown|poweroff|reboot|systemctl (poweroff|reboot)" /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/systemd/system
run atq

section "Manual Shutdown Evidence"
run sudo rg -n "COMMAND=/usr/sbin/(shutdown|reboot)" /var/log/auth.log /var/log/auth.log.1
run rg -n "shutdown -h now|reboot" "${HOME}/.bash_history"

section "GNOME Power Settings"
if need_cmd gsettings; then
  run gsettings list-recursively org.gnome.settings-daemon.plugins.power
  run gsettings get org.gnome.desktop.session idle-delay
else
  printf 'gsettings not found\n'
fi

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

if [[ -n "$SINCE" || -n "$UNTIL" ]]; then
  section "Journal Window"
  journal_args=()
  [[ -n "$SINCE" ]] && journal_args+=(--since "$SINCE")
  [[ -n "$UNTIL" ]] && journal_args+=(--until "$UNTIL")
  run journalctl "${journal_args[@]}"
fi

if (( DISABLE_GNOME_AUTO_SUSPEND || DISABLE_GNOME_LID || DISABLE_GNOME_POWER_BUTTON || DISABLE_XFCE_POWER_BUTTON || ENABLE_PERSISTENT_JOURNAL )); then
  section "Apply Mitigations"
fi

if (( DISABLE_GNOME_AUTO_SUSPEND )); then
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
  printf 'Applied: GNOME idle suspend disabled\n'
fi

if (( DISABLE_GNOME_LID )); then
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'nothing'
  printf 'Applied: GNOME lid close actions disabled\n'
fi

if (( DISABLE_GNOME_POWER_BUTTON )); then
  gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
  printf 'Applied: GNOME power button action disabled\n'
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

if (( DISABLE_GNOME_AUTO_SUSPEND || DISABLE_GNOME_LID || DISABLE_GNOME_POWER_BUTTON || DISABLE_XFCE_POWER_BUTTON || ENABLE_PERSISTENT_JOURNAL )); then
  section "Post-Change Verification"
  run gsettings list-recursively org.gnome.settings-daemon.plugins.power | rg "sleep-inactive|lid-close|power-button-action"
  run xfconf-query -c xfce4-power-manager -lv | rg "power-button-action"
  run journalctl --list-boots
fi
