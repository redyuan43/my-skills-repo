---
name: spacex-frontend-style
description: Apply a SpaceX-inspired frontend design language and D-DIN typography. Use when the user asks for SpaceX style, getdesign.md spacex/design-md, cinematic black aerospace UI, D-DIN/DIN typography, or wants this visual style reused across local HTML/React/Vue/dashboard/tool pages; also use when checking or installing D-DIN fonts for frontend previews.
---

# SpaceX Frontend Style

## Workflow

1. Prefer project-local design rules first: `DESIGN.md`, `AGENTS.md`, existing components, screenshots, or explicit user instructions.
2. If SpaceX style is requested or no stronger local style exists, read `references/spacex-style.md`.
3. Check whether D-DIN is available before previewing typography:

```bash
fc-match "D-DIN"
```

4. If D-DIN is missing and the user wants closer SpaceX typography, run:

```bash
python3 scripts/install_ddin_font.py
```

5. Apply the style with restraint for data-heavy tools: keep black/spectral-white as the base, but allow functional status colors when they improve scanning.
6. Verify with browser screenshots at desktop and narrower widths. Confirm text does not overlap, panels use available viewport height, and refresh/regeneration paths do not overwrite the styling.

## CSS Defaults

Use this font stack:

```css
font-family: "D-DIN", "Liberation Sans Narrow", "Arial Narrow", Arial, Verdana, sans-serif;
```

Use this compact base palette:

```css
:root {
  --space-black: #000;
  --spectral-white: #f0f0fa;
  --ghost-bg: rgba(240, 240, 250, 0.1);
  --ghost-border: rgba(240, 240, 250, 0.35);
}
```

For operational dashboards, status colors are allowed:

```css
:root {
  --status-ok: #35d07f;
  --status-warn: #ffb84d;
  --status-error: #ff5f56;
  --status-relay: #bda2ff;
  --status-info: #67b7ff;
}
```

## Implementation Notes

- Use uppercase labels, actions, table headers, nav, and compact metadata.
- Use positive letter spacing, usually `0.08em` to `0.12em`.
- Prefer ghost buttons with 32px radius; prefer sharp or zero-radius panels.
- Avoid soft shadows, beige/slate/purple gradients, rounded SaaS cards, blobs, and decorative SVGs.
- For data pages, preserve readability over strict imitation: use panels, tables, internal scroll areas, and status colors when needed.
- If a page has a local generator/server, update the generator source and restart the service. Do not only edit generated HTML.

## Resources

- `scripts/install_ddin_font.py`: user-level D-DIN installer for Linux/fontconfig.
- `references/spacex-style.md`: detailed visual rules distilled from `getdesign.md spacex`.
