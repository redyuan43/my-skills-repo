#!/usr/bin/env bash
set -euo pipefail

desktop_dir="${HOME}/Desktop"
script_path="${desktop_dir}/jtop-restart-and-run.sh"
desktop_file="${desktop_dir}/JTop.desktop"
sudoers_file="/etc/sudoers.d/jtop-restart-nopasswd"
want_nopasswd="false"

if [[ "${1:-}" == "--nopasswd" ]]; then
  want_nopasswd="true"
fi

mkdir -p "${desktop_dir}"

if [[ "${want_nopasswd}" == "true" ]]; then
  printf '%s\n' "${USER} ALL=(root) NOPASSWD: /usr/bin/systemctl restart jtop.service" | \
    sudo tee "${sudoers_file}" >/dev/null
  sudo chmod 440 "${sudoers_file}"
  sudo visudo -cf "${sudoers_file}"
  sudo_cmd='sudo -n /usr/bin/systemctl restart jtop.service'
  restart_error='未能免密重启 jtop.service，请检查 sudo 规则或服务状态。'
  intro='正在免密重启 jtop.service ...'
else
  sudo_cmd='sudo /usr/bin/systemctl restart jtop.service'
  restart_error='未能重启 jtop.service，请检查密码、sudo 权限或服务状态。'
  intro='正在使用 sudo 重启 jtop.service ...'
fi

cat > "${script_path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

echo "${intro}"

if ! ${sudo_cmd}; then
  echo
  echo "${restart_error}"
  echo "按回车键关闭窗口。"
  read -r
  exit 1
fi

echo "等待 jtop.service 完全就绪 ..."
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if /usr/bin/systemctl is-active --quiet jtop.service; then
    sleep 2
    echo
    echo "jtop.service 已就绪，正在启动 jtop ..."
    exec /usr/local/bin/jtop
  fi
  sleep 1
done

echo
/usr/bin/systemctl status jtop.service --no-pager -n 20 || true
echo
echo "jtop.service 在等待超时后仍未就绪。"
echo "按回车键关闭窗口。"
read -r
EOF

cat > "${desktop_file}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JTop
Comment=重启 jtop.service 并启动 jtop
Exec=xfce4-terminal --title=JTop --hold --command="${script_path}"
Terminal=false
Icon=utilities-terminal
Categories=System;Monitor;
EOF

chmod +x "${script_path}" "${desktop_file}"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "${desktop_file}"
fi

printf '已生成：\n- %s\n- %s\n' "${script_path}" "${desktop_file}"
if [[ "${want_nopasswd}" == "true" ]]; then
  printf '已写入免密 sudo 规则：\n- %s\n' "${sudoers_file}"
fi