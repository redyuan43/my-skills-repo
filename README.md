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

### 8. meeting-recorder-cli
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

### 9. ollama-download-monitor
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

### 24. emeet-record-av-toggle
**功能：** 用“开始 / 停止 / 状态”三条命令控制 EMEET PIXY 的后台人脸跟踪录制，并自动生成带声音的 MP4
**用途：** 当需要“输入开始就录、输入停止就停”、持续录到人工叫停为止，或想查看当前是否仍在录制时使用
**文件：**
- `SKILL.md` - 技能说明文档（开始/停止/状态工作流、默认设备与注意事项）
- `agents/openai.yaml` - skill 的 UI 元数据
- `scripts/toggle_record.sh` - 后台启动/停止录制、状态查询与音视频封装脚本

### 25. ollama-gpu-pinning
**功能：** 将 Ollama 固定到指定 NVIDIA GPU，并提供 systemd 场景下的回滚脚本
**用途：** 当机器上有多张 NVIDIA 显卡，需要让 Ollama 只在指定 GPU 上加载模型、验证实际落卡结果，并在需要时恢复默认配置时使用
**文件：**
- `SKILL.md` - 技能说明文档（GPU 选择、systemd/临时测试、验证与回滚流程）
- `scripts/rollback_ollama_gpu_selection.sh` - 删除 `CUDA_VISIBLE_DEVICES` 的 systemd drop-in 并重启服务
- `scripts/set_ollama_gpu.sh` - 为 `ollama.service` 写入 GPU 绑定配置并重启服务

### 26. wechat-send-file
**功能：** 使用本地 `PyWxDump` 发送链路把文件发到指定微信会话，并支持 `standalone/main/auto` 窗口模式、GUI 倒计时参数和 `restore_action` 输出
**用途：** 当需要把本地文件发到某个微信联系人或群聊、希望从 `~/Documents` 自动挑选文件、需要直接走主界面搜索发送，或想在发送结束后看到窗口恢复结果时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、工作流、窗口模式、`restore_action` 说明和命令示例）
- `scripts/send_wechat_file.sh` - 发送脚本，支持显式路径、自动选文件、`--window-mode`、GUI 提示参数和包装层结果摘要

### 27. linux-ntfs-offload-symlink
**功能：** 把 Linux 主目录中的大型数据目录迁移到 NTFS 分区，并在原路径保留软链接，同时确保 `fstab` 自动挂载可靠生效
**用途：** 当 `/home` 空间紧张、机器上还有另一块 NTFS 数据盘、希望把模型/缓存/归档迁走且不改变原有访问路径时使用；已覆盖 AMD 395 工作站、Ubuntu、ZFS `/home` + NTFS 数据盘的实测经验
**文件：**
- `SKILL.md` - 技能说明文档（选择迁移对象、复制/切换软链接、`fstab` 配置与重挂验证）
- `references/amd395-ntfs-offload-runbook.md` - AMD 395 + Ubuntu + ZFS/NTFS 组合下的实测运行记录与命令

### 28. wechat-send-camera-roll
**功能：** 把相机卡或 `DCIM` 目录下的照片按文件名顺序批量发送到已经单独打开的微信聊天窗口
**用途：** 当需要把挂载相机卡里的照片一张张发给某个微信联系人、要求纯控件发送而不依赖视觉识别、或需要通过 `--limit` / `--start-after` 做试发和断点续传时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、工作流、约束和命令示例）
- `scripts/send_wechat_camera_roll.py` - 批量发送脚本，支持目录遍历、发送间隔、试发和断点续传

### 29. wechat-screenshot-send
**功能：** 在 Ubuntu X11 上截取当前桌面或交互式截图，并通过本地 `PyWxDump` 图片发送链路立即发到指定微信会话
**用途：** 当需要“一次性完成”桌面截图并发给某个微信联系人或群聊、希望直接走主界面搜索发送、想调节 GUI 倒计时/通知参数，或在截图发送后看到窗口恢复结果时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、一键工作流、窗口模式、诊断场景和命令示例）
- `scripts/screenshot_send_wechat.sh` - 一键截图并发送脚本，支持 `--window-mode`、GUI 提示参数、`--delay` 和 `--print-only`
- `scripts/diagnose_control_wechat.sh` - 控件级诊断截图、发送和 Markdown 分析回发脚本
- `scripts/selftest.sh` - 真实/无副作用自检脚本，用于验证截图与发送命令链路

