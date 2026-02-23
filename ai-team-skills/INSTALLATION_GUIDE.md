# AI Team Skills 安装与使用指南

完整的安装和使用说明，帮助你快速上手 AI Team Skills。

## 📖 核心概念

### Skill (技能) vs Agent (代理)

理解两者的区别是关键：

| 概念 | 位置 | 作用 | 类比 |
|------|------|------|------|
| **Skill** | `~/.claude/skills/` | 用户可调用的命令 | 工具箱/插件 |
| **Agent** | `~/.claude/agents/` | ai-team 启动的工作者定义 | 员工说明书 |

**关系**：
- **Skill** = 用户接口（你输入的 `/命令`）
- **Agent** = 内部工人（skill 内部启动的 subagent）

### 项目结构

```
~/.claude/
├── skills/                    # Skills - 用户直接调用
│   ├── ai-team/               # /ai-team - 多 Agent 流水线
│   ├── gemini-agent/          # /gemini-agent - UI 设计专家
│   └── codex-agent/           # /codex-agent - 代码编写专家
│
└── agents/                    # Agents - ai-team 内部使用
    ├── codex-worker.md        # Codex Worker 行为定义
    └── gemini-worker.md       # Gemini Worker 行为定义
```

**重要**：
- `skills/` 目录包含你可以调用的命令
- `agents/` 目录**仅在使用 `/ai-team` 时需要**

---

## 🔧 前置要求

在安装前，确保已安装以下工具：

