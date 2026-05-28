---
name: skill-quality-gate
description: 对 `my-skills-repo` 里的顶层 skills 做静态质量检查和评分，覆盖结构、SkillOpt-lite references/eval、自检脚本、文档完整性、可执行性与风险模式扫描。适用于想快速发现缺失 `agents/openai.yaml`、`selftest.sh --safe`、`references/gate_checklist.md`、`eval/val/items.json`、危险命令、脚本语法问题或文档不完整的场景。
---

# Skill Quality Gate

当需要对 skills 仓库做一次统一静态巡检、快速发现低质量或高风险技能时使用这个 skill。

## 标准工作流

1. 在仓库根目录执行默认扫描：

```bash
python3 skill-quality-gate/scripts/skill_quality_gate.py
```

2. 如果只想输出机器可读 JSON，使用：

```bash
python3 skill-quality-gate/scripts/skill_quality_gate.py --json
```

3. 如果希望把 `selftest.sh --safe` 也纳入评分要求，使用：

```bash
python3 skill-quality-gate/scripts/skill_quality_gate.py --with-safe-check
```

## 行为约定

- 只扫描仓库根目录下带 `SKILL.md` 的技能目录
- 默认只做静态检查，不执行破坏性命令
- 会检查结构、`agents/openai.yaml`、SkillOpt-lite references、`eval/val/items.json`、文档关键词、shell 语法、`selftest.sh` 可执行位和风险命令模式
- 风险扫描会标记如 `rm -rf /`、`mkfs`、`fdisk`、`systemctl start/stop/restart` 这类高风险痕迹
- `--with-safe-check` 会要求 `selftest.sh` 暴露 `--safe`，用于无副作用的批量门禁

## 适用场景

- 发布 skill 前做一次仓库巡检
- 批量排查哪些 skill 缺少 `selftest.sh`
- 批量排查哪些 skill 缺少 `agents/openai.yaml`、`references/gate_checklist.md` 或 `eval/val/items.json`
- 快速发现脚本语法错误和明显风险模式
- 给技能仓库做可重复的质量评分

## 文件

- `scripts/skill_quality_gate.py`：静态扫描和评分入口
