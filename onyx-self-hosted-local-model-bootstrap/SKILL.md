---
name: onyx-self-hosted-local-model-bootstrap
description: 在 Linux 机器上部署 Onyx 自托管版本，并接通本机 Ollama 与 LM Studio 本地模型。适用于 Docker Compose 安装、Docker daemon 不走代理导致拉镜像失败、ARM 机器优先使用 Web 版、以及 Onyx edge 后台无法正常创建本地模型 provider 时的落地修复。
---

# Onyx Self Hosted Local Model Bootstrap

当用户说“参考 Onyx 文档帮我装上”“Onyx 拉镜像超时”“LM Studio/Ollama 连不上 Onyx”“ARM 机器桌面版能不能用”“把本机本地模型接进 Onyx”时，使用这个 skill。

这个 skill 解决五类高频问题：

- 按官方 Quickstart 用 Docker Compose 装起 Onyx
- Docker CLI 能走代理，但 Docker daemon 拉 `registry-1.docker.io` 超时
- ARM Linux 机器上不纠结 Desktop App，先用 Web 版
- `LM Studio` / `Ollama` 明明本机可用，但 Onyx 容器里填 `localhost` 连不上
- `edge` 版本后台无法新建或探测本地 provider 时，用数据库兜底把 provider 和默认模型补进去

## 标准工作流

1. 先按官方 Quickstart 落地 Onyx。

浏览文档并优先走官方安装脚本：

```bash
curl -fsSL https://onyx.app/install_onyx.sh | bash
```

经验规则：

- 首次安装优先选 `Lite`
- tag 可先用文档推荐的 `edge`，但要提醒用户它可能带来后台小 bug
- 安装目录通常是当前目录下的 `onyx_data/`
- 成功后入口通常是 `http://127.0.0.1:3000`

2. 如果安装脚本在拉镜像阶段超时，先判断是不是 Docker daemon 没继承代理。

如果 shell 里有：

- `HTTP_PROXY=...`
- `HTTPS_PROXY=...`

但 `systemctl show docker --property=Environment` 里没有代理环境，说明 Docker daemon 没走代理。

先向用户确认，再运行：

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/configure_docker_proxy_from_env.sh --yes
```

这个脚本会：

- 读取当前 shell 的 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`
- 写入 `/etc/systemd/system/docker.service.d/http-proxy.conf`
- `daemon-reload` 并重启 Docker

3. 启动 Onyx 后，优先确认服务已经完全起来。

```bash
docker compose -f docker-compose.yml -f docker-compose.onyx-lite.yml ps
curl -I http://127.0.0.1:3000
```

注意：

- `api_server` 初次启动会跑大量数据库迁移
- 若早期 `curl` 被 nginx reset，不一定是失败，可能只是后端仍在迁移
- 看到 `200 OK` 再算入口稳定可用

4. 接本机 `LM Studio` / `Ollama` 时，不要在 Onyx 里填 `localhost`。

如果 Onyx 跑在 Docker 容器里，而模型服务跑在宿主机桌面上，容器视角里的 `localhost` 不是宿主机。

优先用：

- `LM Studio`: `http://host.docker.internal:1234`
- `Ollama`: `http://host.docker.internal:11434`

先做只读检查：

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/check_onyx_local_endpoints.sh
```

如果本机 `curl http://127.0.0.1:1234/v1/models` 和 `curl http://127.0.0.1:11434/api/tags` 都通，而 Onyx 里报 `Connection refused`，优先怀疑填成了 `localhost`。

5. 如果 Onyx `edge` 后台创建 provider 失败，用数据库兜底补 provider。

有些 `edge` 版本会出现这些问题：

- `LM Studio available-models` 因返回字段变化报校验错误
- `/api/admin/llm/provider` 在“新建 provider”场景返回 `not found`

