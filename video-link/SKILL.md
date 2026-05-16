---
name: video-link
description: "Use when the user provides a YouTube, Bilibili, or other online video link and wants the proven video-analyzer publishing workflow: generate operation_manual.md, run deeper Markdown analysis documents, export PDFs and long PNGs, and produce Baoyu-style image prompts/images from the resulting Markdown files. Triggers include 给你一个链接跑完整流程, 生成 Markdown/PDF/长图/配图, 深度分析视频并导出资产, or requests to repeat the last successful video analysis pipeline."
---

# Video Link

Turn one video URL into a complete publishable artifact set:

- core `operation_manual.md`
- deeper `docs_analysis/knowledge_notes.md` and `docs_analysis/deep_report.md`
- illustrated chapter report `docs_analysis_chapters/deep_report_v2.md` with `deep_report_v2.review.md/json`
- evidence index `manual_evidence.md`
- PDF and long PNG exports for the four publishable Markdown documents
- Baoyu-style image-generation prompts and final generated images

## Workflow

1. Work from `/home/ivan/github/video-analyzer`.
2. Run the bundled orchestrator:

   ```bash
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL"
   ```

   Useful options:

   ```bash
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --run-name operation-manual
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --analysis-mode long-talk-fast
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --analysis-mode deep
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --operation-extra "--cookies-from-browser chrome"
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --skip-operation
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --skip-deep-v2
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL" --skip-images
   ```

3. Keep `--analysis-mode auto` unless the user asks for a specific depth. Auto mode probes duration and routes videos at or above 45 minutes to the long-talk fast path.
4. The script prints a `RUN_DIR=...` line. Treat that directory as the source of truth.
5. Verify the expected artifacts:

   ```bash
   test -f "$RUN_DIR/operation_manual.md"
   test -f "$RUN_DIR/docs_analysis/knowledge_notes.md"
   test -f "$RUN_DIR/docs_analysis/deep_report.md"
   test -f "$RUN_DIR/docs_analysis_chapters/deep_report_v2.md"
   test -f "$RUN_DIR/docs_analysis_chapters/deep_report_v2.review.md"
   test -f "$RUN_DIR/manual_evidence.md"
   find "$RUN_DIR/exports" -maxdepth 1 -type f | sort
   find "$RUN_DIR/baoyu_images/prompts" -maxdepth 1 -type f | sort
   ```

6. Generate images one prompt at a time from `RUN_DIR/baoyu_images/prompts/*.md`.
   Use the matching Baoyu skill concept for each prompt:

   - `operation_manual.md`: `baoyu-image-cards`
   - `knowledge_notes.md`: `baoyu-infographic`
   - `deep_report.md`: `baoyu-infographic`
   - `manual_evidence.md`: `baoyu-infographic` as an evidence map/dashboard

   Use `image_gen` when no Baoyu API backend is configured. Save or copy final images into:

   ```bash
   "$RUN_DIR/baoyu_images/final"
   ```

## Export Policy

Default exports include only publishable documents:

- `operation_manual.md`
- `docs_analysis/knowledge_notes.md`
- `docs_analysis/deep_report.md`
- `docs_analysis_chapters/knowledge_notes_v2.md`
- `docs_analysis_chapters/deep_report_v2.md`
- `docs_analysis_chapters/deep_report_v2.review.md`
- `manual_evidence.md`

Do not export `docs_analysis/operation_manual_review.md` by default. It is a review/appendix artifact, not a user-facing deliverable.
Long PNG exports default to a wide mobile-friendly no-margin layout:
`LONGPNG_VIEWPORT_SIZE=1600,1000`, `LONGPNG_NO_MARGIN=1`, `LONGPNG_CONTENT_PADDING=5`.

## Runtime Policy

- Use the repository's `local_lan` profile unless the user says otherwise.
- Keep local proxy variables out of LAN/Tailscale calls by using the repo script, which sources `tools/operation_manual_no_proxy_env.sh`.
- Do not route through the generic SayAnything Gateway unless explicitly requested.
- Keep DotsMOCR OCR on MagicDNS/stable names; rely on the repo fallback for Tailscale IP resolution.
- For Bilibili/YouTube pages that need browser cookies, pass `--operation-extra "--cookies-from-browser chrome"`.

