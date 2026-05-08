#!/usr/bin/env bash
set -euo pipefail

MODEL="${OLLAMA_MODEL:-}"
PROMPT="${1:-Responda exatamente: OLLAMA_OK}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama nao encontrado" >&2
  exit 1
fi

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  open -gj /Applications/Ollama.app >/dev/null 2>&1 || true
  for _ in {1..20}; do
    curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
    sleep 1
  done
fi

if [[ -z "$MODEL" ]]; then
  MODEL="$(ollama list | awk 'NR == 2 {print $1}')"
fi

if [[ -z "$MODEL" ]]; then
  MODEL="qwen2.5:0.5b"
fi

if ! ollama list | awk '{print $1}' | grep -qx "$MODEL"; then
  if [[ "${OLLAMA_PULL_IF_MISSING:-0}" == "1" ]]; then
    ollama pull "$MODEL"
  else
    echo "modelo Ollama ausente: $MODEL" >&2
    echo "rode: OLLAMA_PULL_IF_MISSING=1 OLLAMA_MODEL=$MODEL $0" >&2
    exit 1
  fi
fi

ollama run "$MODEL" "$PROMPT"
