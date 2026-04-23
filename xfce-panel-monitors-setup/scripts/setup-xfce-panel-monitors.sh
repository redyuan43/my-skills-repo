#!/usr/bin/env bash
set -euo pipefail

PANEL_ID="${PANEL_ID:-1}"
GPU_REFRESH_MS="${GPU_REFRESH_MS:-2000}"
IP_REFRESH_MS="${IP_REFRESH_MS:-3000}"
BIN_DIR="${HOME}/.local/bin"
PANEL_RC_DIR="${HOME}/.config/xfce4/panel"
PANEL_XML="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
BACKUP_DIR="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/backups"
GPU_SCRIPT="${BIN_DIR}/xfce-gpu-usage"
IP_SCRIPT="${BIN_DIR}/xfce-ipv4-rotator"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ensure_panel_plugins() {
  local missing=()
  [[ -f /usr/share/xfce4/panel/plugins/cpugraph.desktop ]] || missing+=(xfce4-cpugraph-plugin)
  [[ -f /usr/share/xfce4/panel/plugins/genmon.desktop ]] || missing+=(xfce4-genmon-plugin)

  if ((${#missing[@]} == 0)); then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing missing Xfce panel plugins: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  else
    echo "Missing Xfce panel plugins: ${missing[*]}" >&2
    echo "Install them with your distro package manager, then run this script again." >&2
    exit 1
  fi
}

write_helper_scripts() {
  mkdir -p "$BIN_DIR"

  cat > "$GPU_SCRIPT" <<'GPU_EOF'
#!/usr/bin/env bash
set -uo pipefail

format_kib() {
  awk -v kib="$1" 'BEGIN { printf "%.1fG", kib / 1024 / 1024 }'
}

format_mib() {
  awk -v mib="$1" 'BEGIN { printf "%.1fG", mib / 1024 }'
}

if ! command -v nvidia-smi >/dev/null 2>&1; then
  mem_total_kib="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
  mem_available_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  mem_used_kib=$((mem_total_kib - mem_available_kib))
  mem_total="$(format_kib "$mem_total_kib")"
  mem_used="$(format_kib "$mem_used_kib")"
  printf '<txt>GPU n/a</txt><tool>nvidia-smi not found\nSystem memory: %s / %s</tool>\n' "$mem_used" "$mem_total"
  exit 0
fi

query_output="$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | head -n 1 || true)"

if [[ -z "${query_output// }" ]]; then
  printf '<txt>GPU ?%%</txt><tool>nvidia-smi did not return GPU metrics</tool>\n'
  exit 0
fi

IFS=',' read -r usage temp power <<< "$query_output"
usage="${usage//[[:space:]]/}"
temp="${temp//[[:space:]]/}"
power="${power//[[:space:]]/}"

[[ -n "$usage" ]] || usage="?"
[[ -n "$temp" ]] || temp="?"
[[ -n "$power" ]] || power="?"

mem_total_kib="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
mem_available_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
mem_used_kib=$((mem_total_kib - mem_available_kib))
mem_total="$(format_kib "$mem_total_kib")"
mem_used="$(format_kib "$mem_used_kib")"

gpu_mem_mib="$(nvidia-smi 2>/dev/null | awk '
  /MiB[[:space:]]*\|$/ {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^[0-9]+MiB$/) {
        gsub("MiB", "", $i)
        sum += $i
      }
    }
  }
  END { print sum + 0 }
')"
gpu_mem="$(format_mib "$gpu_mem_mib")"

tooltip="GPU usage: ${usage}%"
tooltip+=$'\n'"GPU process memory: ${gpu_mem}"
tooltip+=$'\n'"System memory: ${mem_used} / ${mem_total}"
tooltip+=$'\n'"Temperature: ${temp} C"
tooltip+=$'\n'"Power: ${power} W"

case $(( ($(date +%s) / 2) % 3 )) in
  0) panel_text="GPU ${usage}%" ;;
  1) panel_text="GMem ${gpu_mem}" ;;
  *) panel_text="RAM ${mem_used}/${mem_total}" ;;
esac

printf '<txt>%s</txt><tool>%s</tool>\n' "$panel_text" "$tooltip"
GPU_EOF

  cat > "$IP_SCRIPT" <<'IP_EOF'
#!/usr/bin/env bash
set -uo pipefail

mapfile -t rows < <(ip -o -4 addr show scope global 2>/dev/null | awk '{split($4, a, "/"); print $2 " " a[1]}')

