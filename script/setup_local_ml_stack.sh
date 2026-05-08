#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv-mlx}"

echo "== Apple local ML stack setup =="
echo "root=$ROOT_DIR"
echo

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install -U pip
"$VENV_DIR/bin/python" -m pip install -r requirements-mlx.txt

if command -v brew >/dev/null 2>&1; then
  if ! brew list llama.cpp >/dev/null 2>&1; then
    brew install llama.cpp
  fi
else
  echo "warning: Homebrew nao encontrado; pulando llama.cpp" >&2
fi

if command -v ollama >/dev/null 2>&1; then
  if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    open -gj /Applications/Ollama.app >/dev/null 2>&1 || true
  fi
else
  echo "warning: Ollama nao encontrado; instale o app Ollama para usar script/ollama_smoke.sh" >&2
fi

echo
echo "Setup concluido. Rode: ./script/check_local_ml_stack.sh"
