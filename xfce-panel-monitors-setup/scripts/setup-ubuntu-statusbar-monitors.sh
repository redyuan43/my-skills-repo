#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ubuntu-statusbar-monitors"
BIN_DIR="${HOME}/.local/bin"
AUTOSTART_DIR="${HOME}/.config/autostart"
APP_PATH="${BIN_DIR}/${APP_NAME}.py"
DESKTOP_PATH="${AUTOSTART_DIR}/${APP_NAME}.desktop"
REFRESH_SECONDS="${REFRESH_SECONDS:-2}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-0}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

python_deps_ok() {
  python3 - <<'PY' >/dev/null 2>&1
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
try:
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3
except (ImportError, ValueError):
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3
PY
}

ensure_deps() {
  need_cmd python3
  need_cmd ip

  if python_deps_ok; then
    return
  fi

  local packages=(python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 gnome-shell-extension-appindicator)
  if [[ "$AUTO_INSTALL_DEPS" == "1" ]] && command -v apt-get >/dev/null 2>&1; then
    echo "Installing Ubuntu AppIndicator dependencies: ${packages[*]}"
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
    python_deps_ok && return
  fi

  echo "Missing Python AppIndicator dependencies." >&2
  echo "Install them after user confirmation with:" >&2
  echo "  sudo apt-get install -y ${packages[*]}" >&2
  echo "Or rerun this script with AUTO_INSTALL_DEPS=1." >&2
  exit 1
}

