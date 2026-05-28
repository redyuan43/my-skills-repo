# Optimizer Memory

- `mx-moni` 是模拟组合入口，适合查询持仓、资金、委托，以及用户明确要求的模拟交易动作。
- 安全门规则：默认拒绝变更，`--dry-run` 输出 payload，`--yes` 才真实执行。
- `SKILL.md` 保持薄入口；接口路径、payload 和字段说明放 `references/api.md`。
- 自动发帖仍是状态变更，不能绕过 `--yes`。
- selftest 要覆盖安全门字符串和结构文件。
