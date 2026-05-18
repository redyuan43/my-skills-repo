---
name: video-link
description: "Use when the user provides a YouTube, Bilibili, or other online video link and wants the proven video-analyzer publishing workflow: generate operation_manual.md, run deeper Markdown analysis documents, generate Baoyu-style final images, insert them into the docs, and export final PDFs. Triggers include 给你一个链接跑完整流程, 生成 Markdown/PDF/配图, 深度分析视频并导出资产, or requests to repeat the last successful video analysis pipeline."
---

# Video Link

Turn one video URL into a complete publishable artifact set:

- core `operation_manual.md`
- deeper `docs_analysis/knowledge_notes.md` and `docs_analysis/deep_report.md`
- illustrated chapter report `docs_analysis_chapters/deep_report_v2.md` with `deep_report_v2.review.md/json`
- evidence index `manual_evidence.md`
- final image-augmented PDFs for the four publishable Markdown documents
- Baoyu-style image-generation prompts and final generated images

## Workflow

1. Work from `/home/nx/github/video-analyzer` on nx1. The publisher script can also auto-detect the repo or accept `--repo PATH`.
2. Run the bundled orchestrator:

   ```bash
   ~/.codex/skills/video-link/scripts/run_video_link_analysis_publisher.sh "VIDEO_URL"
   ```

3. Do not add options by default. The script already defaults to `--profile deepseek_v4_pro`, `--analysis-mode auto`, and `--run-name operation-manual`.
4. The script prints a `RUN_DIR=...` line. Treat that directory as the source of truth.
5. After core analysis, the script runs multidoc and deep-v2 in parallel, then prepares image prompts and calls `tools/run_video_doc_final_publish.sh RUN_DIR --profile deepseek_v4_pro --finalize-only --skip-send`, which generates final images, augments Markdown, re-exports final PDFs, verifies the PDF count, and writes `final_publish_summary.json`.
6. Verify the expected artifacts:

   ```bash
   test -f "$RUN_DIR/operation_manual.md"
   test -f "$RUN_DIR/docs_analysis/knowledge_notes.md"
   test -f "$RUN_DIR/docs_analysis/deep_report.md"
   test -f "$RUN_DIR/docs_analysis_chapters/deep_report_v2.md"
   test -f "$RUN_DIR/docs_analysis_chapters/deep_report_v2.review.md"
   test -f "$RUN_DIR/manual_evidence.md"
   find "$RUN_DIR/exports" -maxdepth 1 -type f | sort
   find "$RUN_DIR/baoyu_images/prompts" -maxdepth 1 -type f | sort
   find "$RUN_DIR/baoyu_images/final" -maxdepth 1 -type f | sort
   test -f "$RUN_DIR/final_publish_summary.json"
   ```

## Export Policy

Default final exports include only publishable documents:

- `operation_manual.md`
- `docs_analysis_chapters/knowledge_notes_v2.md`
- `docs_analysis_chapters/deep_report_v2.md`
- `manual_evidence.md`

Do not export `docs_analysis/operation_manual_review.md` by default. It is a review/appendix artifact, not a user-facing deliverable.
Preliminary PDF export is skipped by default when final image publishing will run, because final publish re-exports the image-augmented PDFs. Do not request preliminary PDFs unless the user explicitly asks for an intermediate PDF before images.

Long PNG exports are optional. Request them with `--final-publish-long-png` only when the user explicitly asks for long images. The long PNG layout defaults are:
`LONGPNG_VIEWPORT_SIZE=1600,1000`, `LONGPNG_NO_MARGIN=1`, `LONGPNG_CONTENT_PADDING=5`.

## Runtime Policy

- Use the repository's `deepseek_v4_pro` profile unless the user says otherwise.
- Text generation and review use DeepSeek Pro through `DEEPSEEK_API_KEY`; vision frame analysis still uses the configured local vision model such as MiniCPM.
- Load DeepSeek credentials from `~/.config/video-analyzer/deepseek.env` when present. Never print the token or commit it to a repository.
- Keep local proxy variables out of LAN/Tailscale calls by using the repo script, which sources `tools/operation_manual_no_proxy_env.sh`.
- Do not route through the generic SayAnything Gateway unless explicitly requested.
- Keep DotsMOCR OCR on MagicDNS/stable names; rely on the repo fallback for Tailscale IP resolution.
- For Bilibili/YouTube pages that need browser cookies, pass `--operation-extra "--cookies-from-browser chrome"`.

## Analysis Mode Policy

Keep `--analysis-mode auto` unless the user explicitly asks for a different mode.

- `auto`: default. Probe URL duration; if duration is `>=45min`, use `long-talk-fast`, otherwise use `balanced`.
- `long-talk-fast`: use only when the user explicitly says to force long-video mode. It uses `tools/run_long_talk_fast_from_url.sh`, prefers downloaded subtitles as the transcript, includes selected comments, skips audio ASR when subtitles exist, disables VL, samples at `0.5fps`, and uses Jetson Ray frame extraction.
- `balanced`: default for normal videos, event analysis, medium-length videos, or cases where some visual evidence matters but full deep inspection is not necessary.
- `deep`: use only when the user explicitly asks for deep video parsing, high visual fidelity, UI/state reconstruction, or stronger screenshot-backed evidence. A deep report is already generated by default as `deep_report_v2.pdf`.
- `fast`: use for quick drafts on shorter videos when speed is more important than visual completeness.

## Advanced Recovery Options

Do not use these options in the default path.

- `--run-dir PATH`: only for resuming an existing run directory.
- `--skip-operation`: only with `--run-dir` when core URL analysis already succeeded.
- `--skip-multidoc`: only when multidoc outputs already exist or the user explicitly does not need them.
- `--skip-deep-v2`: only when chapter deep report outputs already exist or the user explicitly does not need them.
- `--skip-images`: only when the user explicitly does not want final images or final image-augmented PDFs.
- `--skip-final-publish`: only when the user wants prompts but not final images/PDFs.
- `--skip-export`: only when a preliminary export would otherwise run and should be suppressed.
- `--pre-export`: only when the user explicitly wants an intermediate PDF before images.
- `--operation-extra "--cookies-from-browser chrome"`: only when the site requires browser cookies.

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
- If image generation fails, keep the prompt files and rerun with `--skip-operation --skip-multidoc --skip-deep-v2 --run-dir RUN_DIR`. Add `--skip-export` if preliminary exports are not needed.
- If Mermaid or PDF layout fails, fix or rerun the repository PDF converter path: `tools/export_video_docs.sh RUN_DIR --final-only`. Mermaid content is prompted in `video_analyzer/manual.py`, but PDF rendering and mobile layout are owned by `tools/md_to_mobile_pdf.py`.

## Verification

Before reporting success, summarize:

- `RUN_DIR`
- generated Markdown files
- PDF export count under `exports`
- Baoyu prompt files under `baoyu_images/prompts`
- final generated image paths under `baoyu_images/final`
- `final_publish_summary.json`

If any stage fails, report the failing stage and preserve the log path printed by the script.

## References

Read `references/output_contract.md` only when you need exact filenames or retry guidance.
