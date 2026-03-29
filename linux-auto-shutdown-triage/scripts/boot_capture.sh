#!/usr/bin/env bash
set -euo pipefail

REPORT_ROOT="/var/log/auto-shutdown-monitor/reports"
TARGET_USER=""
TARGET_UID=""
TARGET_RUNTIME_DIR=""
TARGET_BUS=""

usage() {
  cat <<'EOF'
Usage:
  boot_capture.sh [options]

Options:
  --report-root PATH   Report root directory. Default: /var/log/auto-shutdown-monitor/reports
  --user USER          Target desktop user for live-session gsettings snapshot
  -h, --help           Show this help
EOF
}

while (($#)); do
  case "$1" in
    --report-root)
      REPORT_ROOT="${2:-}"
      shift 2
      ;;
    --user)
      TARGET_USER="${2:-}"
      shift 2
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

if [[ -n "${TARGET_USER}" ]]; then
  TARGET_UID="$(id -u "${TARGET_USER}" 2>/dev/null || true)"
  if [[ -n "${TARGET_UID}" && -S "/run/user/${TARGET_UID}/bus" ]]; then
    TARGET_RUNTIME_DIR="/run/user/${TARGET_UID}"
    TARGET_BUS="unix:path=${TARGET_RUNTIME_DIR}/bus"
  fi
fi

NOW="$(date '+%Y%m%d-%H%M%S')"
REPORT_DIR="${REPORT_ROOT}/${NOW}"
PSTORE_DIR="${REPORT_DIR}/pstore"
SUMMARY_FILE="${REPORT_DIR}/summary.md"

mkdir -p "${REPORT_DIR}" "${PSTORE_DIR}"

capture() {
  local name="$1"
  shift
  local -a cmd=("$@")

  {
    printf '$'
    for arg in "${cmd[@]}"; do
      printf ' %q' "${arg}"
    done
    printf '\n\n'
    "${cmd[@]}" 2>&1 || true
  } > "${REPORT_DIR}/${name}"
}

capture_filtered_journal() {
  {
    cat <<'EOF'
$ journalctl -b 0 --no-pager -o short-full | grep -E 'restoring from recorded timestamp|Dirty bit is set|Filesystem was changed|not properly unmounted|suspend|watchdog|pstore|ramoops|panic|oom|thermal|NVRM|Xid|nvme|EXT4-fs error|I/O error'

EOF
    journalctl -b 0 --no-pager -o short-full \
      | grep -E 'restoring from recorded timestamp|Dirty bit is set|Filesystem was changed|not properly unmounted|suspend|watchdog|pstore|ramoops|panic|oom|thermal|NVRM|Xid|nvme|EXT4-fs error|I/O error' \
      || true
  } > "${REPORT_DIR}/journal-focus.log"
}

capture_voltage_snapshot() {
  local hwmon_dir=""

  for candidate in /sys/bus/i2c/devices/1-0040/hwmon/hwmon*; do
    if [[ -d "${candidate}" ]]; then
      hwmon_dir="${candidate}"
      break
    fi
  done

  {
    cat <<'EOF'
$ sensors

EOF
    sensors 2>&1 || true

    if [[ -n "${hwmon_dir}" ]]; then
      printf '\n$ find -L %q -maxdepth 1 \\\\( -name "in*_input" -o -name "in*_label" -o -name "curr*_input" -o -name "curr*_label" -o -name "power*_input" -o -name "power*_label" \\\\)\n\n' "${hwmon_dir}"
      find -L "${hwmon_dir}" -maxdepth 1 \
        \( -name 'in*_input' -o -name 'in*_label' -o -name 'curr*_input' -o -name 'curr*_label' -o -name 'power*_input' -o -name 'power*_label' \) \
        -print 2>/dev/null | sort | while read -r path; do
          printf '%s: ' "${path}"
          cat "${path}" 2>/dev/null || true
        done || true
    else
      printf '\nNo INA3221 hwmon directory found under /sys/bus/i2c/devices\n'
    fi
  } > "${REPORT_DIR}/voltage-snapshot.log"
}

capture_watchdog_snapshot() {
  local watchdog_dir=""

  watchdog_dir="$(readlink -f /sys/class/watchdog/watchdog0 2>/dev/null || true)"

  {
    cat <<'EOF'
$ systemctl show -p RuntimeWatchdogUSec -p RebootWatchdogUSec -p ShutdownWatchdogUSec

EOF
    systemctl show -p RuntimeWatchdogUSec -p RebootWatchdogUSec -p ShutdownWatchdogUSec 2>&1 || true
    printf '\n$ journalctl -b 0 --no-pager | grep -i watchdog\n\n'
    journalctl -b 0 --no-pager | grep -i watchdog || true

    if [[ -n "${watchdog_dir}" ]]; then
      printf '\n$ readlink -f /sys/class/watchdog/watchdog0\n\n%s\n' "${watchdog_dir}"
      printf '\n$ find -L %q -maxdepth 2 -type f\n\n' "${watchdog_dir}"
      find -L "${watchdog_dir}" -maxdepth 2 -type f 2>/dev/null | sort | while read -r path; do
        printf '%s: ' "${path}"
        cat "${path}" 2>/dev/null || true
      done || true
    else
      printf '\nNo watchdog sysfs node found at /sys/class/watchdog/watchdog0\n'
    fi
  } > "${REPORT_DIR}/watchdog.log"
}

