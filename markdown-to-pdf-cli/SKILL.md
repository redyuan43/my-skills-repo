---
name: markdown-to-pdf-cli
description: Convert local Markdown files to PDF from the command line, especially on Linux/AMD hosts with local images, Chrome/Puppeteer, and npx md-to-pdf path issues.
---

# Markdown To PDF CLI

Use this skill when the user asks to convert a Markdown file into PDF, especially on a remote Linux host such as AMD.

## Preferred Workflow

Use the bundled wrapper first:

```bash
scripts/md_to_pdf.sh /path/to/input.md /path/to/output.pdf
```

The wrapper defaults to zero left/right page margin and a 5px left/right content
padding so exported PDFs avoid wide gutters while keeping text off the edge.
Override only when a specific document needs wider gutters:

```bash
PDF_SIDE_MARGIN=0.25in PDF_CONTENT_PADDING=16px scripts/md_to_pdf.sh input.md output.pdf
```

The wrapper supports fenced Mermaid diagrams such as:

````markdown
```mermaid
graph TD
  A --> B
```
````

It renders each Mermaid block to a temporary local SVG before generating the
PDF, so the PDF does not depend on CDN-loaded Mermaid JavaScript.

If the skill is installed only as knowledge and the script is not copied into the target machine, run the same command shape manually:

```bash
cd "$(dirname "/path/to/input.md")"
PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome \
  npx --yes md-to-pdf "$(basename "/path/to/input.md")"
```

Then move or copy the generated PDF to the requested destination.

## Rules

- Run from the Markdown file's own directory so relative image paths such as `manual_assets/frame_009.jpg` resolve correctly.
- Prefer system Chrome on AMD. Known path: `/usr/bin/google-chrome`.
- If Chrome detection fails, check `google-chrome`, `google-chrome-stable`, `chromium`, then `chromium-browser`.
- `md-to-pdf` writes the output next to the Markdown by default. The wrapper handles renaming to the requested output path.
- Mermaid diagrams are rendered through `npx --yes @mermaid-js/mermaid-cli` and system Chrome into temporary SVG files.
- Do not use this PDF path when the user wants one continuous long PNG; use the `markdown-to-longpng` skill instead.

## Verification

After conversion:

```bash
file /path/to/output.pdf
ls -lh /path/to/output.pdf
```

Output gate:

- PDF must be non-empty.
- `file` should identify it as PDF.
- If `pdfinfo` is available, `Pages` must be at least 1.
- Full rules live in `references/output_gate.md`.

Safe local smoke:

```bash
bash markdown-to-pdf-cli/scripts/selftest.sh --safe
```

For remote hosts, copy the result back with:

```bash
scp AMD:/path/to/output.pdf "$HOME/Desktop/"
```
