#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Hardware =="
system_profiler SPHardwareDataType | sed -n '1,40p'
echo

echo "== macOS / Xcode / Swift / Python =="
sw_vers
xcodebuild -version
swift --version
python3 --version
echo

echo "== Apple frameworks in active SDK =="
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
for framework in FoundationModels CoreML CreateML Vision NaturalLanguage SoundAnalysis ImagePlayground AppIntents; do
  if [[ -d "$SDK_PATH/System/Library/Frameworks/$framework.framework" ]]; then
    echo "present: $framework"
  else
    echo "missing: $framework"
  fi
done
echo

echo "== Create ML app =="
CREATE_ML="/Applications/Xcode.app/Contents/Applications/Create ML.app"
if [[ -d "$CREATE_ML" ]]; then
  defaults read "$CREATE_ML/Contents/Info.plist" CFBundleShortVersionString
else
  echo "missing"
fi
echo

echo "== Python ML packages =="
.venv-mlx/bin/python - <<'PY'
import importlib.metadata as md
for name in ["mlx", "mlx-metal", "mlx-lm", "transformers", "huggingface_hub", "coremltools"]:
    try:
        print(f"{name}={md.version(name)}")
    except md.PackageNotFoundError:
        print(f"{name}=missing")
PY
echo

echo "== MLX smoke =="
.venv-mlx/bin/python script/mlx_smoke.py
echo

echo "== MLX-LM CLI =="
.venv-mlx/bin/mlx_lm.generate --help >/dev/null
echo "mlx_lm.generate=available"
echo

echo "== llama.cpp =="
if command -v llama-cli >/dev/null 2>&1; then
  llama-cli --version
else
  echo "llama-cli=missing"
fi
echo

echo "== Ollama =="
if command -v ollama >/dev/null 2>&1; then
  ollama --version || true
  curl -fsS http://127.0.0.1:11434/api/tags || true
else
  echo "ollama=missing"
fi
