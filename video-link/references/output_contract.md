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

## Required Final Exports

The final publish stage should create four PDF deliverables:

- `exports/operation_manual.pdf`
- `exports/knowledge_notes_v2.pdf`
- `exports/deep_report_v2.pdf`
- `exports/manual_evidence.pdf`

Long PNG exports are optional. When requested, they should use the wide no-margin defaults:

```bash
tools/run_video_doc_final_publish.sh RUN_DIR --finalize-only --skip-send --long-png
```

## Image Prompt Outputs

`scripts/prepare_baoyu_image_prompts.py RUN_DIR` should create:

- `baoyu_images/prompts/01-image-cards-operation-manual.md`
- `baoyu_images/prompts/02-infographic-knowledge-notes.md`
- `baoyu_images/prompts/03-infographic-deep-report.md`
- `baoyu_images/prompts/04-infographic-manual-evidence.md`

The final publish stage should then create:

- `baoyu_images/final/01-image-cards-operation-manual.png`
- `baoyu_images/final/02-infographic-knowledge-notes.png`
- `baoyu_images/final/03-infographic-deep-report.png`
- `baoyu_images/final/04-infographic-manual-evidence.png`
- `final_publish_summary.json`

## Retry Notes

- If operation manual generation fails before `RUN_DIR` is known, rerun with the same `--run-name`.
- If multi-doc generation fails, rerun the skill script with `--skip-operation --run-dir RUN_DIR`.
- If only exports fail, run `tools/export_video_docs.sh RUN_DIR` directly.
- If image generation or final publish fails, keep prompt files and retry the skill script with `--skip-operation --skip-multidoc --skip-deep-v2 --run-dir RUN_DIR`.