### 30. tailscale-login-helper
**功能：** 检查 Linux 机器在重启后是否仍保持 Tailscale 登录，并在需要时触发重新登录流程
**用途：** 当需要确认“重启后还要不要重新登录 Tailscale”、排查 `tailscaled` 服务状态、恢复 Tailnet 登录，或快速判断为何看不到另一台 Tailscale 主机时使用
**文件：**
- `SKILL.md` - 技能说明文档（判断规则、标准工作流和使用经验）
- `scripts/tailscale_login_helper.sh` - 状态检查与登录恢复脚本，支持 `status` 和 `login`

### 31. linux-wx-decrypt
**功能：** 通过 PyWxDump 导出和解密 Linux 微信本地数据库，串联 key 提取与数据库批量解密流程
**用途：** 当需要把当前机器上运行中的 Linux 微信 `db_storage` 转成可读数据库，用于本地分析、归档或后续聊天处理时使用
**文件：**
- `SKILL.md` - 技能说明文档（流程、约束和触发场景）
- `scripts/run_linux_wx_decrypt.sh` - 包装 `linux_get_wx_key.py` 与 `linux_decrypt_wx_db.py` 的入口脚本，支持全流程、仅提 key、仅解密

### 32. wechat-chat-watch
**功能：** 通过 PyWxDump 监听指定微信会话或全部会话的新消息，并输出文本、JSON 或 webhook 事件
**用途：** 当需要持续监控某个聊天、把增量消息接到下游系统、或在监听阶段启用媒体/链接增强时使用
**文件：**

### 33. codex-persona-manager
**功能：** 为 Codex、Claude Code 和 OpenCode 安装、迁移和切换猫系人格模板，支持交互式列出人格并让用户自己选择
**用途：** 当需要在新电脑上恢复 AI CLI 的人格配置、避免手动改 `AGENTS.md` / `settings.json`、查看有哪些人格可选，或切换当前工具的说话风格与自称名字时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、交互式工作流、三端安装与切换方式）
- `assets/personas/` - 10 份打包的人格模板，会安装到目标机器的 Codex / Claude Code / OpenCode 对应目录
- `scripts/manage_codex_personas.sh` - 交互式安装与切换脚本，支持 `--list`、`--install-only`、`--target`、`--activate`
- `references/persona-table.md` - 人格 ID、自称名字、风格关键词与适用场景对照表

### 34. wechat-chat-summary
**功能：** 通过 PyWxDump 导出指定微信会话的历史消息并生成 Markdown 总结，支持时间范围和可选回发
**用途：** 当需要总结某个群聊或联系人最近一段时间讨论内容、导出全量聊天摘要、或把精简版总结发回原会话时使用
**文件：**
- `SKILL.md` - 技能说明文档（总结流程、时间范围和发送回写约束）
- `scripts/summarize_wechat_chat.sh` - 包装 `linux_wx_chat_daemon.py summarize-chat` 的总结入口脚本

### 35. wechat-link-to-doc
**功能：** 通过 PyWxDump 把微信里分享的 URL，尤其是公众号文章，转成包含 `document.md` 和资源目录的本地文档包
**用途：** 当需要把一条公众号链接或普通网页固化为本地 Markdown 文档，用于后续总结、归档或知识库输入时使用
**文件：**
- `SKILL.md` - 技能说明文档（链接文档化流程、文档类型选择和输出说明）
- `scripts/wechat_link_to_doc.sh` - 包装 `tools/link_doc_hook.py` 的单 URL 文档化入口脚本

### 36. wechat-auto-assistant
**功能：** 通过 PyWxDump 运行“监听消息 -> 丰富上下文 -> 调用外部 Agent webhook -> 执行结构化动作”的微信自动助理闭环
**用途：** 当需要对白名单微信会话启用真实自动化流程，并让外部 Agent 返回 `send_text`、`send_file`、`send_image`、`summarize_chat` 等动作由本机执行时使用
**文件：**
- `SKILL.md` - 技能说明文档（Assistant 动作协议、白名单约束和适用场景）
- `scripts/run_wechat_auto_assistant.sh` - 包装 `linux_wx_chat_daemon.py watch` Assistant 模式的入口脚本
- `wechat-send-file` / `wechat-screenshot-send` / `wechat-send-camera-roll` - 配套发送类 skill，继续承担独立发送场景

