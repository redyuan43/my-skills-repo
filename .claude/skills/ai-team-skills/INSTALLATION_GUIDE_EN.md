# AI Team Skills Installation & Usage Guide

Complete installation and usage instructions to help you get started with AI Team Skills quickly.

## 📖 Core Concepts

### Skill vs Agent

Understanding the difference is key:

| Concept | Location | Purpose | Analogy |
|---------|----------|---------|----------|
| **Skill** | `~/.claude/skills/` | User-invocable commands | Toolbox/Plugin |
| **Agent** | `~/.claude/agents/` | Worker definitions for ai-team | Employee manual |

**Relationship**:
- **Skill** = User interface (the `/command` you type)
- **Agent** = Internal worker (subagent launched by skills)

### Project Structure

```
~/.claude/
├── skills/                    # Skills - User-invocable
│   ├── ai-team/               # /ai-team - Multi-agent pipeline
│   ├── gemini-agent/          # /gemini-agent - UI design expert
│   └── codex-agent/           # /codex-agent - Code writing expert
│
└── agents/                    # Agents - Used internally by ai-team
    ├── codex-worker.md        # Codex Worker behavior definition
    └── gemini-worker.md       # Gemini Worker behavior definition
```

**Important**:
- `skills/` directory contains commands you can invoke
- `agents/` directory is **only needed when using `/ai-team`**

---

## 🔧 Prerequisites

Before installation, ensure the following tools are installed:

- ✅ [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- ✅ [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed and authenticated
- ✅ [Codex CLI](https://github.com/openai/codex) installed and configured

### Verify Prerequisites

```bash
# Verify Claude Code
claude --version

# Verify Gemini CLI
gemini --version

# Verify Codex CLI
codex --version
```

---

## 📥 Installation Methods

### Option 1: Full Installation (Recommended - Includes Multi-Agent Pipeline)

**Use Cases**:
- Need multi-agent collaboration (UI + backend + tests)
- Large-scale refactoring or full-stack development
- Want to experience the complete pipeline functionality

#### Linux / macOS

```bash
# Navigate to project directory
cd /path/to/ai-team-skills

# Install all skills
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/

# Install agent definitions (required for ai-team)
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/

# Verify installation
ls ~/.claude/skills/
ls ~/.claude/agents/
```

#### Windows (PowerShell)

```powershell
# Navigate to project directory
cd C:\path\to\ai-team-skills

# Install all skills
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object {
    Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" -Force
}

# Install agent definitions (required for ai-team)
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\*.md "$env:USERPROFILE\.claude\agents\" -Force

# Verify installation
Get-ChildItem "$env:USERPROFILE\.claude\skills\"
Get-ChildItem "$env:USERPROFILE\.claude\agents\"
```

**What's Installed**:
- ✅ 3 Skills (`/ai-team`, `/gemini-agent`, `/codex-agent`)
- ✅ 2 Agent definitions (codex-worker, gemini-worker)

---

### Option 2: Single Agent Installation (Lightweight - Individual Use Only)

**Use Cases**:
- Only need to simplify CLI calls
- Don't need multi-agent collaboration
- Use single agents for tasks

#### Linux / macOS

```bash
cd /path/to/ai-team-skills

# Install single agent skills only
cp -r gemini-agent codex-agent ~/.claude/skills/

# Verify installation
ls ~/.claude/skills/
```

#### Windows (PowerShell)

```powershell
cd C:\path\to\ai-team-skills

# Install single agent skills only
@("gemini-agent", "codex-agent") | ForEach-Object {
    Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" -Force
}

# Verify installation
Get-ChildItem "$env:USERPROFILE\.claude\skills\"
```

**What's Installed**:
- ✅ 2 Skills (`/gemini-agent`, `/codex-agent`)
- ❌ **Cannot use** `/ai-team` command

---

### Option 3: Custom Installation (Minimal)

Install only what you need:

```bash
# Install Codex Agent only
cp -r codex-agent ~/.claude/skills/

# Install Gemini Agent only
cp -r gemini-agent ~/.claude/skills/

# Install AI Team only (requires agents/)
cp -r ai-team ~/.claude/skills/
mkdir -p ~/.claude/agents && cp agents/*.md ~/.claude/agents/
```

---

## ✅ Verify Installation

### Check File Structure

```bash
# Linux / macOS
tree ~/.claude/skills/
tree ~/.claude/agents/

# Or use ls
ls -R ~/.claude/skills/
ls ~/.claude/agents/
```

```powershell
# Windows
Get-ChildItem -Recurse "$env:USERPROFILE\.claude\skills\"
Get-ChildItem "$env:USERPROFILE\.claude\agents\"
```

**Expected Output** (full installation):

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

### Test Skills

In Claude Code conversation:

```bash
# Test Codex Agent
/codex-agent write a Hello World function

# Test Gemini Agent
/gemini-agent design a button component

# Test AI Team (requires full installation)
/ai-team implement a simple counter component
```

---

## 🎯 Usage Methods

### Method 1: Direct Skill Commands

In Claude Code conversation:

```bash
# Single agent invocation
/codex-agent implement a JWT authentication middleware
/codex implement a JWT authentication middleware  # Short form

/gemini-agent design a login form component
/design-ui design a login form component  # Short form

# Multi-agent pipeline (requires full installation)
/ai-team implement complete user management with UI, backend API, and tests
/team implement complete user management with UI, backend API, and tests  # Short form
```

### Method 2: Natural Language (Claude Auto-Routes)

You can also **skip commands** and just describe the task - Claude Code will automatically select the appropriate skill:

```
User input: "help me implement a login form"
→ Claude detects "login form" → invokes /gemini-agent

User input: "fix this authentication bug"
→ Claude detects "fix" "bug" → invokes /codex-agent

User input: "implement complete user management"
→ Claude detects "complete implementation" → invokes /ai-team
```

**Auto-routing Keywords**:

| Skill | Trigger Keywords |
|-------|------------------|
| `/codex-agent` | implement, write, fix, refactor, test, code, feature, API, backend, database, bug, review, audit |
| `/gemini-agent` | design, UI, component, page, layout, style, beautify, frontend, interface, visual |
| `/ai-team` | complete, full-stack, pipeline, collaborate, large, refactor + multi-module |

---

## 📋 Use Cases

### Case 1: Pure Code Implementation

```bash
# Use Codex Agent
/codex-agent implement a JWT token verification middleware with expiry check and refresh
```

**Workflow**:
1. Claude Code analyzes requirements
2. Builds Codex-friendly prompt
3. Invokes `codex-run.sh` script
4. Collects and reviews code output

### Case 2: Pure UI Design

```bash
# Use Gemini Agent
/gemini-agent design a responsive navigation bar with logo, menu, and search box
```

**Workflow**:
1. Claude Code analyzes requirements
2. Builds Gemini-friendly prompt
3. Invokes `gemini-run.sh` script
4. Collects and reviews UI code

### Case 3: Code Review

```bash
# Use Codex Agent review mode
/codex-agent review my uncommitted changes for code quality and security issues
```

**Workflow**:
1. Invokes `codex-run.sh -r --uncommitted`
2. Codex analyzes uncommitted code
3. Returns review report

### Case 4: UI + Backend + Tests (Full-Stack)

```bash
# Use AI Team pipeline
/ai-team implement complete user management:
- UI: user list page and edit form
- Backend: CRUD API endpoints
- Tests: unit and integration tests
```

**Workflow (Auto-orchestrated)**:
1. **Phase 1**: Claude analyzes task → splits into subtasks
2. **Phase 2**: Launch workers
   - gemini-worker: design UI components
   - codex-worker-1: implement backend API
   - codex-worker-2: write tests
3. **Phase 3**: Claude reviews and integrates
4. **Phase 4**: Run tests and deliver

### Case 5: Multi-Module Parallel Refactoring

```bash
# Use AI Team parallel mode
/ai-team refactor authentication system:
- Module A: refactor JWT validation logic
- Module B: refactor permission check middleware
- Module C: update related tests
```

**Workflow (Parallel Execution)**:
1. Launch 3 codex-workers in parallel
2. Each completes their task independently
3. Claude integrates all changes
4. Run integration tests

---

## 🔍 Skill Details

### /codex-agent

**Capabilities**: Code writing, fixing, refactoring, reviewing

**Example Usage**:
```bash
# Standard code writing
/codex-agent implement a Redis cache utility class

# Code review
/codex-agent review my uncommitted changes

# Bug fix
/codex-agent fix the login timeout issue
```

**Wrapper Scripts**:
- Linux/macOS: `~/.claude/skills/codex-agent/scripts/codex-run.sh`
- Windows: `~/.claude/skills/codex-agent/scripts/codex-run.ps1`

**Prompt Templates**: `~/.claude/skills/codex-agent/references/prompt-templates.md`

---

### /gemini-agent

**Capabilities**: UI design, frontend components, page layouts, styling

**Example Usage**:
```bash
# UI component design
/gemini-agent design a modal dialog with custom title and content

# Page layout
/gemini-agent design a Dashboard page with sidebar and stat cards

# Style beautification
/gemini-agent beautify this form with modern minimalist design
```

**Wrapper Scripts**:
- Linux/macOS: `~/.claude/skills/gemini-agent/scripts/gemini-run.sh`
- Windows: `~/.claude/skills/gemini-agent/scripts/gemini-run.ps1`

**Prompt Templates**: `~/.claude/skills/gemini-agent/references/prompt-templates.md`

---

### /ai-team

**Capabilities**: Multi-agent collaboration pipeline, auto-orchestration

**Example Usage**:
```bash
# Full-stack feature development
/ai-team implement article management system with list, detail, and edit features

# Large refactoring
/ai-team refactor entire authentication system including frontend login and backend middleware

# UI + implementation pipeline
/ai-team design and implement a comment system
```

**Pipeline Templates**: `~/.claude/skills/ai-team/references/pipeline-templates.md`

**Agent Definitions**:
- `~/.claude/agents/codex-worker.md` - Codex Worker behavior
- `~/.claude/agents/gemini-worker.md` - Gemini Worker behavior

---

## 🛠️ Advanced Usage

### Direct Wrapper Script Invocation (Bypass Skill)

If you're familiar with script parameters:

```bash
# Codex Agent - code writing
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -f /tmp/prompt.txt \
  -s dangerous \
  -d /path/to/project \
  -o /tmp/result.txt

# Codex Agent - code review
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -r --uncommitted \
  -d /path/to/project \
  -o /tmp/review.txt

# Gemini Agent - UI design
bash ~/.claude/skills/gemini-agent/scripts/gemini-run.sh \
  -f /tmp/prompt.txt \
  -d /path/to/project
```

### Direct CLI Invocation (Lowest Level)

```bash
# Ensure CLI is in PATH
export PATH="$HOME/.local/share/pnpm:$PATH"

# Codex CLI
codex exec -s danger-full-access -C /path/to/project - < /tmp/prompt.txt

# Gemini CLI
gemini yolo "design a button"
```

**Comparison**:

| Level | Ease of Use | Flexibility | Use Case |
|-------|-------------|-------------|----------|
| Skill Commands | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Daily use |
| Wrapper Scripts | ⭐⭐⭐ | ⭐⭐⭐⭐ | Custom parameters |
| Raw CLI | ⭐⭐ | ⭐⭐⭐⭐⭐ | Deep customization |

---

## 🔧 Troubleshooting

### Q1: Cannot use `/ai-team` after installation

**Cause**: Agent definition files not installed

**Solution**:
```bash
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```

### Q2: `command not found: codex` or `command not found: gemini`

**Cause**: CLI tools not installed or not in PATH

**Solution**:
```bash
# Check Codex installation
which codex

# Check Gemini installation
which gemini

# Manually add to PATH (if needed)
export PATH="$HOME/.local/share/pnpm:$PATH"
```

### Q3: Skill invocation fails with parameter errors

**Cause**: Script permission or path issues

**Solution**:
```bash
# Add execute permissions
chmod +x ~/.claude/skills/codex-agent/scripts/*.sh
chmod +x ~/.claude/skills/gemini-agent/scripts/*.sh

# Check script paths
ls -l ~/.claude/skills/codex-agent/scripts/
```

### Q4: Want to update Skills

**Solution**:
```bash
# Re-copy (will overwrite)
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/
cp agents/*.md ~/.claude/agents/
```

### Q5: Want to uninstall Skills

**Solution**:
```bash
# Remove skills
rm -rf ~/.claude/skills/ai-team
rm -rf ~/.claude/skills/gemini-agent
rm -rf ~/.claude/skills/codex-agent

# Remove agents (if no longer needed)
rm -rf ~/.claude/agents/codex-worker.md
rm -rf ~/.claude/agents/gemini-worker.md
```

---

## 📚 References

### Official Documentation
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Codex CLI GitHub](https://github.com/openai/codex)

### Project Files
- [README.md](README.md) - Project overview (Chinese)
- [README_EN.md](README_EN.md) - Project overview (English)
- [Codex Prompt Templates](codex-agent/references/prompt-templates.md)
- [Gemini Prompt Templates](gemini-agent/references/prompt-templates.md)
- [AI Team Pipeline Templates](ai-team/references/pipeline-templates.md)

---

## 🆘 Get Help

Having issues?

1. Check the [Troubleshooting](#troubleshooting) section
2. Review each skill's `SKILL.md` file
3. Read templates and examples in `references/` directories
4. Submit a GitHub Issue (if applicable)

---

## 📄 License

MIT