capture_pstore_snapshot() {
  {
    printf '$ ls -la /sys/fs/pstore\n\n'
    ls -la /sys/fs/pstore 2>&1 || true
  } > "${REPORT_DIR}/pstore-list.log"

  if find /sys/fs/pstore -mindepth 1 -maxdepth 1 | grep -q .; then
    find /sys/fs/pstore -mindepth 1 -maxdepth 1 -type f | while read -r path; do
      cp -f "${path}" "${PSTORE_DIR}/$(basename "${path}")" 2>/dev/null || true
    done || true
  fi
}

capture_session_topology() {
  {
    cat <<'EOF'
$ loginctl list-sessions --no-legend

EOF
    loginctl list-sessions --no-legend 2>&1 || true
    printf '\n$ loginctl show-session ...\n\n'
    loginctl list-sessions --no-legend 2>/dev/null | while read -r sid _; do
      printf '## session %s\n' "${sid}"
      loginctl show-session "${sid}" -p Name -p Service -p Type -p Class -p State -p Remote -p Display -p Seat 2>&1 || true
      printf '\n'
    done || true
    printf '$ sed -n 1,160p /etc/gdm3/custom.conf\n\n'
    sed -n '1,160p' /etc/gdm3/custom.conf 2>&1 || true
    printf '\n$ systemctl is-active gdm.service xrdp.service xrdp-sesman.service\n\n'
    systemctl is-active gdm.service xrdp.service xrdp-sesman.service 2>&1 || true
    printf '\n$ pgrep -a -f "gnome-shell|gsd-power|xfce4-session|xfce4-power-manager|xrdp|xrdp-sesman"\n\n'
    pgrep -a -f "gnome-shell|gsd-power|xfce4-session|xfce4-power-manager|xrdp|xrdp-sesman" 2>&1 || true
  } > "${REPORT_DIR}/session-topology.log"
}

capture_live_gnome_settings() {
  {
    if [[ -z "${TARGET_USER}" ]]; then
      printf 'No target user provided. Use --user USER to capture live-session gsettings.\n'
      return 0
    fi

    printf 'Target user: %s\n' "${TARGET_USER}"
    printf 'Target uid: %s\n\n' "${TARGET_UID:-unknown}"

    if [[ -n "${TARGET_BUS}" ]]; then
      printf '$ sudo -u %q env XDG_RUNTIME_DIR=%q DBUS_SESSION_BUS_ADDRESS=%q gsettings list-recursively org.gnome.settings-daemon.plugins.power\n\n' \
        "${TARGET_USER}" "${TARGET_RUNTIME_DIR}" "${TARGET_BUS}"
      sudo -u "${TARGET_USER}" env XDG_RUNTIME_DIR="${TARGET_RUNTIME_DIR}" DBUS_SESSION_BUS_ADDRESS="${TARGET_BUS}" \
        gsettings list-recursively org.gnome.settings-daemon.plugins.power 2>&1 || true
    else
      printf 'No live session bus found for user %s under /run/user/%s/bus\n' "${TARGET_USER}" "${TARGET_UID:-unknown}"
    fi
  } > "${REPORT_DIR}/gnome-live-power.log"
}

capture "date.txt" date
capture "uptime-s.txt" uptime -s
capture "who-b.txt" who -b
capture "last-x.txt" bash -lc "last -x | head -n 40"
capture "journal-list-boots.txt" journalctl --list-boots
capture "journal-current-boot-head.log" bash -lc "journalctl -b 0 --no-pager -o short-full | head -n 400"
capture "journal-previous-boot.log" journalctl -b -1 --no-pager -o short-full
capture "syslog-keywords.log" bash -lc "grep -a -nE 'shutdown|reboot|suspend|watchdog|pstore|ramoops|panic|oom|thermal|nvme|EXT4-fs error|I/O error|NVRM|Xid|power key|gpio-keys|under.?voltage|brownout|throttle' /var/log/syslog /var/log/kern.log /var/log/auth.log | tail -n 800"
capture "system-conf-watchdog.txt" bash -lc "systemd-analyze cat-config systemd/system.conf | grep -n 'Watchdog' || true"
capture "system-units.txt" bash -lc "systemctl cat nvmemwarning.service nvramoopsconfig.service gdm.service xrdp.service xrdp-sesman.service 2>/dev/null || true"
capture_filtered_journal
capture_watchdog_snapshot
capture_voltage_snapshot
capture_pstore_snapshot
capture_session_topology
capture_live_gnome_settings

{
  echo "# Boot Evidence Summary"
  echo
  echo "- Captured at: $(date '+%F %T %Z')"
  echo "- Current boot start: $(uptime -s 2>/dev/null || echo unknown)"
  echo "- Report dir: ${REPORT_DIR}"
  echo "- Previous boot journal available: $(if journalctl -b -1 -n 1 >/dev/null 2>&1; then echo yes; else echo no; fi)"
  echo "- pstore files captured: $(find "${PSTORE_DIR}" -type f | wc -l)"
  echo
  echo "## Key Files"
  echo
  echo "- \`last-x.txt\`"
  echo "- \`journal-list-boots.txt\`"
  echo "- \`journal-focus.log\`"
  echo "- \`journal-previous-boot.log\`"
  echo "- \`watchdog.log\`"
  echo "- \`voltage-snapshot.log\`"
  echo "- \`pstore-list.log\`"
  echo "- \`session-topology.log\`"
  echo "- \`gnome-live-power.log\`"
  echo "- \`syslog-keywords.log\`"
} > "${SUMMARY_FILE}"

if [[ -n "${TARGET_USER}" ]] && id "${TARGET_USER}" >/dev/null 2>&1; then
  chown -R "${TARGET_USER}:${TARGET_USER}" "${REPORT_ROOT}" || true
fi