### 37. baidunetdisk-upload
**功能：** 通过已安装的 Linux 百度网盘桌面客户端上传本地文件，并用远端目录回读验证上传结果
**用途：** 当需要把本地文件快速上传到百度网盘、只提供精确路径或大概文件名、并希望上传后能直接给出网盘目录供人工审核时使用
**文件：**
- `SKILL.md` - 技能说明文档（工作流、约束、危险操作确认要求）
- `scripts/upload_to_baidunetdisk.py` - 上传执行脚本，负责本地路径解析、临时打包、调用百度网盘客户端上传并回读远端目录

### 38. baidunetdisk-remote-image-search
**功能：** 只针对百度网盘指定目录搜索图片内容，串联远端目录同步、本地缓存、独立 ZBox 索引和 OCR/图片摘要检索
**用途：** 当需要在百度网盘某个目录里查“图片里有什么文字或内容”、希望结果限定在百度网盘范围内，并返回远端路径、命中来源和片段供人工判断时使用
**文件：**
- `SKILL.md` - 技能说明文档（工作流、默认本地优先策略、云端视觉使用边界）
- `scripts/search_baidunetdisk_images.py` - 搜索脚本，负责调用现有 harness 执行 `remote image search` 并输出稳定结果
### 39. jetson-display-stack-repair
**功能：** 排查和修复 Jetson 上 GNOME/Weston 图形栈启动失败、黑屏或登录界面不显示
**用途：** 当 `graphical.target` 已启用但屏幕仍不亮、`gdm3` 没有拉起、`nvweston` 抢占 DRM、`display-manager.service` 缺失或 Xorg 报 `drmSetMaster failed` 时使用
**文件：**
- `SKILL.md` - 技能说明文档（启动链检查、冲突排除和验证流程）
- `agents/openai.yaml` - skill 的 UI 元数据
- `references/jetson-display-stack-repair.md` - Jetson 图形栈排障参考与命令清单

### 40. headless-vnc-chromium-fix
**功能：** 在无显示器的 Ubuntu/Linux 机器上安装 TigerVNC + XFCE，并修复 Chromium 因缺少图形会话或 Snap 权限异常而无法启动的问题
**用途：** 当用户说“没接显示器”“想装 VNC”“Chromium 打不开”“`chromium-browser` 起不来”“`snap-confine` 权限不对”时使用；这是服务端技能，不是客户端连接脚本
**文件：**
- `SKILL.md` - 技能说明文档（服务端 headless 检测、VNC 安装、XFCE 启动、Chromium/Snap 排障流程）
- `scripts/repair_snap_confine.sh` - 将 `/usr/lib/snapd/snap-confine` 修回 `root:root 4755` 并重启 `snapd`

### 41. vnc-client-connect
**功能：** 在 Linux 客户端上一键连接远端 VNC 服务，支持 `host`、`host:display` 和 `host:port` 三种输入
**用途：** 当需要“给客户端一个连接脚本”“从另一台 Linux 电脑连接 VNC”“不想手工敲 viewer 参数”时使用；这是客户端技能，不修改服务端配置
**文件：**
- `SKILL.md` - 技能说明文档（客户端定位、viewer 选择顺序、目标格式和使用示例）
- `scripts/connect_vnc.sh` - Linux 客户端连接脚本，自动选择可用 viewer 并发起 VNC 连接

### 42. wechat-linux-official-setup
**功能：** 按 Tencent 官方 Linux 版下载页安装 ARM 架构微信，并完成启动、GNOME 固定和手动扫码登录的标准流程
**用途：** 当需要在 ARM Linux 上安装官方微信客户端、验证 `wechat` 可启动、把启动器固定到 GNOME Dock，或想把“下载 -> 安装 -> 启动 -> 登录”整理成可复用流程时使用
**文件：**
- `SKILL.md` - 技能说明文档（官方来源、安装启动工作流、登录约束和使用场景）
- `scripts/install_wechat_official.sh` - 官方 ARM 包下载、安装、启动和 GNOME 固定脚本

### 43. chromium-flatpak-fallback
**功能：** 当 Ubuntu 上的 `chromium-browser` 实际走 Snap 包装器且反复失败时，改用 Flatpak 安装并启动真正可用的 Chromium
**用途：** 当用户明确需要 Chromium、`snap run chromium` 因 `snap-confine`/namespace/容器环境报错或卡住、而机器本身已有图形桌面时使用
**文件：**
- `SKILL.md` - 技能说明文档（判定条件、Flatpak 回退流程与验证标准）
- `scripts/chromium_flatpak_fallback.sh` - 诊断、安装、启动与进程检查脚本

