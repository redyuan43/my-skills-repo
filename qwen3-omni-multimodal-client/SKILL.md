---
name: qwen3-omni-multimodal-client
description: Call the local Qwen3-Omni deployment with text, audio, image, and video inputs, plus text or audio outputs. Use when the user wants ready-to-run CLI commands for the local wrapper server, wants to check readiness first, or wants a quick multimodal inference workflow against this repository's deployment.
---

# Qwen3-Omni Multimodal Client

Use this skill when the local Qwen3-Omni stack is already installed and the user wants to call it through the wrapper API.

## Workflow

1. Resolve the project root.
   Prefer `QWEN_OMNI_PROJECT_ROOT=/path/to/Qwen3-Omni`.
2. Check readiness first.
   Run `scripts/run_qwen3_omni_infer.sh ping`.
3. Call the local CLI client.
   The wrapper command forwards to `.venv/bin/qwen-omni-client`.
4. Save audio outputs when requested.
   Use `--save-audio`.

## Commands

Ping:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh ping
```

Text to text:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt '请用一句话介绍你自己。' \
  --output-modalities text
```

Text to audio:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt '请用一句简短的话介绍你自己，并朗读出来。' \
  --output-modalities audio \
  --save-audio /tmp/qwen3_omni.wav
```

Image to text:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt '请用一句话描述这张图片。' \
  --image var/samples/cherry_blossom.jpg \
  --output-modalities text
```

Audio to text:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt '请转写并简要总结这段音频。' \
  --audio var/samples/mary_had_lamb.ogg \
  --output-modalities text
```

Video to text:

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt '请用一句话描述这个视频。' \
  --video var/samples/sample_demo_1.mp4 \
  --output-modalities text
```

## Known limitation

Mixed `audio+image+video -> text,audio` requests currently return audio reliably. Text may be empty even when the HTTP request succeeds.

## References

- Read `references/examples.md` for a compact command cookbook.