此时先向用户说明会直接写入 Onyx 数据库，再执行：

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/seed_local_model_providers.sh
```

这个脚本会：

- 写入 `Ollama` provider
- 写入 `LM Studio` provider
- 补一组可直接使用的模型配置
- 设默认文本模型为 `Ollama / qwen3.5:4b`
- 设默认视觉模型为 `Ollama / qwen3-vl:latest`

## ARM 机器经验

- Linux ARM 机器上，优先把 Onyx 当作 Web 服务来部署和使用
- 如果官方桌面客户端下载页只提供 `amd64` 包，不要硬装；先直接用浏览器访问本机 `3000` 端口
- 只要 Docker 镜像能正常拉下并启动，就不要先把“桌面客户端没有 ARM 包”和“服务端不能跑”混为一谈

## 默认地址

- Onyx Web: `http://127.0.0.1:3000`
- LM Studio native metadata: `http://127.0.0.1:1234/api/v1/models`
- LM Studio OpenAI compatibility: `http://127.0.0.1:1234/v1/models`
- Ollama tags: `http://127.0.0.1:11434/api/tags`

容器里访问宿主机时，对应改为：

- `http://host.docker.internal:1234`
- `http://host.docker.internal:11434`

## 经验规则

- `curl` 能通 Docker Hub，不代表 Docker daemon 也能通；先区分“终端代理”和“daemon 代理”
- 若 `docker pull` 在 10 到 20 秒左右超时，而 shell 里已有代理变量，优先怀疑 daemon 未继承代理
- `LM Studio` / `Ollama` 接入失败时，先查本机端口监听和本机 API 是否可访问，再查 Onyx 里是不是填成了 `localhost`
- 对 Onyx `edge`，优先把系统“先跑起来”；后台细节 bug 再定点绕过，不要一开始就推翻整个部署
- 如果只需先给用户能用的系统，优先 `Lite` + Web + 本地模型，先别扩成 `Standard`

## 验证

最小验证顺序：

```bash
curl -I http://127.0.0.1:3000
```

```bash
curl -s http://127.0.0.1:3000/api/llm/provider
```

```bash
curl -s http://127.0.0.1:1234/v1/models
curl -s http://127.0.0.1:11434/api/tags
```

若需要验证后台是否真正收到了 provider：

```bash
curl -s -b /tmp/onyx-admin.cookies http://127.0.0.1:3000/api/admin/llm/provider
```

## 安全规则

- 修改 Docker daemon 代理前先确认，因为这会重启 Docker 并短暂影响现有容器
- 不要默认改系统 DNS
- 不要默认覆盖用户现有 Onyx 用户账号；若登录凭据不可用，优先临时创建一个新管理员账号而不是重置旧密码
- 直接写 Onyx 数据库只作为 `edge` 版后台异常时的兜底手段，用完要明确告诉用户改了什么

---

# English Version

Use this skill when the user wants to install self-hosted Onyx on Linux, connect local `Ollama` and `LM Studio`, fix Docker image pull failures caused by daemon proxy issues, or recover from `edge`-version admin bugs around local model providers.

This skill covers five recurring scenarios:

- Install Onyx with the official Docker Compose quickstart
- Fix cases where the shell can reach Docker Hub but the Docker daemon cannot
- Prefer the Web UI on ARM Linux instead of assuming the Desktop App will work
- Fix `LM Studio` or `Ollama` connectivity when Onyx runs in Docker and the user configured `localhost`
- Seed local model providers directly when an `edge` build cannot create them cleanly from the admin UI

## Standard Workflow

1. Install Onyx with the official quickstart.

Use the upstream installer first:

```bash
curl -fsSL https://onyx.app/install_onyx.sh | bash
```

Recommended defaults:

- Choose `Lite` for the first deployment
- `edge` is acceptable for a first pass, but warn the user that admin-side bugs are more likely
- The installer usually creates `onyx_data/` under the current directory
- The local entrypoint is usually `http://127.0.0.1:3000`

2. If image pulls time out, check whether the Docker daemon inherited proxy settings.

If the current shell has:

