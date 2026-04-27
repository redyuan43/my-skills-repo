# SpaceX-Inspired Frontend Reference

Source inspiration:
- `npx getdesign@latest add spacex`
- https://getdesign.md/spacex/design-md
- https://github.com/VoltAgent/awesome-design-md/tree/main/design-md/spacex

## Core Mood

SpaceX style is cinematic aerospace minimalism: black void, spectral near-white typography, uppercase labels, positive tracking, and almost no ornament. The interface should feel like mission-control instrumentation rather than a soft SaaS dashboard.

## Palette

- Space black: `#000000`
- Spectral white: `#f0f0fa`
- Ghost surface: `rgba(240, 240, 250, 0.1)`
- Ghost border: `rgba(240, 240, 250, 0.35)`
- Dark overlay: `rgba(0, 0, 0, 0.5)`

For tools and dashboards, add a small status palette only when needed:

- OK: `#35d07f`
- Warning: `#ffb84d`
- Error: `#ff5f56`
- Relay/route/secondary: `#bda2ff`
- Info: `#67b7ff`

## Typography

- Use `D-DIN` when installed.
- Fallback: `"Liberation Sans Narrow", "Arial Narrow", Arial, Verdana, sans-serif`.
- Use uppercase for headings, labels, actions, table headers, nav, and chips.
- Use positive letter spacing:
  - Display: around `0.08em`
  - Labels/actions: `0.08em` to `0.12em`
  - Micro labels: up to `0.18em`
- Preserve monospace fonts for IPs, shell commands, hashes, ports, and logs.

## Layout

- Prefer edge-to-edge sections and strong alignment.
- Use full-viewport or viewport-aware sections when appropriate.
- Avoid nested cards. Use thin spectral borders for necessary panels.
- For operational pages, one side can be sticky and viewport-height while tables scroll internally.
- At medium widths, stack instead of squeezing columns.

## Components

### Buttons

Use ghost buttons by default:

```css
button {
  background: rgba(240, 240, 250, 0.1);
  border: 1px solid rgba(240, 240, 250, 0.35);
  border-radius: 32px;
  color: #f0f0fa;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
```

### Tables

- Black background, thin borders, sticky headers.
- Uppercase table headers.
- Monospace values for technical identifiers.
- Use internal scroll containers that fill the available viewport height.

### Status Chips

- Chips may use color for status scanning.
- Keep chip typography uppercase, compact, and tracked.
- Avoid using color as decoration; each color must map to a meaning.

## Do Not

- Do not use soft shadows, large rounded cards, beige/slate/purple-blue themes, bokeh, blobs, or generic gradients.
- Do not force all text into uppercase when it harms reading of long Chinese copy.
- Do not edit only generated HTML when a generator script will overwrite it.
- Do not install fonts globally unless the user explicitly approves system-level changes.
