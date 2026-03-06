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
- `ai-cli-suite-installer/scripts/install_ai_clis.sh` - 六大 CLI 安装升级脚本（含 npm 用户级前缀自动配置、超时保护、非交互优化；该路径为唯一入口）

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
- `scripts/download_and_monitor_ollama.sh` - 一键启动缺失模型下载并自动进入监控
- `scripts/monitor_ollama_logs.sh` - 多模型下载日志监控脚本（兼容 `*.log` 与 `ollama_*.log` 命名）
- `references/install-ollama.md` - Ollama 官方安装路径汇总与命令参考（含来源链接）
- `agents/openai.yaml` - skill 的 UI 元数据

### 10. sudo-nopasswd-toggle
**功能：** 为本地 Linux 用户开启 `sudo` 免密、查看当前状态，或恢复为需要密码验证
**用途：** 当用户要求配置 `sudo NOPASSWD`、`sudo 免密`、`sudo 不用输密码`，或要求撤销该配置并恢复密码校验时使用
**文件：**
- `SKILL.md` - 技能说明文档（启用、关闭、状态检查与安全注意事项）
- `scripts/manage_sudo_nopasswd.sh` - 托管 `/etc/sudoers.d/90-<user>-nopasswd` 的操作脚本，支持 `enable`、`disable`、`status`

### 11. download-youtube-video
**功能：** 使用 `yt-dlp` 下载 YouTube 视频、音频、字幕、缩略图和元数据
**用途：** 当用户提供 YouTube 链接，希望保存本地视频或音频、抓取字幕/自动字幕、保留描述与 `.info.json` 元数据，或网页抓取失败后需要切换到实际媒体下载流程时使用
**文件：**
- `SKILL.md` - 技能说明文档（下载模式、失败处理和工作流说明）
- `scripts/download_youtube.py` - 基于 `yt-dlp` 的下载包装脚本，支持 video/audio/subtitles/metadata 模式
- `references/yt_dlp_presets.md` - 常用下载参数和操作规则参考

### 12. analyze-video-file
**功能：** 使用 `ffprobe` 和 `ffmpeg` 分析本地视频文件，导出结构化报告、抽帧、音频和字幕相关产物
**用途：** 当用户想知道一个视频文件讲了什么、需要抽取关键帧和转录前置材料、或只想检查编码、时长、分辨率与流信息时使用
**文件：**
- `SKILL.md` - 技能说明文档（分析模式、解释规则和失败处理）
- `scripts/analyze_video.py` - 本地视频分析脚本，生成 `ffprobe.json`、`summary.json`、`report.md` 等产物
- `references/report_fields.md` - 输出文件字段及阅读顺序说明

### 13. tts
**功能：** 文字转语音（Text-to-Speech），将文字合成为语音并播放
**用途：** 当需要将文字转换为语音（使用本地 Qwen3-TTS 模型）、自动检测模型加载状态并触发加载后播放时使用。用法：`/tts 你好世界`
**文件：**
- `SKILL.md` - 技能说明文档（参数解析、模型加载检测、合成与播放流程）

### 14. asr
**功能：** 语音识别（Speech-to-Text），将音频文件转录为文字
**用途：** 当需要将本地音频文件（WAV 等）通过本地 Qwen3-ASR 模型转录为文字时使用。用法：`/asr /path/to/audio.wav`
**文件：**
- `SKILL.md` - 技能说明文档（转录流程、响应字段说明与错误处理）

### 15. translate
**功能：** 语义翻译（Semantic Translation），使用本地 AI 模型进行中英文互译
**用途：** 当需要通过本地 Ollama 大语言模型翻译文字、支持中英互译时使用。用法：`/translate Hello World [to:zh|to:en]`
**文件：**
- `SKILL.md` - 技能说明文档（参数解析、API 调用、响应展示与 fallback 处理）

### 16. download-bilibili-video
**功能：** 使用 `yt-dlp` 下载 Bilibili 视频、音频、字幕、弹幕和元数据，并处理 `b23.tv` 短链与浏览器 cookie
**用途：** 当用户提供 `bilibili.com` 或 `b23.tv` 链接，希望保存本地视频或音频、抓取字幕/自动字幕/弹幕、保留描述与 `.info.json` 元数据，或在遇到 `412 Precondition Failed` 时需要借助 Chromium cookie 完成下载时使用
**文件：**
- `SKILL.md` - 技能说明文档（B 站下载工作流、短链解析、cookie 使用和失败处理）
- `scripts/download_bilibili.py` - Bilibili 下载包装脚本，支持 `video`/`audio`/`subtitles`/`metadata` 模式，并自动探测 Chromium/Snap Chromium 配置

