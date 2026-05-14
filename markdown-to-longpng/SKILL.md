---
name: markdown-to-longpng
description: Convert local Markdown files into one continuous long PNG by rendering Markdown to HTML and taking a full-page Chrome screenshot, preserving relative local images and avoiding PDF page gaps.
---

# Markdown To Long PNG

Use this skill when the user asks to convert Markdown into a single long PNG, especially when PDF-to-PNG creates page gaps or multiple sliced images.

## Preferred Workflow

Use the bundled wrapper:

```bash
scripts/md_to_longpng.sh /path/to/input.md /path/to/output.png
```

The wrapper supports fenced Mermaid diagrams such as:

````markdown
```mermaid
graph TD
  A --> B
```
````

It renders each Mermaid block to a temporary local SVG before rendering the
Markdown to HTML and taking the full-page screenshot.

On AMD, an equivalent proven command is also installed as:

```bash
md-to-longpng /path/to/input.md /path/to/output.png
```

## How It Works

The wrapper:

1. Pre-renders fenced Mermaid blocks to temporary local SVG files.
2. Uses `npx --yes mume-cli html` to render Markdown into HTML.
3. Injects `<base href="file://原Markdown目录/">` into the generated HTML so local relative images load correctly.
4. Uses `npx --yes playwright screenshot --channel chrome --full-page --viewport-size=1280,900` to capture one continuous PNG.

## Rules

- Use this instead of PDF plus `pdftoppm` when the user wants a long image.
- Keep the Markdown's relative assets in place; paths like `manual_assets/...` are resolved from the Markdown directory.
- If images are missing in the PNG, verify the generated HTML has a `<base href="file://.../">` tag and that the referenced image files exist.
- Mermaid diagrams are rendered through `npx --yes @mermaid-js/mermaid-cli` and system Chrome into temporary SVG files.
- On AMD, Chrome is available as `/usr/bin/google-chrome`; Playwright can use it via `--channel chrome`.
- AMD's `node`/`npx` may live in `~/.local/bin`; the wrapper prepends that path automatically.

## Verification

After conversion:

```bash
file /path/to/output.png
identify /path/to/output.png 2>/dev/null || true
```

Previously verified on AMD:

- Input: `/home/ivan/github/video-analyzer/downloads/url-videos/BV1EGdrBQEVN/operation-manual/operation_manual.md`
- Output: single PNG, `1280 x 8143`, with relative images visible.

For remote hosts, copy the result back with:

```bash
scp AMD:/path/to/output.png "$HOME/Desktop/"
```
