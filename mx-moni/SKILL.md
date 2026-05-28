---
name: mx-moni
description: 东方财富妙想模拟组合管理 skill。Use when the user explicitly wants to query simulated portfolio holdings, balance, orders, historical fills, or perform simulated buy, sell, cancel-order, and post-summary actions with MX_APIKEY.
---

# mx-moni 妙想模拟组合管理 skill

用于查询东方财富妙想模拟组合的持仓、资金、委托记录，并在用户明确要求时执行模拟买入、卖出、撤单或发帖。

## 使用边界

- 适合：模拟组合持仓、资金、委托查询；用户明确提出的模拟交易动作；收盘后模拟操作总结发帖。
- 不适合：真实资金交易、投资建议生成、代用户做交易决策、非 A 股模拟交易。
- 查询动作可直接运行；`buy`、`sell`、`cancel`、`newPost`、`--auto-post` 发帖等状态变更默认拒绝真实调用。
- 状态变更必须显式传 `--yes` 才会请求接口；用 `--dry-run` 可只输出 endpoint 和 payload。

## 配置

- `MX_APIKEY`：妙想 Skills 页面获取的 API Key，必须保密。
- `MX_API_URL`：可选，默认 `https://mkapi2.dfcfs.com/finskillshub`。
- 默认输出目录：`~/.mx/mx-moni/output/`。

## 快速调用

```bash
# 查询类：可直接运行
python3 scripts/mx_moni.py "我的持仓"
python3 scripts/mx_moni.py "账户资金"
python3 scripts/mx_moni.py "我的委托"

# 状态变更：先 dry-run 看 payload
python3 scripts/mx_moni.py --dry-run "买入 600519 1700 100 股"
python3 scripts/mx_moni.py --dry-run "撤销所有委托"

# 确认执行：必须显式 --yes
python3 scripts/mx_moni.py --yes "买入 600519 1700 100 股"
python3 scripts/mx_moni.py --yes "卖出 600519 100 股"
python3 scripts/mx_moni.py --yes "撤销所有委托"
python3 scripts/mx_moni.py --yes "总结一下今日操作"
```

## 参考资料

- 接口细节、请求体和响应字段见 `references/api.md`。
- 安全门检查见 `references/gate_checklist.md`。
- 负例和不采纳改动见 `references/rejected_edits.md`。
- 优化记忆见 `references/optimizer_memory.md`。
