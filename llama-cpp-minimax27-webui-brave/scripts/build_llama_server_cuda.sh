#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$HOME/github/llama.cpp}"

cd "$REPO_ROOT"
cmake -S "." -B "build" -DGGML_CUDA=ON -DLLAMA_CURL=ON
cmake --build "build" --config Release -j --target llama-server