### 44. linux-wechat-send-bootstrap
**功能：** 为 PyWxDump 的 Linux 微信文本发送链路做一键引导，自动补齐 `.venv` 最小依赖、提取 key、解密数据库，并走“搜索 + 视觉验标题 + 数据库回读”的稳妥发送流程
**用途：** 当新用户第一次在 Linux 上使用 PyWxDump 发送微信消息，遇到 `.venv` 缺 `Pillow` / `pycryptodomex`、`~/.wx_db_keys.json` 为空、`ptrace_scope` 阻止提 key、`OPENAI_API_KEY` 只在 `~/.bashrc` 中，或默认 `send-text` 无法稳定命中目标会话时使用
**文件：**
- `SKILL.md` - 技能说明文档（前置条件、工作流、风险点和命令示例）
- `scripts/send_text_with_setup.sh` - 引导脚本，负责定位 PyWxDump、准备 `.venv`、提 key、解密数据库并切到交互式 bash
- `scripts/send_text_with_setup.py` - 发送执行脚本，负责主界面搜索、视觉验标题、发送文本和数据库回读确认

### 45. sync-latest-skills
**功能：** 拉取 `my-skills-repo` 最新内容，并把仓库里的顶层技能目录同步到 `~/.codex/skills`
**用途：** 当需要一键刷新本机技能目录、把仓库更新同步回本地链接，或替换旧版本技能目录时使用
**文件：**
- `SKILL.md` - 技能说明文档
- `scripts/sync_latest_skills.sh` - 拉取仓库并将顶层技能目录链接到 `~/.codex/skills`，支持 `--rebase`

### 46. gh-browser-chromium-fix
**功能：** 配置 GitHub CLI 及系统默认 Web 处理器一起打开 Chromium，而不是 Firefox 或不可用的 Snap 浏览器
**用途：** 当 `gh auth login`、`gh browse` 或 `--web` 链接走错浏览器、需要把 `gh config browser` 和 XDG 默认浏览器一起固定到 Chromium，或想避免 `gh` 继续调用 Firefox 时使用
**文件：**
- `SKILL.md` - 技能说明文档（`gh` 浏览器路由、系统默认 Web 处理器和失败处理）
- `scripts/set_gh_browser.sh` - 自动探测 Chromium 并同时写入 `gh config browser` 和 XDG 默认处理器的脚本

### 47. openclaw-wechat-linux-local-launcher
**功能：** 为 OpenClaw 的本地 `wechat-linux` 调试环境提供配置模板，并指导如何用辅助脚本启动、看日志、查状态和停止 Gateway
**用途：** 当需要在单机上把 `wechat-linux` 跑起来、先准备 `~/.openclaw/openclaw.json` 和 `~/.openclaw/.env`，再用 `scripts/run-wechat-linux-local.sh` 等脚本做本地 bring-up 时使用
**文件：**
- `SKILL.md` - 技能说明文档（前置条件、配置编辑、启动顺序和常见排障点）
- `assets/templates/openclaw.json` - 脱敏版 OpenClaw 本地 `wechat-linux` 配置模板
- `assets/templates/wechat-linux.env.example` - 脱敏版环境变量模板（API key / Base URL / DISPLAY）

### 48. dual-mi-barge-in-replay-lab
**功能：** 用两台 `MI Speakphone` 做自动化 `barge-in` 真实回放实验，让 `speaker1` 播放助手语音、`speaker2` 外放模拟插话、`mic1` 负责检测与识别，并输出可定位问题的实验工件
**用途：** 当需要定位“实时语音打断不灵敏”“AEC 把外部插话也消掉了”“流式 partial 比 batch 更差”“双设备自动化回放测试怎么搭”时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用场景、默认拓扑、推荐参数与实验工作流）
- `references/runbook.md` - 双 `MI` 自动化回放的经验总结、关键误区、判据和默认策略说明

