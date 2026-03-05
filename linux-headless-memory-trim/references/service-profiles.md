# Service Profiles

## STOP_DISABLE_DEFAULT

以下服务通常可在“纯推理无头”场景停用（根据设备角色增减）：

- `jtop.service`
- `docker.service`
- `containerd.service`
- `docker.socket`
- `bluetooth.service`
- `ModemManager.service`
- `avahi-daemon.service`
- `avahi-daemon.socket`
- `openvpn.service`（仅当不使用 OpenVPN）
- `snapd.service`
- `snapd.socket`
- `snap.cups.cupsd.service`
- `snap.cups.cups-browsed.service`
- `gdm.service`（或对应 display-manager）

## KEEP_UNCHANGED

以下项目默认保持不改，除非用户明确要求：

- `ollama.service`
- `ssh.service`
- `NetworkManager.service`
- `systemd-resolved.service`
- `wpa_supplicant.service`（Wi-Fi 设备）
- `nvfancontrol.service`、`nvpmodel.service`（Jetson 常见）
- 业务进程与其依赖

## OPTIONAL_UNINSTALL_PACKAGES

仅在确认长期不需要时再执行卸载：

- Docker: `docker.io`/`docker-ce`、`containerd`
- 通信与发现：`modemmanager`、`avahi-daemon`
- 桌面：`gdm3`、桌面元包
- Snap：`snapd`（注意依赖链）

## Verification Checklist

- `free -h`：观察 used/swap 变化
- `ps aux --sort=-%mem | head`：确认高占用常驻减少
- `systemctl get-default`：应为 `multi-user.target`
- `systemctl is-active ollama.service ssh.service NetworkManager.service`：应保持 active
- `systemctl --failed`：应无失败单元
