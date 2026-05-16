# Output Contract

## Required Markdown Outputs

- `operation_manual.md`: primary generated operation/analysis manual.
- `docs_analysis/knowledge_notes.md`: method and knowledge framework notes.
- `docs_analysis/deep_report.md`: deeper event or topic analysis.
- `docs_analysis_chapters/knowledge_notes_v2.md`: chapter-by-chapter expanded notes.
- `docs_analysis_chapters/deep_report_v2.md`: illustrated chapter deep report.
- `docs_analysis_chapters/deep_report_v2.review.md`: automatic structure/evidence review.
- `docs_analysis_chapters/deep_report_v2.review.json`: machine-readable review result.
- `manual_evidence.md`: frame/OCR/VL/transcript evidence index.

`docs_analysis/operation_manual_review.md` may exist, but it is not exported by default.

## Required Exports

`tools/export_video_docs.sh RUN_DIR` should create:

- `exports/operation_manual.pdf`
- `exports/operation_manual.long.png`
- `exports/knowledge_notes.pdf`
- `exports/knowledge_notes.long.png`
- `exports/deep_report.pdf`
- `exports/deep_report.long.png`
- `exports/knowledge_notes_v2.pdf`
- `exports/knowledge_notes_v2.long.png`
- `exports/deep_report_v2.pdf`
- `exports/deep_report_v2.long.png`
- `exports/deep_report_v2.review.pdf`
- `exports/deep_report_v2.review.long.png`
- `exports/manual_evidence.pdf`
- `exports/manual_evidence.long.png`

Long PNG exports should use the wide no-margin defaults unless the user asks otherwise:

```bash
LONGPNG_VIEWPORT_SIZE=1600,1000 LONGPNG_NO_MARGIN=1 LONGPNG_CONTENT_PADDING=16 tools/export_video_docs.sh RUN_DIR
```

## Image Prompt Outputs

`scripts/prepare_baoyu_image_prompts.py RUN_DIR` should create:

- `baoyu_images/prompts/01-image-cards-operation-manual.md`
- `baoyu_images/prompts/02-infographic-knowledge-notes.md`
- `baoyu_images/prompts/03-infographic-deep-report.md`
- `baoyu_images/prompts/04-infographic-manual-evidence.md`

## Retry Notes

- If operation manual generation fails before `RUN_DIR` is known, rerun with the same `--run-name`.
- If multi-doc generation fails, rerun the skill script with `--skip-operation --run-dir RUN_DIR`.
- If only exports fail, run `tools/export_video_docs.sh RUN_DIR` directly.
- If image generation fails, keep prompt files and retry one prompt at a time.