### 49. headless-vnc-audio-xfce
**功能：** 在无显示器 Ubuntu/Linux 上部署固定会话 `TigerVNC + XFCE + PulseAudio TCP`，同时覆盖服务端安装、客户端音频接入、黑屏排障和内存优化经验
**用途：** 当机器只通过 VNC 访问 GUI、需要让客户端听到远端音视频声音、重启后遇到“端口通但黑屏”、或想继续压 `XFCE` 内存占用时使用
**文件：**
- `SKILL.md` - 技能说明文档（架构、标准工作流、常见坑和优化优先级）
- `references/runbook.md` - 已验证过的经验总结，含黑屏、音频、协议误用和内存口径说明
- `scripts/vnc_audio_server_setup.sh` - 服务端创建 `vnc_audio` sink 并暴露 `PulseAudio TCP`
- `scripts/vnc_audio_status.sh` - 服务端音频状态检查脚本
- `scripts/vnc_audio_client_attach.sh` - Linux 客户端用 `parec | pacat` 挂接远端音频
- `scripts/vnc_session_poststart.sh` - VNC 会话启动后关闭 `xfce4-screensaver/xiccd` 等干扰项
- `assets/vncserver-headless.service` - `systemd` 常驻 VNC 服务模板
- `assets/xstartup` - `TigerVNC` 会话入口模板
- `assets/xfce4-session.xml` - 精简 `XFCE` failsafe session 模板
- `assets/autostart/*.desktop` - 关闭 `xfce4-screensaver`、`xiccd`、`tracker`、`nm-applet` 等自启动项的覆盖模板

### 50. vnc-xfce-recovery-kit
**功能：** 把坏掉的 `TigerVNC + XFCE` 桌面一键恢复到完整可用状态，并提供可扩展的启动 hook 机制
**用途：** 当用户说“VNC 服务端能连但桌面体验坏了”“想重装 XFCE 并恢复标准桌面”“Chromium 打不开但我默认就要 Chromium”“希望把这套恢复流程固化成以后还能重复跑的脚本”时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用场景、最短使用方式、可扩展 hook 约定）
- `references/runbook.md` - 恢复后的目标状态、为什么保留 `-extension SELinux`、以及后续扩展建议
- `scripts/recover_vnc_xfce.sh` - 一键恢复脚本：重装 `dbus/selinux-policy-default/XFCE`、备份并重置用户配置、恢复标准 `xstartup`、刷新 `vncserver-headless.service`、固定默认终端和浏览器、重建 `:1` 桌面

### 51. linux-auto-shutdown-triage
**功能：** 排查 Linux 机器“自动关机 / 自动重启 / 像关机一样消失”的问题，并在必要时执行电源策略止血和日志持久化
**用途：** 当用户说“电脑过一会儿自己关机”“怀疑系统有自动关机逻辑”“空闲后像关机一样”“想查是手动关机、定时任务、电源键、合盖还是自动挂起”时使用
**文件：**
- `SKILL.md` - 技能说明文档（排查顺序、证据判断、止血策略与验证标准）
- `references/command-checklist.md` - 时间线、计划任务、手动关机、GNOME/XFCE 电源策略、日志与 `journald` 持久化命令清单
- `references/boot-capture.md` - 开机自动取证脚本的适用场景、安装方式与判读要点
- `scripts/boot_capture.sh` - 在新 boot 一开始自动抓取上一轮异常关机/挂起证据的落盘脚本
- `scripts/triage_auto_shutdown.sh` - 默认只读排查、按需执行止血配置的一键脚本

### 52. headless-rdp-remmina-audio
**功能：** 作为局域网/直连主线，在无显示器的 Ubuntu/Linux 主机上通过 `Remmina + RDP` 访问 `xrdp + XFCE`，启用音频重定向，并为 Linux 客户端生成可复用的 `.remmina` 配置
**用途：** 当用户说“只通过远程桌面登录主机”“客户端固定用 Remmina”“远程要听到服务器声音”“需要处理分辨率或剪贴板问题”时使用；这是默认的直连入口，不覆盖 Tailscale 和 VNC server
**文件：**
- `SKILL.md` - 技能说明文档（直连边界、最小服务端前提、客户端 Remmina 工作流、TigerVNC 切换步骤、分辨率/剪贴板排障）
- `scripts/write_remmina_profile.sh` - 在 Linux 客户端生成启用本地音频、客户端分辨率、`16bpp` 和键盘抓取的 `.remmina` 配置文件
- `scripts/push_remmina_profile_via_ssh.sh` - 通过 SSH 在另一台 Linux 客户端直接写入 `.remmina` 配置文件

### 53. xfce-lock-screen-timeout
**功能：** 检查并设置 XFCE 桌面的空闲锁屏时间，明确区分 `xfce4-screensaver` 持久化配置和当前 X11 会话 `xset` 的即时超时
**用途：** 当用户要求“把 XFCE 锁屏时间改成一小时/30 分钟”、需要查看当前锁屏超时，或发现图形界面改了但实际不生效时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、判断顺序、手工兜底命令和验证方式）
- `scripts/set_xfce_lock_screen_timeout.sh` - 查看当前状态，或把空闲锁屏时间改成指定分钟数并立即校验

