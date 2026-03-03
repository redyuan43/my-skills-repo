# Examples

Assume the project root is `/home/dgx/github/Qwen3-Omni`.

## Set project root once

```bash
export QWEN_OMNI_PROJECT_ROOT=/home/dgx/github/Qwen3-Omni
```

## Ready check

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh ping
```

## Mixed request with audio output

```bash
skills/qwen3-omni-multimodal-client/scripts/run_qwen3_omni_infer.sh infer \
  --prompt 'Use all inputs and answer briefly, then generate speech.' \
  --audio var/samples/mary_had_lamb.ogg \
  --image var/samples/cherry_blossom.jpg \
  --video var/samples/sample_demo_1.mp4 \
  --output-modalities text,audio \
  --save-audio /tmp/mixed.wav
```

## Troubleshooting

- If `readyz` returns `503`, restart the model server and wait for `/v1/models`.
- If `infer` returns `502`, check whether `127.0.0.1:8091` is ready before blaming the wrapper.