- ✅ [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装
- ✅ [Gemini CLI](https://github.com/google-gemini/gemini-cli) 已安装并登录
- ✅ [Codex CLI](https://github.com/openai/codex) 已安装并配置

### 验证前置工具

```bash
# 验证 Claude Code
claude --version

# 验证 Gemini CLI
gemini --version

# 验证 Codex CLI
codex --version
```

---

## 📥 安装方式

### 方案 1: 完整安装（推荐 - 包含多 Agent 流水线）

**适用场景**：
- 需要多 Agent 协作（UI + 后端 + 测试）
- 大型重构或全栈开发
- 想体验完整的流水线功能

#### Linux / macOS

```bash
# 切换到项目目录
cd /path/to/ai-team-skills

# 安装所有 skills
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/

# 安装 agent 定义文件（ai-team 必需）
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/

# 验证安装
ls ~/.claude/skills/
ls ~/.claude/agents/
```

#### Windows (PowerShell)

```powershell
# 切换到项目目录
cd C:\path\to\ai-team-skills

# 安装所有 skills
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object {
    Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" -Force
}

# 安装 agent 定义文件（ai-team 必需）
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\*.md "$env:USERPROFILE\.claude\agents\" -Force

# 验证安装
Get-ChildItem "$env:USERPROFILE\.claude\skills\"
Get-ChildItem "$env:USERPROFILE\.claude\agents\"
```

**安装内容**：
- ✅ 3 个 Skill（`/ai-team`, `/gemini-agent`, `/codex-agent`）
- ✅ 2 个 Agent 定义（codex-worker, gemini-worker）

---

### 方案 2: 单 Agent 安装（轻量版 - 只需单独调用）

**适用场景**：
- 只需要简化 CLI 调用
- 不需要多 Agent 协作
- 只用单个 Agent 完成任务

#### Linux / macOS

```bash
cd /path/to/ai-team-skills

# 只安装单 Agent skills
cp -r gemini-agent codex-agent ~/.claude/skills/

# 验证安装
ls ~/.claude/skills/
```

#### Windows (PowerShell)

```powershell
cd C:\path\to\ai-team-skills

# 只安装单 Agent skills
@("gemini-agent", "codex-agent") | ForEach-Object {
    Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" -Force
}

# 验证安装
Get-ChildItem "$env:USERPROFILE\.claude\skills\"
```

**安装内容**：
- ✅ 2 个 Skill（`/gemini-agent`, `/codex-agent`）
- ❌ **无法使用** `/ai-team` 命令

---

### 方案 3: 按需安装（最小化）

只安装你需要的 skill：

```bash
# 只安装 Codex Agent
cp -r codex-agent ~/.claude/skills/

# 只安装 Gemini Agent
cp -r gemini-agent ~/.claude/skills/

# 只安装 AI Team（需要同时安装 agents/）
cp -r ai-team ~/.claude/skills/
mkdir -p ~/.claude/agents && cp agents/*.md ~/.claude/agents/
```

---

## ✅ 验证安装

### 检查文件结构

```bash
# Linux / macOS
tree ~/.claude/skills/
tree ~/.claude/agents/

# 或使用 ls
ls -R ~/.claude/skills/
ls ~/.claude/agents/
```

```powershell
# Windows
Get-ChildItem -Recurse "$env:USERPROFILE\.claude\skills\"
Get-ChildItem "$env:USERPROFILE\.claude\agents\"
```

**预期输出**（完整安装）：

```
~/.claude/skills/
├── ai-team/
│   ├── SKILL.md
│   └── references/
│       └── pipeline-templates.md
├── gemini-agent/
│   ├── SKILL.md
│   ├── scripts/
│   │   ├── gemini-run.sh
│   │   └── gemini-run.ps1
│   └── references/
│       └── prompt-templates.md
└── codex-agent/
    ├── SKILL.md
    ├── scripts/
    │   ├── codex-run.sh
    │   └── codex-run.ps1
    └── references/
        └── prompt-templates.md

~/.claude/agents/
├── codex-worker.md
└── gemini-worker.md
```

### 测试 Skills

在 Claude Code 对话中输入：

```bash
# 测试 Codex Agent
/codex-agent 写一个 Hello World

# 测试 Gemini Agent
/gemini-agent 设计一个按钮

# 测试 AI Team（需要完整安装）
/ai-team 实现一个简单的计数器组件
```

---

## 🎯 使用方式

### 方式 1: 直接调用 Skill 命令

在 Claude Code 对话中直接输入：

```bash
# 单 Agent 调用
/codex-agent 实现一个 JWT 认证中间件
/codex 实现一个 JWT 认证中间件  # 简写形式

/gemini-agent 设计一个登录表单组件
/design-ui 设计一个登录表单组件  # 简写形式

# 多 Agent 流水线（需要完整安装）
/ai-team 完整实现用户管理功能，包括 UI、后端 API 和测试
/team 完整实现用户管理功能，包括 UI、后端 API 和测试  # 简写形式
```

### 方式 2: 自然语言描述（Claude 自动路由）

你也可以**不输入命令**，直接描述任务，Claude Code 会自动选择合适的 skill：

```
用户输入: "帮我实现一个登录表单"
→ Claude 自动识别关键词 "登录表单" → 调用 /gemini-agent

用户输入: "修复这个认证 bug"
→ Claude 自动识别关键词 "修复" "bug" → 调用 /codex-agent

用户输入: "完整实现用户管理功能"
→ Claude 自动识别关键词 "完整实现" → 调用 /ai-team
```

**自动路由关键词**：

| Skill | 触发关键词 |
|-------|-----------|
| `/codex-agent` | 实现、编写、修复、重构、测试、代码、功能、API、后端、数据库、bug、review、审查 |
| `/gemini-agent` | 设计、UI、组件、页面、布局、样式、美化、前端、界面、视觉 |
| `/ai-team` | 完整、全栈、流水线、协作、大型、重构 + 多模块 |

---

## 📋 使用场景

### 场景 1: 单纯代码实现

```bash
# 使用 Codex Agent
/codex-agent 实现一个 JWT token 验证中间件，支持过期检查和刷新
```

**工作流程**：
1. Claude Code 分析需求
2. 构建 Codex 友好的 prompt
3. 调用 `codex-run.sh` 脚本
4. 收集和审查代码输出

### 场景 2: 单纯 UI 设计

```bash
# 使用 Gemini Agent
/gemini-agent 设计一个响应式导航栏，包含 logo、菜单和搜索框
```

**工作流程**：
1. Claude Code 分析需求
2. 构建 Gemini 友好的 prompt
3. 调用 `gemini-run.sh` 脚本
4. 收集和审查 UI 代码

### 场景 3: 代码审查

```bash
# 使用 Codex Agent 的 review 模式
/codex-agent 审查我的未提交变更，检查代码质量和安全问题
```

**工作流程**：
1. 调用 `codex-run.sh -r --uncommitted`
2. Codex 分析未提交的代码
3. 返回审查报告

### 场景 4: UI + 后端 + 测试（全栈开发）

```bash
# 使用 AI Team 流水线
/ai-team 完整实现用户管理功能：
- UI: 用户列表页、编辑表单
- 后端: CRUD API 接口
- 测试: 单元测试和集成测试
```

**工作流程（自动编排）**：
1. **Phase 1**: Claude 分析任务 → 拆分为子任务
2. **Phase 2**: 启动 Workers
   - gemini-worker: 设计 UI 组件
   - codex-worker-1: 实现后端 API
   - codex-worker-2: 编写测试
3. **Phase 3**: Claude 审查和整合
4. **Phase 4**: 运行测试并交付

### 场景 5: 多模块并行重构

```bash
# 使用 AI Team 并行模式
/ai-team 重构认证系统：
- 模块 A: 重构 JWT 验证逻辑
- 模块 B: 重构权限检查中间件
- 模块 C: 更新相关测试
```

**工作流程（并行执行）**：
1. 启动 3 个 codex-worker 并行处理
2. 各自独立完成任务
3. Claude 整合所有变更
4. 运行集成测试

---

## 🔍 Skill 详细说明

### /codex-agent

**功能**: 代码编写、修复、重构、审查

**参数示例**:
```bash
# 标准代码编写
/codex-agent 实现一个 Redis 缓存工具类

# 代码审查
/codex-agent 审查我的未提交变更

# Bug 修复
/codex-agent 修复登录超时的问题
```

**包装脚本位置**:
- Linux/macOS: `~/.claude/skills/codex-agent/scripts/codex-run.sh`
- Windows: `~/.claude/skills/codex-agent/scripts/codex-run.ps1`

**Prompt 模板**: `~/.claude/skills/codex-agent/references/prompt-templates.md`

---

### /gemini-agent

**功能**: UI 设计、前端组件、页面布局、样式美化

**参数示例**:
```bash
# UI 组件设计
/gemini-agent 设计一个模态框组件，支持自定义标题和内容

# 页面布局
/gemini-agent 设计一个 Dashboard 页面，包含侧边栏和统计卡片

# 样式美化
/gemini-agent 美化这个表单，使用现代简洁的设计风格
```

**包装脚本位置**:
- Linux/macOS: `~/.claude/skills/gemini-agent/scripts/gemini-run.sh`
- Windows: `~/.claude/skills/gemini-agent/scripts/gemini-run.ps1`

**Prompt 模板**: `~/.claude/skills/gemini-agent/references/prompt-templates.md`

---

### /ai-team

**功能**: 多 Agent 协作流水线，自动编排

**参数示例**:
```bash
# 全栈功能开发
/ai-team 实现文章管理系统，包括列表、详情、编辑功能

# 大型重构
/ai-team 重构整个认证系统，包括前端登录组件和后端中间件

# UI + 实现联动
/ai-team 设计并实现一个评论系统
```

**流水线模板**: `~/.claude/skills/ai-team/references/pipeline-templates.md`

**Agent 定义**:
- `~/.claude/agents/codex-worker.md` - Codex Worker 行为规则
- `~/.claude/agents/gemini-worker.md` - Gemini Worker 行为规则

---

## 🛠️ 高级用法

### 直接调用包装脚本（绕过 Skill）

如果你熟悉脚本参数，可以直接调用：

```bash
# Codex Agent - 代码编写
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -f /tmp/prompt.txt \
  -s dangerous \
  -d /path/to/project \
  -o /tmp/result.txt

# Codex Agent - 代码审查
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -r --uncommitted \
  -d /path/to/project \
  -o /tmp/review.txt

# Gemini Agent - UI 设计
bash ~/.claude/skills/gemini-agent/scripts/gemini-run.sh \
  -f /tmp/prompt.txt \
  -d /path/to/project
```

### 直接调用 CLI（最底层）

```bash
# 确保 PATH 包含 CLI
export PATH="$HOME/.local/share/pnpm:$PATH"

# Codex CLI
codex exec -s danger-full-access -C /path/to/project - < /tmp/prompt.txt

# Gemini CLI
gemini yolo "设计一个按钮"
```

**对比**：

| 层级 | 易用性 | 灵活性 | 适用场景 |
|------|--------|--------|----------|
| Skill 命令 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 日常使用 |
| 包装脚本 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 自定义参数 |
| 原始 CLI | ⭐⭐ | ⭐⭐⭐⭐⭐ | 深度定制 |

---

## 🔧 常见问题

### Q1: 安装后无法使用 `/ai-team`

**原因**: 未安装 `agents/` 目录下的 Agent 定义文件

**解决**:
```bash
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```

### Q2: 提示 `command not found: codex` 或 `command not found: gemini`

**原因**: CLI 工具未安装或未添加到 PATH

**解决**:
```bash
# 检查 Codex 安装
which codex

# 检查 Gemini 安装
which gemini

# 手动添加到 PATH（如果需要）
export PATH="$HOME/.local/share/pnpm:$PATH"
```

### Q3: Skill 调用失败，提示参数错误

**原因**: 包装脚本权限问题或路径问题

**解决**:
```bash
# 添加执行权限
chmod +x ~/.claude/skills/codex-agent/scripts/*.sh
chmod +x ~/.claude/skills/gemini-agent/scripts/*.sh

# 检查脚本路径
ls -l ~/.claude/skills/codex-agent/scripts/
```

### Q4: 想更新 Skills

**解决**:
```bash
# 重新复制即可（会覆盖）
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/
cp agents/*.md ~/.claude/agents/
```

### Q5: 想卸载 Skills

**解决**:
```bash
# 删除 skills
rm -rf ~/.claude/skills/ai-team
rm -rf ~/.claude/skills/gemini-agent
rm -rf ~/.claude/skills/codex-agent

# 删除 agents（如果不再需要）
rm -rf ~/.claude/agents/codex-worker.md
rm -rf ~/.claude/agents/gemini-worker.md
```

---

## 📚 参考资料

### 官方文档
- [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Codex CLI GitHub](https://github.com/openai/codex)

### 项目文件
- [README.md](README.md) - 项目概述（中文）
- [README_EN.md](README_EN.md) - 项目概述（英文）
- [Codex Prompt 模板](codex-agent/references/prompt-templates.md)
- [Gemini Prompt 模板](gemini-agent/references/prompt-templates.md)
- [AI Team 流水线模板](ai-team/references/pipeline-templates.md)

---

## 🆘 获取帮助

遇到问题？

1. 检查 [常见问题](#常见问题) 部分
2. 查看各 Skill 的 `SKILL.md` 文件
3. 阅读 `references/` 目录下的模板和示例
4. 提交 GitHub Issue（如果适用）

---

## 📄 License

MIT