### 54. wechat-auto-enter-startup
**功能：** 安装视觉识别版 Linux 微信自动进入流程，自动启动 `wechat`、识别绿色 `Enter Weixin` 按钮并点击，同时可配置为桌面登录后自动执行
**用途：** 当用户想把“启动微信并点进入微信”做成稳定脚本、明确嫌弃固定坐标点击、需要改成截图识别绿色按钮，或者希望在 XFCE/GNOME 登录后自动运行这套流程时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、安装工作流、自启动方式和限制）
- `scripts/install_wechat_auto_enter.sh` - 安装脚本，负责复制主脚本、生成 autostart wrapper 和 `~/.config/autostart` 桌面项
- `scripts/wechat_auto_enter.sh` - 运行脚本，负责启动微信、定位窗口、截图识别绿色按钮并点击中心
- `scripts/wechat_auto_enter_autostart.sh` - 自启动包装脚本模板，负责登录桌面后延迟执行主脚本
- `scripts/selftest.sh` - 语法、依赖和安装结果检查脚本

### 55. remmina-tailscale-xrdp
**功能：** 作为外网扩展路径，在 Linux 服务端与 Linux 客户端之间打通 Tailscale + xrdp + XFCE + Remmina 远程桌面，并完成客户端 Remmina 参数优化、服务端 XFCE 合成器优化、Tailscale 登录与联通验证
**用途：** 当用户说“Remmina 局域网已经能连，想从外网继续连”“继续用 xrdp + XFCE，不要换协议”“把客户端和服务端一起配通并顺手优化桌面性能”时使用；局域网/直连默认仍走 `headless-rdp-remmina-audio`
**文件：**
- `SKILL.md` - 技能说明文档，包含服务端检查、Tailscale 安装登录、XFCE 优化、Remmina 调参、MagicDNS 与 3389 联通验证的完整工作流

### 56. ssh-monitor-cycle
**功能：** 在单个终端里按 `~/.ssh/config` 轮询多台 SSH 主机，依次运行 `htop` 和 `jtop/nvtop`，并通过本地 PTY 代理支持 `PageUp/PageDown` 切换与 `Ctrl-G/Ctrl-R` 停驻/恢复
**用途：** 当需要在一台终端里循环查看多台机器的 CPU/GPU 负载，希望保留远端全屏监控界面、自动处理 `htop` 缺失安装，并直接用按键完成上一台/下一台切换或停驻当前界面时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、运行方式、按键说明与限制）
- `scripts/ssh_monitor_cycle.py` - 主逻辑，负责主机发现、SSH PTY 代理、`PageUp/PageDown` 切换与 `Ctrl-G/Ctrl-R` 停驻控制
- `scripts/ssh_monitor_cycle.sh` - 启动包装脚本，统一从 shell 调用 Python 版本

### 57. remmina-x11-clipboard-bridge
**功能：** 修复 Linux X11 下 Remmina 内复制文本后无法在本地应用直接 `Ctrl+V` 粘贴的问题，并自动安装/配置 `autocutsel` 进行 `PRIMARY` 与 `CLIPBOARD` 桥接
**用途：** 当用户说“Remmina 里复制的文本贴不到外面”“X11 下远程桌面选中文本后本地剪贴板没更新”，或想把这个修复做成登录后自动生效时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、诊断顺序、安装步骤、验证与回滚）
- `scripts/install_autocutsel_bridge.sh` - 安装 `autocutsel`、写入 `~/.config/autostart/autocutsel.desktop`，并在当前 X11 会话立即启动桥接

### 58. jetson-agx-max-power
**功能：** 在 `Jetson AGX Orin` 上查看当前 power mode / clocks 状态，切到 `MAXN + jetson_clocks`，并恢复到执行前自动保存的状态
**用途：** 当用户说“把 AGX 切到 max power”“开 MAXN”“确认现在是不是最大 clock”“恢复之前的 nvpmodel / clocks 状态”时使用
**文件：**
- `SKILL.md` - 技能说明文档（标准工作流、行为约定、约束与验证方式）
- `scripts/jetson_agx_max_power.sh` - 统一入口脚本，支持 `status|max|restore` 以及 `状态|最大|恢复`
- `agents/openai.yaml` - skill 的 UI 元数据

