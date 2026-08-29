# Peer Relay 操作手册

本手册使用示例地址，执行时替换为真实值：

- 严格 NAT 后的目标节点：`100.64.0.10`
- Relay 的 Tailscale IP：`100.64.0.20`
- Relay 的稳定公网端点：`203.0.113.10:40000`

## 1. 变更前证据

在客户端、目标和候选 Relay 上交叉执行：

```bash
tailscale status
tailscale ping --c 5 <other-node>
tailscale netcheck
```

在客户端检查 SSH 最终配置：

```bash
ssh -G <ssh-alias> | sed -n '/^hostname /p; /^user /p; /^port /p; /^proxyjump /p; /^proxycommand /p'
```

应用基线应分开测量：

```bash
curl --noproxy '*' -o /dev/null -sS \
  -w 'connect=%{time_connect} first_byte=%{time_starttransfer} total=%{time_total} size=%{size_download} speed=%{speed_download}\n' \
  'http://<target-magicdns>:<port>/<api-path>'
```

URL 中 `#fragment` 不会发送给服务器。先从浏览器开发者工具确认页面实际调用的 API 或 WebSocket 地址。

## 2. 候选 Relay 验收

不要只依据候选节点在 `tailscale status` 中显示 direct。Peer Relay 使用独立 UDP 端口，候选节点必须满足：

- 客户端和目标到它的 RTT 都低；
- 它具有稳定的公网 IPv4/IPv6 端点或可靠的静态端口映射；
- 公网端点的 UDP 端口能从任意来源入站；
- 能管理主机防火墙和云平台防火墙；
- Tailscale 版本支持 Peer Relay。

云主机产品类型要通过实例元数据或控制台确认。云服务器、轻量应用服务器等产品可能使用不同防火墙页面，不能凭公网 IP 猜控制台入口。

## 3. 配置 Relay 节点

确认影响和回滚命令后，在 Relay 节点执行：

```bash
sudo tailscale set \
  --relay-server-port=40000 \
  --relay-server-static-endpoints='203.0.113.10:40000'
```

若使用 UFW：

```bash
sudo ufw allow 40000/udp comment 'Tailscale peer relay'
sudo ufw status numbered
```

还要在云平台防火墙/安全组中放行公网入站 UDP 40000。主机防火墙已放行不代表云边界已放行；Relay 主动发出的 STUN 响应也不能证明任意客户端能主动打入该端口。

## 4. 添加最小 tailnet grant

下面仅允许目标节点 `100.64.0.10` 使用 Relay `100.64.0.20`：

```json
{
  "src": ["100.64.0.10"],
  "dst": ["100.64.0.20"],
  "app": {
    "tailscale.com/cap/relay": []
  }
}
```

把该对象加入现有 `grants` 数组，不覆盖其他 policy。保存前预览变更并保留原 policy 副本。若多个严格 NAT 节点需要 Relay，逐一列出节点或使用受控 tag，避免 `src: ["*"]`。

## 5. 验证控制面和数据面

在 Relay 上抓取独立端口：

```bash
sudo tcpdump -ni any udp port 40000
```

从客户端和目标分别向公网端点发送测试 UDP：

```bash
printf probe | nc -u -w 1 203.0.113.10 40000
```

然后检查：

```bash
tailscale status
tailscale ping --c 5 <target>
```

期望 `tailscale status` 对目标显示 `peer-relay <public-endpoint>:vni:<id>`。VNI 已分配只说明 policy 与控制面已就绪；如果抓包看不到双方流量，继续检查静态端点、NAT 和两层防火墙。

需要关联日志中的 disco key 与节点时，可检查：

```bash
tailscale debug netmap
```

## 6. 应用层验收

分别验证：

- SSH：测量从命令开始到远端输出的总耗时；
- HTTP：分别记录首字节、完整响应大小、总耗时和吞吐；
- WebSocket：使用 `wscat`、应用客户端或协议测试工具完成真实握手；
- 实时音频：计算编码码率并确认有稳定余量、低抖动和可接受丢包。

通过 HTTP 代理执行 WebSocket curl 可能只测到代理行为。对比 `env | rg -i 'proxy'` 与 `curl --noproxy '*'`，但不要因绕过代理略有改善就忽略 Relay 吞吐瓶颈。

## 7. 回滚

先停止把新流量引向 Relay，再撤销网络开放。按环境确认后执行：

1. 从 tailnet policy 删除新增的 relay grant，并保存；
2. 在 Relay 节点关闭功能：

   ```bash
   sudo tailscale set --relay-server-port='' --relay-server-static-endpoints=''
   ```

3. 删除主机防火墙规则；UFW 可先用 `sudo ufw status numbered` 找到规则编号，再执行 `sudo ufw delete <number>`；
4. 删除云平台 UDP 入站规则；
5. 重新运行路径与应用基线，确认回到预期状态。

## 8. 官方资料

- [Tailscale Peer Relay](https://tailscale.com/docs/features/peer-relay)
- [设备连接与 direct/DERP 路径](https://tailscale.com/docs/reference/device-connectivity)
- [防火墙端口说明](https://tailscale.com/docs/reference/faq/firewall-ports)
