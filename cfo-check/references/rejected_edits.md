# Rejected Edits

这些改法暂时不采用，后续优化时除非有新证据，不要重复引入。

## 把 data-science 全量说明复制进 cfo-check

拒绝原因：会让 `SKILL.md` 变长，降低触发后的可读性；`cfo-check` 只需要路由和质量门禁，具体 API 细节应复用 `$data-science` 和 `mx-*` skills。

## 让 cfo-check 直接执行自选股或模拟交易

拒绝原因：这类动作会改变外部状态。`cfo-check` 可以分析和建议下一步，但执行 `$mx-zixuan`、`$mx-moni` 必须由用户明确要求。

## 在 skill 中保存真实 API key 或示例密钥

拒绝原因：可提交文件不能包含真实密钥。只允许写变量名、配置路径和占位说明。

## 把所有估值方法都塞进主入口

拒绝原因：主入口过长会削弱 skill 的激活质量。估值公式、脚本和模板应放到 `references/` 或 `scripts/`，由具体任务按需加载。