### 59. v2rayn-linux-github-install
**功能：** 在 Linux 上直接从 GitHub Releases 安装指定版本的 `v2rayN`，并校验 GUI 客户端是否安装成功
**用途：** 当用户要求安装 `v2rayN`、明确指定版本号（如 `7.20.2`）、要求使用 Linux `.deb` 包而不是 Windows 资产，或需要在 Ubuntu ARM64/x64 上完成下载、安装与验证时使用
**文件：**
- `SKILL.md` - 技能说明文档（版本选择、GitHub 下载、`apt` 安装、结果校验与失败处理）

### 60. lmstudio-brave-mcp-bootstrap
**功能：** 为 LM Studio 一键安装 Brave Search MCP，写入本地 `mcp.json`、自定义 MCP server、启动脚本和凭证模板，支持代理、IPv4 与重试策略
**用途：** 当用户需要把 Brave Search API 接入 LM Studio、希望把这套 MCP 搜索能力迁移到其他 Linux/macOS 设备、或希望把代理配置稳定固化到 LM Studio 子进程时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、标准工作流、资源说明）
- `agents/openai.yaml` - skill UI 元数据，方便支持 skill 面板的平台直接触发
- `assets/brave-lmstudio-mcp.mjs` - 自定义 Brave MCP server，暴露 web/news/video/image/place/suggest/spellcheck/summarizer 等工具
- `assets/brave-lmstudio-mcp.sh` - LM Studio 启动脚本，负责加载凭证并拉起 Node server
- `assets/brave-official-mcp.sh` - 官方 Brave MCP 启动脚本，适用于 `--mode official`
- `assets/brave-search.env.example` - 凭证与代理模板
- `references/troubleshooting.md` - Brave MCP 常见超时、代理和套餐边界排障说明
- `scripts/install_lmstudio_brave_mcp.sh` - 一键安装或更新 LM Studio Brave MCP 的入口脚本，支持 `custom` / `official` 模式，并可做链路自检

### 61. chromium-v2ray-google-fix
**功能：** 修复 Linux 上 Chromium 通过 `v2rayN/xray` 访问 `www.google.com` 的问题，覆盖代理诊断、DNS 污染排查、Chromium 固定代理启动包装器，以及桌面快捷方式生成
**用途：** 当用户遇到“Chromium 能开百度但打不开 Google”“需要把 Chromium 固定走本地 V2Ray 代理”“要生成指向 `~/.local/bin/chromium` 的桌面快捷方式”时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、工作流、安全规则）
- `scripts/fix_chromium_v2ray_google.sh` - 诊断/修复脚本，支持 `diagnose`、`apply-wrapper`、`desktop`、`set-dns`、`all`

### 62. codex-safe-sandbox-no-approval
**功能：** 把 Codex 全局默认权限切到“相对安全的 sandbox + 不审批”组合，即 `sandbox_mode = "workspace-write"` 与 `approval_policy = "never"`，并保留 `~/.codex/config.toml` 里的其他设置
**用途：** 当用户希望取消默认 `danger-full-access`、恢复到更安全的工作区写入沙箱，同时又不想每次手动批准命令时使用
**文件：**
- `SKILL.md` - 技能说明文档（触发条件、标准工作流、写入值与行为边界）
- `scripts/manage_codex_safe_no_approval.sh` - 配置管理脚本，支持 `status` 和 `apply`，写入前自动备份现有 `config.toml`


### 63. codex-rs-build-troubleshoot
**功能：** 同步 `codex-rs` 最新代码、编译 `codex-cli`，并诊断 `core`、`tui`、`app-server`、`mcp` 等核心模块构建状态以及 `/loop`、二进制路径、feature 配置错位问题
**用途：** 当需要从云端同步最新源码、开始编译、确认核心模块是否随依赖链成功编译，或排查“源码已改但运行行为没变”和 `/loop` alarm 功能异常时使用
**文件：**
- `SKILL.md` - 技能说明文档（主流程、判断口径、/loop 专项检查）
- `scripts/build_codex_rs.sh` - 同步、编译、二进制核对、`/loop` 诊断和关键测试入口脚本
- `references/troubleshooting.md` - 常见构建错位、feature gate、旧进程和 `/loop` 相关排障说明


