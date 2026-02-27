# 我的技能仓库

这个仓库存储我的个人技能（skills）集合，每个文件夹包含一个独立的技能。

## 技能列表

### 1. windows-network-share-fix
**功能：** 修复Windows 11网络共享访问问题
**用途：** 当用户无法访问网络共享并收到"组织的安全策略阻止未经身份验证的来宾访问"错误时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `enable_guest_access.reg` - 注册表修复文件
- `fix_network_share.ps1` - PowerShell修复脚本

### 2. gh-repo-maintenance
**功能：** 使用 `gh` CLI 维护 GitHub 仓库（登录检查、仓库盘点、批量筛选、隐藏/删除）
**用途：** 当需要整理 GitHub 仓库、筛选可删除仓库、批量删除老 fork，或把符合条件的仓库改为私有（隐藏）时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `scripts/repo_cutoff_visibility.py` - 按日期列出/隐藏仓库（改私有）
- `scripts/repo_bulk_delete_forks.py` - 批量删除老 fork（默认 dry-run，需 `--apply`）
- `references/gh-github-repo-maintenance-notes.md` - 常见错误与处理说明

### 3. publish-skill-to-my-skills-repo
**功能：** 将本地 Codex skill 按 `my-skills-repo` 格式发布到 GitHub 技能仓库
**用途：** 当需要把新建技能同步到 `my-skills-repo`、保持目录结构一致、生成 README 条目模板并完成提交推送时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `scripts/import_skill_to_my_skills_repo.py` - 复制本地技能到仓库并生成 README 条目模板
- `references/my-skills-repo-format.md` - `my-skills-repo` 的目录与 README 格式说明


### 4. ai-team-skills
**功能：** 打包的 AI 团队协作技能集合（含多个 skill 与 agent 提示文件）
**用途：** 当需要一套可直接落地的团队协作技能结构（`ai-team`、`codex-agent`、`gemini-agent` 以及 `agents/`）时使用
**文件：**
- `2026-02-22-skill.txt` - 技能说明草稿/整理记录
- `INSTALLATION_GUIDE.md` - 中文安装说明
- `INSTALLATION_GUIDE_EN.md` - English installation guide
- `README.md` - 项目说明（中文）
- `README_EN.md` - Project README (English)
- `agents/` - agent worker 提示文件（Codex / Gemini）
- `ai-team/` - 团队协作 skill（含 `SKILL.md` 与 `references/`）
- `codex-agent/` - Codex agent skill（含脚本与参考模板）
- `gemini-agent/` - Gemini agent skill（含脚本与参考模板）

### 5. cli-config-bootstrap
**功能：** 为 Claude CLI / Qwen CLI / Kilo CLI / OpenCode 生成和维护可迁移的本地配置模板（脱敏版）
**用途：** 当需要在新电脑快速恢复 AI CLI 开发环境、统一多台机器配置、备份脱敏配置模板或批量更新 provider endpoint（含阿里云 Coding Plan 的 Kilo/OpenCode 文档版配置）时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `assets/templates/claude/config.json` - Claude CLI 脱敏配置模板
- `assets/templates/claude/settings.json` - Claude CLI 设置模板
- `assets/templates/kilo/config.json` - Kilo CLI 配置模板（阿里云 Coding Plan 完整模型配置）
- `assets/templates/kilo/opencode.json` - Kilo OpenCode 配置模板
- `assets/templates/kilo/package.json` - Kilo package 配置模板
- `assets/templates/opencode/opencode.json` - OpenCode 配置模板（阿里云 Coding Plan 完整模型配置）
- `assets/templates/qwen/settings.json` - Qwen CLI 设置模板
- `scripts/export_cli_configs.sh` - 从当前机器导出脱敏模板
- `scripts/install_cli_configs.sh` - 安装模板并按环境变量替换占位符

### 6. claude-aliyun-config-fixer
**功能：** 配置与排障 Claude Code 对接阿里云百炼 / Coding Plan（含 `403 invalid api-key` 快速定位）
**用途：** 当按阿里云文档配置 Claude Code 失败、出现 `403 invalid api-key`、或不确定 `sk-` / `sk-sp-` Key 与 Base URL 如何匹配时使用
**文件：**
- `SKILL.md` - 技能说明文档（含 Key 前缀与 Base URL 对应关系、冲突项清理、最小验证与排障流程）

### 7. ai-cli-suite-installer
**功能：** 批量安装/升级 `claude`、`kilo`、`codex`、`opencode`、`qwen`、`gemini` 六大 CLI，并处理 npm 全局权限问题
**用途：** 当需要一键安装或统一升级这六个 AI CLI、修复 `npm -g` 的 `EACCES/EPERM`、切换到 `~/.npm-global`（无需 sudo）、或避免 `kilo/opencode/claude` 升级卡住时使用
**文件：**
- `SKILL.md` - 技能说明文档（安装/升级流程、npm 权限处理、常见卡住场景说明）
- `scripts/install_ai_clis.sh` - 六大 CLI 安装升级脚本（含 npm 用户级前缀自动配置、超时保护、非交互优化）

### 9. meeting-recorder-cli
**功能：** 通过 CLI 操控本机会议录音服务，驱动 ASR HTTP 转录并生成会议纪要
**用途：** 当需要启动/停止录音、查看转录结果、生成会议摘要、或排查录音→转录→摘要链路问题时使用
**文件：**
- `SKILL.md` - 技能说明文档（含前置条件、标准工作流与诊断流程）
- `scripts/onekey.sh` - 一键启停录音与生成摘要的主控脚本
- `scripts/meeting.sh` - 会议 CLI 命令封装（start/stop/status/transcript/summary）
- `scripts/check.sh` - ASR 服务与录音进程健康检查脚本
- `scripts/server.sh` - 录音服务器管理脚本
- `references/runbook.md` - 命令参考与输出说明
- `agents/openai.yaml` - skill 的 UI 元数据

### 8. ollama-download-monitor
**功能：** 安装 Ollama 并监控 `ollama pull` 模型下载进度与完成状态
**用途：** 当需要先按官方流程安装 Ollama（Linux/macOS/Windows），再通过日志实时查看多个模型下载进度并确认是否下载成功时使用
**文件：**
- `SKILL.md` - 技能说明文档（安装、下载、监控、校验完整流程）
- `scripts/monitor_ollama_logs.sh` - 多模型下载日志监控脚本（兼容 `*.log` 与 `ollama_*.log` 命名）
- `references/install-ollama.md` - Ollama 官方安装路径汇总与命令参考（含来源链接）
- `agents/openai.yaml` - skill 的 UI 元数据

## 使用方法

1. 克隆此仓库到本地
2. 找到需要的技能文件夹
3. 按照每个技能的说明文档使用相应的修复工具

## 添加新技能

1. 在仓库根目录创建新的文件夹，命名为技能名称
2. 在新文件夹中创建必要的文件，包括：
   - `SKILL.md` - 技能说明文档（必需）
   - 相关的脚本、工具或配置文件
3. 更新本README.md文件，添加新技能的说明

## 贡献

欢迎提交新的技能或改进现有技能！
