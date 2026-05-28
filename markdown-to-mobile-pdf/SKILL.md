---
name: markdown-to-mobile-pdf
description: Convert local Markdown files into narrow mobile-readable PDF documents using the proven WeasyPrint renderer from video-analyzer. Use when the user asks for Markdown to mobile PDF, phone-friendly PDF, mobile-first article export, narrow PDF pages, Chinese Markdown PDF output, or PDF export that preserves local relative images and handles Mermaid diagrams.
---

# Markdown To Mobile PDF

## Overview

Use this skill to turn one Markdown file into a phone-friendly PDF. It uses a 96mm x 170mm page size, Chinese-capable font stack, relative-image support, syntax highlighting, and Mermaid handling.

## Preferred Workflow

Run the bundled wrapper:

```bash
scripts/md_to_mobile_pdf.sh /path/to/input.md /path/to/output.pdf "Optional title"
```

If no output path is provided, the wrapper writes:

```bash
/path/to/input.mobile.pdf
```

The direct Python entry is also available:

```bash
/path/to/.venv/bin/python scripts/md_to_mobile_pdf.py /path/to/input.md /path/to/output.pdf --title "Title"
```

## Rules

- Use this path when the user wants a PDF optimized for phone reading, not desktop print layout.
- Keep Markdown assets next to the source file; relative image paths are resolved from the Markdown directory.
- Mermaid `flowchart TD` blocks that are simple linear flows render as native mobile HTML flowcharts.
- Other Mermaid blocks use `npx --yes @mermaid-js/mermaid-cli`; make sure `npx` and Chrome/Chromium are available if those diagrams exist.
- Do not use this when the user asks for one continuous image; use `markdown-to-longpng` instead.

## Dependencies

The Python renderer requires:

```bash
python3 -c "import markdown, pygments, weasyprint"
```

The shell wrapper prefers `PYTHON`, then `VIDEO_ANALYZER_ROOT/.venv/bin/python`, then `/home/ivan/github/video-analyzer/.venv/bin/python`, then the current directory's `.venv`, then system `python3`. If imports fail, install dependencies into the active project environment rather than globally when possible.

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
bash markdown-to-mobile-pdf/scripts/selftest.sh --safe
```