## Analysis Mode Policy

Use the publisher's `--analysis-mode` switch instead of remembering separate commands.

- `auto`: default. Probe URL duration; if duration is `>=45min`, use `long-talk-fast`, otherwise use `balanced`.
- `long-talk-fast`: for long interviews, podcasts, talks, panels, and lecture-style videos where speech/subtitles carry most of the meaning. It uses `tools/run_long_talk_fast_from_url.sh`, prefers downloaded subtitles as the transcript, includes selected comments, skips audio ASR when subtitles exist, disables VL, samples at `0.5fps`, and uses Jetson Ray frame extraction.
- `balanced`: default for normal videos, event analysis, medium-length videos, or cases where some visual evidence matters but full deep inspection is not necessary.
- `deep`: use only when the user explicitly needs high visual fidelity, UI/state reconstruction, or stronger screenshot-backed evidence. Expect materially slower VL/OCR work.
- `fast`: use for quick drafts on shorter videos when speed is more important than visual completeness.

## Performance And Failure Notes

- Long videos should not default to `1fps`; use the long-talk fast path's `0.5fps` unless the user asks for denser visual scanning.
- If subtitles are available and trustworthy enough for the task, prefer them and skip ASR. Do not rerun ASR just because the pipeline is being resumed.
- If a URL run fails at `Transcribing audio` with `Required ASR transcript was not produced`, classify it as an ASR failure, not OCR. Reuse the existing `RUN_DIR/audio.wav` or output directory audio file to generate `transcript.md` only, then resume from the transcript instead of redownloading the video or rerunning completed stages.
- For ASR-only recovery, call the repo's VibeVoice provider with proxy variables cleared for LAN/Tailscale endpoints and write the result with `video_analyzer.artifacts.write_transcript_markdown()`. VibeVoice cold start can take several minutes; GPU memory used by `vibevoice-asr-backend` is a healthy progress signal.
- If `:8000/v1/models` for DotsMOCR briefly times out, treat it as possible lazy cold start before declaring OCR down. Check `dots-mocr-lazy-proxy.service`, `/proxy/health`, and the `dots-mocr-vllm` container.
- `vl-context-before` / `vl-context-after` can multiply VL cost. Keep them at zero unless nearby frames are essential and close in timestamp.
- Use proxy only for external page/video metadata when needed. LAN/Tailscale model endpoints, Jetson workers, Ray, OCR, VL, and rsync must bypass local proxy variables.
- The AMD Fast model may be theoretically capable of larger context, but the current serving instance can report a smaller actual `n_ctx` such as about 100K. Long subtitles must be compressed before final manual generation unless the serving context is confirmed larger.
- If final manual generation fails after frame/OCR work succeeded, resume from the existing `analysis.json` or run directory. Do not rerun download, ASR, frame extraction, or OCR unless those artifacts are missing or stale.
- The illustrated deep report v2 is generated by `tools/generate_chapter_deep_report.py --deep-v2 --no-final-synthesis --no-format-markdown-final`. It keeps deterministic 17-chapter structure, inserts one chapter frame per chapter, and writes `deep_report_v2.review.md/json`. The review output tells whether the remaining checks are machine-passed or `human_required`.
- The validated long-talk Jetson split is five devices with equal global segments: `nx1,nx2,nx3,nx4,agx`. Do not give AGX two global segments by default. AGX can run multiple NVDEC sessions, but the best internal parallelism is not fixed yet and should be benchmarked before becoming a default.

## Verification

Before reporting success, summarize:

- `RUN_DIR`
- generated Markdown files
- PDF/long PNG export count under `exports`
- Baoyu prompt files under `baoyu_images/prompts`
- final generated image paths if image generation was completed

If any stage fails, report the failing stage and preserve the log path printed by the script.

## References

Read `references/output_contract.md` only when you need exact filenames or retry guidance.
