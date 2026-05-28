# mx-moni API Reference

## Endpoints

Base URL defaults to `https://mkapi2.dfcfs.com/finskillshub`.

| Action | Endpoint | Payload |
| --- | --- | --- |
| positions | `/api/claw/mockTrading/positions` | `{"moneyUnit": 1}` |
| balance | `/api/claw/mockTrading/balance` | `{"moneyUnit": 1}` |
| orders | `/api/claw/mockTrading/orders` | `{"fltOrderDrt": 0, "fltOrderStatus": 0}` |
| buy/sell | `/api/claw/mockTrading/trade` | `{"type": "buy|sell", "stockCode": "600519", "quantity": 100, "useMarketPrice": false, "price": 170000}` |
| cancel | `/api/claw/mockTrading/cancel` | `{"type": "all"}` or `{"type": "order", "orderId": "...", "stockCode": "600519"}` |
| newPost | `/api/claw/mockTrading/newPost` | `{"text": "..."}` |

## Safety Gate

`positions`、`balance`、`orders` 属于查询动作，可直接请求。

`buy`、`sell`、`cancel`、`newPost` 属于外部状态变更，脚本默认拒绝真实调用：

```bash
python3 scripts/mx_moni.py --dry-run "买入 600519 1700 100 股"
python3 scripts/mx_moni.py --yes "买入 600519 1700 100 股"
```

`--dry-run` 输出 method、URL 和 payload，不需要真实请求；`--yes` 是唯一真实执行开关。

## Payload Notes

- 股票代码仅支持 6 位 A 股代码。
- `quantity` 以股为单位；输入“手”时脚本会乘以 100。
- 限价委托会将价格按接口要求放大为整数：沪市通常 2 位小数，深市通常 3 位小数。
- 市价委托设置 `useMarketPrice=true`，不会传限价 `price`。