### 17. qwen3-omni-multimodal-client
**功能：** 调用本地 `Qwen3-Omni` 服务，统一覆盖文本、音频、图片、视频输入，以及文本/音频输出
**用途：** 当本地 `Qwen3-Omni` wrapper 服务已经启动，用户需要快速执行 `ping`、文本问答、文本转语音、图片理解、音频理解或视频理解命令时使用
**文件：**
- `SKILL.md` - 技能说明文档（何时使用、工作流、已知限制）
- `references/examples.md` - 多模态命令速查示例
- `scripts/run_qwen3_omni_infer.sh` - 本地 CLI 调用包装脚本

### 18. qwen3-omni-bundle-manager
**功能：** 安全隔离不可用模型缓存、生成只包含可用 `gptq4` 路径的部署压缩包，并校验压缩包内容
**用途：** 当需要清理 `Qwen3-Omni` 项目里的失败模型分支、保留可用 `gptq4` 模型、导出可迁移 bundle，或验证归档是否排除了失败模型时使用
**文件：**
- `SKILL.md` - 技能说明文档（清理、打包、校验工作流）
- `references/bundle-layout.md` - bundle 内部布局说明
- `scripts/prune_and_bundle.sh` - 串联清理与打包的入口脚本

### 19. deskflow-linux-setup
**功能：** 在 Linux 上安装、运行并排障 Deskflow，覆盖 Flatpak、原生包、AppImage 和源码编译
**用途：** 当需要安装 Deskflow 键鼠共享工具、验证下载的安装包是否可用、修复 `.deb` 依赖冲突，或按官方方法从源码构建 Deskflow 时使用
**文件：**
- `SKILL.md` - 技能说明文档（安装路径选择、Flatpak 工作流、损坏包修复、验证步骤）
- `references/install-methods.md` - 程序摘要、安装方式对比、Linux 依赖列表、源码编译命令和 Ubuntu GNOME 快捷键配置
- `assets/deskflow-1.26.0-linux-x86_64.flatpak` - 已验证可安装的 Deskflow Flatpak 原始安装包

### 20. openclaw-setup
**功能：** 安装 OpenClaw 并配置 API 模型 provider
**用途：** 当需要全新安装 OpenClaw、配置 GLM/Ollama/OpenAI/OpenRouter 等模型 provider、启动 Gateway 或排查常见问题时使用
**文件：**
- `SKILL.md` - 技能说明文档（含安装、onboarding、provider 配置、Gateway 启动、常见排障全流程）

### 21. cpu-process-watchflow
**功能：** 先发现当前高 CPU 进程，再持续监控指定进程并在退出或持续低负载时告警
**用途：** 当需要先筛出正在高负载运行的程序，再对选定 PID 或进程名做持续监控，及时发现进程停止或进入异常空转状态时使用
**文件：**
- `SKILL.md` - 技能说明文档（两阶段工作流、默认阈值与监控规则）
- `scripts/find_high_cpu_processes.py` - 列出当前高 CPU 进程，输出 PID、CPU%、进程名和命令行
- `scripts/watch_processes.py` - 按 PID 或进程名持续监控，并在退出或连续低于 CPU 阈值时告警
- `agents/openai.yaml` - skill 的 UI 元数据


### 22. diarization
**功能：** 说话人分离（Speaker Diarization），对本地音频或视频文件生成 speaker turns、RTTM 和 speaker transcript
**用途：** 当需要对本地音频或视频做说话人分离，并输出 `diarization.json`、`diarization.rttm`、`speaker_transcript.md` 和 `run_manifest.json` 时使用
**文件：**
- `SKILL.md` - 技能说明文档（输入检查、音频预处理、ASR 健康检查与 diarization 执行流程）


### 23. meeting-room
**功能：** 在 Ubuntu 上执行会议室会议纪要脚本，统一支持 start、stop、status，并在 stop 后自动等待 diarization 和生成 summary
**用途：** 当需要在会议室里用一套固定脚本来启动会议纪要、停止会议纪要、查看状态和抓取日志，或调用已安装的会议快捷启动器时使用
**文件：**
- `SKILL.md` - 技能说明文档（统一入口、产物目录、Ubuntu 启动器和会议脚本调用方式）

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