### 64. llama-cpp-minimax27-webui-brave
**功能：** 在 `llama.cpp` 中编译 CUDA 版 `llama-server`，启动 MiniMax-M2.7 WebUI，并接入 Brave MCP 搜索桥接
**用途：** 当需要在本地 `llama.cpp` 里跑 Unsloth 的 `MiniMax-M2.7-GGUF`、启用 WebUI、保留已验证的 thinking 配置，并把 Brave MCP 联网搜索接进聊天界面时使用
**文件：**
- `SKILL.md` - 技能说明文档（标准工作流、关键规则、已验证经验）
- `scripts/build_llama_server_cuda.sh` - CUDA 版 `llama-server` 编译入口脚本
- `scripts/check_minimax27_stack.sh` - Brave MCP / llama-server 健康检查与最小聊天验证脚本
- `references/runbook.md` - 编译、启动、测试和常见问题处理手册



### 65. lmstudio-auto-updater
**功能：** 为 Linux 上通过 AppImage 安装的 LM Studio 执行自动检查、下载、校验、切换软链和用户级 systemd 定时更新
**用途：** 当需要检查本机 LM Studio 是否有新版本、执行安全升级、修复桌面启动器到最新 AppImage，或安装用户级自动更新定时器时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、标准工作流、验证口径）
- `scripts/lmstudio_auto_update.sh` - LM Studio AppImage 检查、升级、清理和定时任务安装入口脚本
- `scripts/selftest.sh` - 无副作用自检脚本，验证 latest 跳转、版本探测与下载链路
- `agents/openai.yaml` - skill 的 UI 元数据

### 66. jetson-super-mode-upgrade
**功能：** 在 Jetson Orin Nano / Orin NX 上启用并验收真正可用的 Super Mode，覆盖 Super DTB、`nv_boot_control.conf`、bootloader capsule、双重启验证与回滚
**用途：** 当系统里已经出现 `*_super.conf`、`nv-super.dtb` 或 super capsule，但仅靠 `nvpmodel` 切换并没有真正提频、GPU 仍卡在 `918000000`，需要把“伪 Super”升级成“真 Super”时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、两阶段升级流程、验收指标与回滚规则）
- `references/runbook.md` - 命令清单、关键检查点、典型半成功现象与回滚示例

### 67. pywxdump-linux-bootstrap
**功能：** 为当前仓库的 Linux 微信工具链执行依赖检查、安装、修复和配置写入，并统一复用正式入口脚本
**用途：** 当需要在新机器初始化 PyWxDump Linux 微信环境、排查 watcher/link-doc/ASR 前置依赖、执行 profile 化安装或补写配置时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用场景、标准工作流、profile 规则与约束）
- `scripts/bootstrap_with_profiles.sh` - 轻量入口脚本，自动定位仓库与 Python 并转调 `tools/bootstrap_linux_wechat_stack.py`

### 68. pywxdump-obsidian-shortcut
**功能：** 为当前仓库生成“先增量导出 chat_archive，再打开 Obsidian Vault”的 Linux 桌面快捷方式，并统一复用正式入口脚本
**用途：** 当需要在新机器上初始化微信知识库桌面入口、修复已有快捷方式，或在 Vault 路径迁移后重新生成启动入口时使用
**文件：**
- `SKILL.md` - 技能说明文档（用途、默认参数、工作流与限制说明）
- `scripts/install_shortcut.sh` - 轻量入口脚本，自动定位仓库与 Python 并转调 `tools/install_obsidian_vault_shortcut.py`

### 69. android-tablet-sunshine-moonlight-ubuntu
**功能：** 在 Ubuntu 24.x 上用 Sunshine + Moonlight 把当前桌面共享到 Android 平板，并用 `adb` 校验平板分辨率、前台应用与连通状态
**用途：** 当用户想把当前 Ubuntu 屏幕共享到安卓平板、需要区分“当前桌面共享”与“VNC 独立桌面”、希望根据平板实际分辨率做判断，或要确认 Moonlight 是否真的连接到当前桌面时使用
**文件：**
- `SKILL.md` - 技能说明文档（适用边界、决策规则、标准工作流、分辨率指导与常见误区）
- `references/apps-and-roles.md` - 记录 Ubuntu 端与 Android 端分别使用哪些 app、各自角色是什么，以及 Sunshine+Moonlight 与 TigerVNC+AVNC 的边界
- `scripts/adb_tablet_display_info.sh` - 读取 Android 平板的 `wm size`、`wm density` 与 `dumpsys display` 关键信息，确认真实物理分辨率和横屏逻辑分辨率
- `scripts/sunshine_moonlight_status.sh` - 汇总 ADB 连接、Android 前台 Moonlight 焦点、主机 `xrandr`、Sunshine 服务与最近日志，快速判断当前桌面共享链路是否正常

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
