# MichaelSun/cfo-check Methodology Provenance

This skill adopts a curated, locally maintained subset of
`MichaelSun/cfo-check`, commit `87f27bb8be1300e5e7ad53a4c79a95184373e4cf`
(retrieved July 22, 2026), licensed MIT.

The imported methodology is intentionally split across existing local skills
instead of copying the upstream profile distribution:

- `cfo-check`: CFO-style workflow, data provenance, valuation discipline, and
  report-level gates.
- `data-science/scripts/financial-analysis/`: reproducible ROIC-WACC,
  maintenance CapEx, capital allocation, accounting anomaly, cross-validation,
  and margin-of-safety analysis.
- `data-science/references/financial-analysis/`: Greenwald, McKinsey, reverse
  DCF, A-share data, and telecom valuation guidance.
- `data-science/references/buffett-review/`: moat, governance, owner earnings,
  capital allocation, valuation, and risk review material.
- `mx-*`: profile-scoped current A-share and Hong Kong data, screening,
  watchlist, and simulated-portfolio capabilities.

The upstream distribution's unrelated product, media, device, and general
automation skills are deliberately excluded. Its hard-coded profile paths and
any instruction to reveal a full private reasoning trace are not adopted.

When updating this integration, review the upstream change first and keep the
local source attribution and commit reference current.
