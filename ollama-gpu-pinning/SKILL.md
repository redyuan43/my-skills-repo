---
name: ollama-gpu-pinning
description: Pin Ollama to a specific NVIDIA GPU on multi-GPU Linux hosts, verify the binding with runtime evidence, and roll back cleanly. Use when the user wants Ollama models to load on a chosen GPU instead of whichever GPU Ollama selects automatically.
---

# Ollama GPU Pinning

Use this skill when Ollama is running on a Linux host with multiple NVIDIA GPUs and the user wants Ollama to use one specific GPU.

## Workflow

1. Discover available GPUs and map user wording like "first GPU" or "second GPU" to an exact GPU UUID.
2. Confirm whether Ollama is running as a systemd service or as a foreground `ollama serve` process.
3. Prefer GPU UUID over numeric index because UUID is stable across reordering.
4. For persistent systemd-based setup, use the bundled script:

```bash
bash ollama-gpu-pinning/scripts/set_ollama_gpu.sh "GPU-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

5. Verify effective configuration:
   - `systemctl show ollama.service --property=Environment`
   - `systemctl cat ollama.service`
   - `nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader`
6. If needed, force one local model inference to prove `ollama runner` lands on the chosen GPU.
7. To roll back, use:

```bash
bash ollama-gpu-pinning/scripts/rollback_ollama_gpu_selection.sh
```

## Notes

- The bundled scripts target `ollama.service` by default.
- The apply script writes only one systemd drop-in file:
  - `/etc/systemd/system/ollama.service.d/10-gpu-selection.conf`
- This avoids editing the main service file and keeps rollback simple.
- If the chosen GPU cannot hold the model, Ollama will no longer borrow the other GPUs because only the selected GPU remains visible to the service.

## Temporary Test Without Persisting

If the user wants a temporary check before changing systemd, run a second Ollama server on another port:

```bash
CUDA_VISIBLE_DEVICES="GPU-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
OLLAMA_HOST="127.0.0.1:11435" \
ollama serve
```

Then query that temporary instance:

```bash
OLLAMA_HOST="127.0.0.1:11435" ollama run qwen3.5:0.8b "reply with test"
```

## Safety Rules

- Do not overwrite unrelated systemd drop-ins.
- Use GPU UUID unless the user explicitly wants index-based selection.
- If the user asks to modify or restart the system service, treat that as a system configuration change and make sure the request is explicit.
- When the Git repo is dirty, add and commit only the new skill files and the intended `README.md` changes.