- `HTTP_PROXY=...`
- `HTTPS_PROXY=...`

but `systemctl show docker --property=Environment` does not, the daemon is likely bypassing the proxy.

After the user confirms, run:

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/configure_docker_proxy_from_env.sh --yes
```

This script:

- reads `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` from the current shell
- writes `/etc/systemd/system/docker.service.d/http-proxy.conf`
- reloads systemd and restarts Docker

3. Confirm that Onyx is fully up before treating the deployment as successful.

```bash
docker compose -f docker-compose.yml -f docker-compose.onyx-lite.yml ps
curl -I http://127.0.0.1:3000
```

Notes:

- the first `api_server` startup may spend a while running migrations
- an early nginx connection reset does not automatically mean the deployment failed
- wait for `200 OK` before calling the entrypoint healthy

4. When wiring local `LM Studio` or `Ollama` into Onyx, do not use `localhost`.

If Onyx runs in Docker and the model server runs on the Linux host, container-side `localhost` points to the container itself, not the host.

Use:

- `LM Studio`: `http://host.docker.internal:1234`
- `Ollama`: `http://host.docker.internal:11434`

Run the read-only checks:

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/check_onyx_local_endpoints.sh
```

If host-side APIs work but Onyx reports `Connection refused`, first suspect an incorrect `localhost` base URL inside Onyx.

5. If an `edge` build cannot create local providers from the admin UI, seed them as a fallback.

Typical symptoms:

- `LM Studio available-models` fails because the returned schema changed
- `/api/admin/llm/provider` behaves like an update-only endpoint and cannot create a new provider

Explain the fallback clearly to the user, then run:

```bash
bash onyx-self-hosted-local-model-bootstrap/scripts/seed_local_model_providers.sh
```

This seeds:

- one `Ollama` provider
- one `LM Studio` provider
- a practical starter set of local model entries
- default text model: `Ollama / qwen3.5:4b`
- default vision model: `Ollama / qwen3-vl:latest`

## ARM Notes

- On ARM Linux, prioritize self-hosted Onyx through the browser
- If the official Desktop App only ships `amd64` Linux artifacts, do not block on that
- Do not confuse "the Desktop App may not support ARM" with "the self-hosted service cannot run on ARM"

## Default Endpoints

- Onyx Web: `http://127.0.0.1:3000`
- LM Studio native metadata: `http://127.0.0.1:1234/api/v1/models`
- LM Studio OpenAI compatibility: `http://127.0.0.1:1234/v1/models`
- Ollama tags: `http://127.0.0.1:11434/api/tags`

From inside containers, use:

- `http://host.docker.internal:1234`
- `http://host.docker.internal:11434`

## Heuristics

- If `curl` can reach Docker Hub but `docker pull` times out, distinguish shell proxy from daemon proxy
- If `docker pull` times out quickly and the shell already exports proxy variables, suspect that Docker daemon did not inherit them
- If `LM Studio` or `Ollama` integration fails, verify host-side ports and APIs first, then verify the Onyx base URL
- On `edge`, optimize for "usable now" first, then patch specific admin bugs
- If the goal is simply to get the user operational, start with `Lite + Web + local models`

## Verification

Minimal checks:

```bash
curl -I http://127.0.0.1:3000
```

```bash
curl -s http://127.0.0.1:3000/api/llm/provider
```

```bash
curl -s http://127.0.0.1:1234/v1/models
curl -s http://127.0.0.1:11434/api/tags
```

To verify the admin-side provider list:

```bash
curl -s -b /tmp/onyx-admin.cookies http://127.0.0.1:3000/api/admin/llm/provider
```

## Safety Rules

- Confirm with the user before changing Docker daemon proxy settings, because Docker will restart
- Do not change system DNS by default
- Do not overwrite an existing user account by default; create a temporary admin account if login credentials are unavailable
- Treat direct Onyx database writes as an `edge` fallback, and tell the user exactly what was changed
