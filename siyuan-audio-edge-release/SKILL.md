---
name: siyuan-audio-edge-release
description: 为 SIYUAN NOTE Audio 提供 Nano1/Nano2/Nano3 的项目发布配置；与通用服务端发布流程配合处理 Audio API、绑定、便笺同步和边缘节点部署。
metadata:
  short-description: 发布和维护 SIYUAN Audio 边缘节点
---

# SIYUAN Audio Edge Release

这是 `$server-release-deployment` 的 SIYUAN NOTE Audio 项目配置。先应用通用技能的发布、验收和回滚原则，再使用以下仓库和节点约束。

处理 SIYUAN NOTE Audio 后端时，先确认任务属于服务端而不是客户端。服务端权威代码与发布控制目录是：

```text
/home/ivan/github/PyWxDump
```

GitHub 仓库 `redyuan43/PyWxDump` 的 `master` 是唯一权威版本。不要在 `X_Note` 客户端仓库实现后端改动，也不要直接修改 `/opt/siyuan-audio/current`，除非正在处理已确认的线上故障恢复。

## Audio 项目约束

- Nano1、Nano2、Nano3 必须运行同一个不可变代码 release，但它们是独立边缘节点。
- 节点本地的账户、设备绑定、录音、SQLite 数据和密钥必须隔离；绝不在节点之间复制 `/srv/siyuan-audio` 或 `/etc/siyuan-audio` 下的状态文件。

## Audio 发布参数

- 权威远端：GitHub `redyuan43/PyWxDump` 的 `master`。
- 发布控制目录：`/home/ivan/github/PyWxDump`。
- 最低测试：`tests.test_audio_auth` 与 `tests.test_audio_node_release_scripts`。
- 全量发布：`./deploy.sh all`。
- 单节点灰度：`./deploy.sh nano1`、`./deploy.sh nano2` 或 `./deploy.sh nano3`。
- 状态检查：`./deploy.sh status`，每台节点的 `/api/version` 必须返回相同 release 与完整 commit，且 API 和 worker 均为 `active`。
- 指定节点回滚：`./deploy.sh rollback NODE RELEASE_ID`。

涉及后端位置或发布方式时，更新 PyWxDump 的 `AGENTS.md`；只有客户端代理需要重新定位时，才更新 X_Note 的 `AGENTS.md` 指针。

需要具体命令、首次节点引导、回滚方式或最终汇报格式时，阅读 [发布操作参考](references/release-operations.md)。
