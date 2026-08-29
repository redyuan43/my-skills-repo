---
name: fix-tailscale-derp-with-peer-relay
description: 诊断 Tailscale 节点之间因严格 NAT、CGNAT、DERP 高延迟或 UDP 入站不可达导致的 SSH、HTTP、WebSocket 慢连接，并安全部署、验证和回滚 Peer Relay。适用于某一客户端访问目标节点很慢、其他节点访问正常、tailscale status 显示 relay/DERP、SSH ProxyJump 只能改善 SSH 而不能透明改善域名 API，或需要为实时 ASR 等低延迟服务保持原 Tailscale 域名和端口的场景。
---

# 修复 Tailscale DERP 慢链路

## 目标

先用证据确认慢点位于 Tailscale 路径、应用还是代理层，再优先恢复直连；直连不可行时，部署一个双方都能低延迟访问且 UDP 端口真正公网可达的 Peer Relay。保持原 Tailscale IP、MagicDNS 域名、SSH 配置和应用端口不变。

## 安全边界

- 默认只执行只读诊断。
- 修改 `tailscale set`、tailnet policy、主机防火墙或云防火墙前，说明影响范围、回滚方式并取得明确确认。
- 不把认证密钥、个人域名、真实公网 IP 或 tailnet policy 全文写入公开记录。
- 不用宽泛的 `src: ["*"]` 代替最小授权。
- 不因版本升级、VNI 分配或单次 ping 成功就宣布问题已解决。

## 工作流

### 1. 建立路径基线

确认客户端、目标节点、候选 Relay 的准确主机名和 Tailscale IP。优先运行只读脚本：

```bash
bash scripts/diagnose_tailscale_path.sh <target> [ssh-alias]
```

同时在目标端和候选 Relay 端执行反向 `tailscale ping` 与 `tailscale netcheck`，记录：

- `tailscale status` 是 `direct`、`relay <region>` 还是 `peer-relay`；
- 双向 RTT，不能只测一个方向；
- UDP、IPv4/IPv6、端口映射、`MappingVariesByDestIP`；
- `ssh -G` 的最终配置，排除遗留 `ProxyJump`；
- HTTP 首字节、完整响应大小与总耗时；
- WebSocket 是否完成真实应用握手。

### 2. 定位根因

按以下顺序判断：

1. 目标服务在目标机本地是否快速，端口是否正确监听；
2. 同局域网访问是否快速；
3. Tailscale 是否走高延迟 DERP；
4. UDP 41641 是否监听，主机防火墙是否放行；
5. 路由器映射地址是否与 STUN 公网地址不同，以识别双层 NAT/CGNAT；
6. IPv6 直连、UPnP 或普通 Tailscale 直连是否只在部分节点成立；
7. shell 的 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 是否污染 HTTP/WebSocket 测试。

普通 Tailscale UDP 直连不代表独立的 Peer Relay 端口也能接受公网入站。缺少 `xt_connmark` 之类的路由警告也不应自动被判定为普通节点间 UDP 的根因。

### 3. 选择最小修复

- 若公网 UDP、IPv6、UPnP 或 NAT 配置可安全修复，优先恢复直接连接。
- 仅需 SSH 临时恢复时可使用 ProxyJump，但要明确它不改善 HTTP、WebSocket 或其他端口。
- 目标在 CGNAT 后、DERP 延迟高且需要透明承载全部 Tailscale 流量时，选择 Peer Relay。
- 候选 Relay 必须同时满足：双方低 RTT、支持所需 Tailscale 版本、具有可声明的稳定公网 UDP 端点、主机与云平台两层防火墙均可放行。

### 4. 部署 Peer Relay

执行任何写操作前，完整读取 [Peer Relay 操作手册](references/peer-relay-runbook.md)。按手册依次完成：

1. 在候选节点声明 Relay 监听端口和静态公网端点；
2. 放行主机防火墙 UDP 端口；
3. 放行云厂商安全组或轻量服务器防火墙；
4. 在 tailnet policy 中添加只允许目标节点使用该 Relay 的最小 grant；
5. 用抓包和任意来源 UDP 入站验证数据面，而不是只看控制面分配。

### 5. 分层验证

变更后必须逐层验证并保留前后对比：

1. `tailscale status` 显示目标链路为 `peer-relay`；
2. `tailscale ping` RTT 稳定且符合双方到 Relay 的预期；
3. Relay 抓包能看到客户端和目标节点的数据包；
4. SSH 建连耗时下降；
5. HTTP 分别记录首字节和完整响应吞吐；
6. 实时应用使用真实协议测试，例如 WebSocket 收到应用的 ready 消息；
7. 对实时音频按编码码率计算余量，不以大文件下载速度替代实时流验证。

延迟下降不等于吞吐提升。若首字节明显改善但大响应仍慢，继续检查 Relay 上下行、云出口、MTU、丢包和代理，不要把瓶颈归给目标 API。

### 6. 回滚与报告

若数据面不可达或性能退化，按操作手册反序回滚 Relay、policy grant、主机防火墙和云防火墙规则。最终报告应包含：

- 根因证据与排除项；
- 修改的节点、端口和 policy 范围；
- direct/DERP/Peer Relay 路径前后变化；
- SSH、HTTP 首字节、完整吞吐、WebSocket 的独立结果；
- 未解决的吞吐或稳定性风险。
