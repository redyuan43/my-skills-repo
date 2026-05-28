# Gate Checklist

- 持仓、资金、委托查询可直接运行。
- `buy`、`sell`、`cancel`、`newPost` 和 `--auto-post` 发帖属于状态变更，默认拒绝真实调用。
- 状态变更必须显式传 `--yes`；`--dry-run` 只输出 endpoint 和 payload。
- 普通 dry-run 不要求 `MX_APIKEY`；真实查询、自动收盘检查或执行才需要密钥。
- 不把模拟交易动作包装成投资建议或收益承诺。