write_indicator_app() {
  mkdir -p "$BIN_DIR"
  cat > "$APP_PATH" <<'PY_EOF'
#!/usr/bin/env python3
import os
import signal
import subprocess
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk
try:
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3 as AppIndicator
except (ImportError, ValueError):
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator


APP_ID = "ubuntu-statusbar-monitors"
REFRESH_SECONDS = max(1, int(os.environ.get("REFRESH_SECONDS", "2")))


def read_meminfo():
    data = {}
    with open("/proc/meminfo", "r", encoding="utf-8") as fh:
        for line in fh:
            key, value = line.split(":", 1)
            data[key] = int(value.strip().split()[0])
    total = data.get("MemTotal", 0)
    available = data.get("MemAvailable", 0)
    used = max(0, total - available)
    return used, total


def format_kib(kib):
    return f"{kib / 1024 / 1024:.1f}G"


def read_cpu_total_idle():
    with open("/proc/stat", "r", encoding="utf-8") as fh:
        fields = fh.readline().split()[1:]
    values = [int(item) for item in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    return sum(values), idle


class Metrics:
    def __init__(self):
        self.prev_total, self.prev_idle = read_cpu_total_idle()
        self.cpu_percent = 0
        self.gpu_cache = (0, "GPU n/a", "GMem n/a", "nvidia-smi not found")

    def update_cpu(self):
        total, idle = read_cpu_total_idle()
        total_delta = max(1, total - self.prev_total)
        idle_delta = max(0, idle - self.prev_idle)
        self.cpu_percent = round((1 - idle_delta / total_delta) * 100)
        self.prev_total, self.prev_idle = total, idle

    def update_gpu(self):
        now = time.monotonic()
        cached_at, gpu_text, gmem_text, tooltip = self.gpu_cache
        if now - cached_at < 4:
            return gpu_text, gmem_text, tooltip

        if not shutil_which("nvidia-smi"):
            self.gpu_cache = (now, "GPU n/a", "GMem n/a", "nvidia-smi not found")
            return self.gpu_cache[1:]

        query = [
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits",
        ]
        try:
            output = subprocess.check_output(query, text=True, timeout=1.5, stderr=subprocess.DEVNULL)
            row = output.strip().splitlines()[0]
            usage, mem_used, mem_total, temp, power = [part.strip() or "?" for part in row.split(",")[:5]]
            gpu_text = f"GPU {usage}%"
            if mem_used.isdigit() and mem_total.isdigit():
                gmem_text = f"GMem {int(mem_used) / 1024:.1f}/{int(mem_total) / 1024:.1f}G"
            else:
                gmem_text = "GMem ?"
            tooltip = "\n".join([
                f"GPU usage: {usage}%",
                f"GPU memory: {mem_used}/{mem_total} MiB",
                f"Temperature: {temp} C",
                f"Power: {power} W",
            ])
        except Exception as exc:
            gpu_text = "GPU ?"
            gmem_text = "GMem ?"
            tooltip = f"nvidia-smi failed: {exc}"

        self.gpu_cache = (now, gpu_text, gmem_text, tooltip)
        return gpu_text, gmem_text, tooltip

    def ipv4_rows(self):
        try:
            output = subprocess.check_output(
                ["ip", "-o", "-4", "addr", "show", "scope", "global"],
                text=True,
                timeout=1.5,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            return []

        rows = []
        for line in output.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                rows.append((parts[1], parts[3].split("/")[0]))
        return rows

    def snapshot(self):
        self.update_cpu()
        used, total = read_meminfo()
        gpu_text, gmem_text, gpu_tooltip = self.update_gpu()
        rows = self.ipv4_rows()
        if rows:
            ip_index = int(time.time() / 3) % len(rows)
            ip_text = f"IP {rows[ip_index][1]}"
            ip_tooltip = "IPv4 addresses:\n" + "\n".join(f"{name} {addr}" for name, addr in rows)
        else:
            ip_text = "IP none"
            ip_tooltip = "No non-loopback IPv4 address found"

        ram_text = f"RAM {format_kib(used)}/{format_kib(total)}"
        details = "\n".join([
            f"CPU: {self.cpu_percent}%",
            gpu_tooltip,
            f"RAM: {format_kib(used)} / {format_kib(total)}",
            ip_tooltip,
        ])
        return {
            "cpu": f"CPU {self.cpu_percent}%",
            "gpu": gpu_text,
            "gmem": gmem_text,
            "ram": ram_text,
            "ip": ip_text,
            "details": details,
        }


def shutil_which(cmd):
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        path = os.path.join(directory, cmd)
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


class MetricIndicator:
    def __init__(self, indicator_id, fallback_icon, label_width, on_refresh, on_quit):
        self.indicator = AppIndicator.Indicator.new(
            indicator_id,
            fallback_icon,
            AppIndicator.IndicatorCategory.SYSTEM_SERVICES,
        )
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.details_item = Gtk.MenuItem(label="Collecting metrics...")
        self.details_item.set_sensitive(False)
        self.label_width = label_width
        self.indicator.set_menu(self.build_menu(on_refresh, on_quit))

    def build_menu(self, on_refresh, on_quit):
        menu = Gtk.Menu()
        menu.append(self.details_item)
        menu.append(Gtk.SeparatorMenuItem())

        refresh = Gtk.MenuItem(label="Refresh all")
        refresh.connect("activate", lambda _item: on_refresh())
        menu.append(refresh)

        quit_item = Gtk.MenuItem(label="Quit monitors")
        quit_item.connect("activate", lambda _item: on_quit())
        menu.append(quit_item)

        menu.show_all()
        return menu

    def update(self, label, details):
        self.indicator.set_label(label, self.label_width)
        self.details_item.set_label(details)


class MultiStatusIndicators:
    def __init__(self):
        self.metrics = Metrics()
        self.indicators = {
            "cpu": MetricIndicator(f"{APP_ID}-cpu", "utilities-system-monitor", "CPU 100%", self.update, Gtk.main_quit),
            "gpu": MetricIndicator(f"{APP_ID}-gpu", "video-display", "GPU 100%", self.update, Gtk.main_quit),
            "gmem": MetricIndicator(f"{APP_ID}-gmem", "media-flash", "GMem 99.9/99.9G", self.update, Gtk.main_quit),
            "ram": MetricIndicator(f"{APP_ID}-ram", "drive-harddisk", "RAM 999.9/999.9G", self.update, Gtk.main_quit),
            "ip": MetricIndicator(f"{APP_ID}-ip", "network-workgroup", "IP 255.255.255.255", self.update, Gtk.main_quit),
        }
        self.update()
        GLib.timeout_add_seconds(REFRESH_SECONDS, self.update)

    def update(self):
        snapshot = self.metrics.snapshot()
        details = snapshot["details"]
        for key, indicator in self.indicators.items():
            indicator.update(snapshot[key], details)
        return True


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    MultiStatusIndicators()
    Gtk.main()


if __name__ == "__main__":
    main()
PY_EOF
  chmod +x "$APP_PATH"
}

write_autostart() {
  mkdir -p "$AUTOSTART_DIR"
  cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=Ubuntu Status Bar Monitors
Comment=Show CPU, GPU, RAM and IPv4 metrics in the Ubuntu status bar
Exec=${APP_PATH}
Terminal=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;Unity;XFCE;
EOF
}

restart_indicator() {
  local pid
  local app_pattern="(^| )${APP_PATH}($| )"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(pgrep -u "$(id -u)" -f "$app_pattern" || true)

  if [[ -n "${DISPLAY:-}" ]]; then
    setsid -f "$APP_PATH" >/tmp/${APP_NAME}.log 2>&1 </dev/null
    sleep 2
    if ! pgrep -u "$(id -u)" -f "$app_pattern" >/dev/null 2>&1; then
      echo "Indicator failed to stay running. Recent log:" >&2
      sed -n '1,80p' "/tmp/${APP_NAME}.log" >&2 || true
      exit 1
    fi
  else
    echo "DISPLAY is not set; autostart is installed but the indicator was not started now."
  fi
}

main() {
  ensure_deps
  write_indicator_app
  write_autostart
  restart_indicator

  echo "Configured Ubuntu/GNOME status bar monitors:"
  echo "  App: ${APP_PATH}"
  echo "  Autostart: ${DESKTOP_PATH}"
  echo "  Refresh seconds: ${REFRESH_SECONDS}"
}

main "$@"