if ((${#rows[@]} == 0)); then
  printf '<txt> IP none</txt><tool>No non-loopback IPv4 address found</tool>\n'
  exit 0
fi

period=3
index=$(( ($(date +%s) / period) % ${#rows[@]} ))
selected="${rows[$index]}"
ip_addr="${selected##* }"

tooltip="IPv4 addresses:"
for row in "${rows[@]}"; do
  tooltip+=$'\n'"${row}"
done

printf '<txt> IP %s</txt><tool>%s</tool>\n' "$ip_addr" "$tooltip"
IP_EOF

  chmod +x "$GPU_SCRIPT" "$IP_SCRIPT"
}

plugin_ids() {
  xfconf-query -c xfce4-panel -p "/panels/panel-${PANEL_ID}/plugin-ids" \
    | awk '/^[[:space:]]*[0-9]+$/ {print $1}'
}

plugin_type() {
  xfconf-query -c xfce4-panel -p "/plugins/plugin-$1" 2>/dev/null || true
}

set_plugin_type() {
  local id="$1"
  local type="$2"
  if xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}" >/dev/null 2>&1; then
    xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}" -s "$type"
  else
    xfconf-query -c xfce4-panel -p "/plugins/plugin-${id}" --create -t string -s "$type"
  fi
}

next_plugin_id() {
  local max=0
  local id
  while IFS= read -r id; do
    ((id > max)) && max="$id"
  done < <(xfconf-query -c xfce4-panel -l | sed -n 's|^/plugins/plugin-\([0-9]\+\)$|\1|p')
  echo $((max + 1))
}

find_plugin_by_type() {
  local wanted="$1"
  local id
  while IFS= read -r id; do
    [[ "$(plugin_type "$id")" == "$wanted" ]] && {
      echo "$id"
      return
    }
  done < <(xfconf-query -c xfce4-panel -l | sed -n 's|^/plugins/plugin-\([0-9]\+\)$|\1|p' | sort -n)
}

find_genmon_by_command() {
  local wanted_command="$1"
  local id rc command
  while IFS= read -r id; do
    [[ "$(plugin_type "$id")" == "genmon" ]] || continue
    rc="${PANEL_RC_DIR}/genmon-${id}.rc"
    [[ -f "$rc" ]] || continue
    command="$(sed -n 's/^Command=//p' "$rc" | head -n 1)"
    [[ "$command" == "$wanted_command" ]] && {
      echo "$id"
      return
    }
  done < <(xfconf-query -c xfce4-panel -l | sed -n 's|^/plugins/plugin-\([0-9]\+\)$|\1|p' | sort -n)
}

append_missing_plugins_to_panel() {
  local ids=("$@")
  local current=()
  local id wanted exists
  mapfile -t current < <(plugin_ids)

  for wanted in "${ids[@]}"; do
    exists=0
    for id in "${current[@]}"; do
      [[ "$id" == "$wanted" ]] && exists=1
    done
    ((exists == 1)) || current+=("$wanted")
  done

  local cmd=(xfconf-query -c xfce4-panel -p "/panels/panel-${PANEL_ID}/plugin-ids")
  for id in "${current[@]}"; do
    cmd+=(-t int -s "$id")
  done
  "${cmd[@]}"
}

write_genmon_rc() {
  local id="$1"
  local command="$2"
  local update_period="$3"
  mkdir -p "$PANEL_RC_DIR"
  cat > "${PANEL_RC_DIR}/genmon-${id}.rc" <<EOF
Command=${command}
UseLabel=0
Text=
UpdatePeriod=${update_period}
Font=Sans 10
EOF
}

main() {
  need_cmd xfconf-query
  need_cmd xfce4-panel
  need_cmd ip
  need_cmd awk

  ensure_panel_plugins
  write_helper_scripts

  if [[ -f "$PANEL_XML" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$PANEL_XML" "${BACKUP_DIR}/xfce4-panel.xml.$(date +%Y%m%d-%H%M%S).monitors.bak"
  fi

  local cpu_id gpu_id ip_id
  cpu_id="$(find_plugin_by_type cpugraph || true)"
  if [[ -z "$cpu_id" ]]; then
    cpu_id="$(next_plugin_id)"
    set_plugin_type "$cpu_id" cpugraph
  fi

  gpu_id="$(find_genmon_by_command "$GPU_SCRIPT" || true)"
  if [[ -z "$gpu_id" ]]; then
    gpu_id="$(next_plugin_id)"
    set_plugin_type "$gpu_id" genmon
  fi

  ip_id="$(find_genmon_by_command "$IP_SCRIPT" || true)"
  if [[ -z "$ip_id" ]]; then
    ip_id="$(next_plugin_id)"
    set_plugin_type "$ip_id" genmon
  fi

  append_missing_plugins_to_panel "$cpu_id" "$gpu_id" "$ip_id"

  xfce4-panel --quit >/tmp/xfce4-panel-monitors-quit.log 2>&1 || true
  sleep 2
  write_genmon_rc "$gpu_id" "$GPU_SCRIPT" "$GPU_REFRESH_MS"
  write_genmon_rc "$ip_id" "$IP_SCRIPT" "$IP_REFRESH_MS"
  nohup xfce4-panel >/tmp/xfce4-panel-monitors-start.log 2>&1 &
  sleep 3

  echo "Configured Xfce panel monitors on panel-${PANEL_ID}:"
  echo "  CPU plugin: plugin-${cpu_id}"
  echo "  GPU/RAM rotator: plugin-${gpu_id} -> ${GPU_SCRIPT}"
  echo "  IPv4 rotator: plugin-${ip_id} -> ${IP_SCRIPT}"
}

main "$@"
