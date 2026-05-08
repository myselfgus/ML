#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Apple ML / AI Audit Trail =="
echo

echo "-- Foundation Models compile + run"
env HOME="$ROOT_DIR" CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache" \
xcrun swiftc -parse-as-library script/foundationmodels_smoke.swift -o .build/foundationmodels_smoke
./.build/foundationmodels_smoke
echo

echo "-- MLX smoke"
.venv-mlx/bin/python script/mlx_smoke.py
echo

echo "-- MLX-LM CLI"
.venv-mlx/bin/mlx_lm.generate --help >/dev/null
echo "mlx_lm.generate=available"
echo

echo "-- Ollama local smoke"
if command -v ollama >/dev/null 2>&1; then
  ollama list || true
  if [[ "${RUN_OLLAMA_GENERATION:-0}" == "1" ]]; then
    ./script/ollama_smoke.sh || true
  else
    echo "ollama_generation=skipped (set RUN_OLLAMA_GENERATION=1 to run)"
  fi
else
  echo "ollama=missing"
fi
echo

echo "-- Remaining manual Apple Intelligence / PCC steps"
cat <<'EOF'
1. Open Shortcuts on macOS.
2. Create one shortcut with "Use Model".
3. Run the same prompt with:
   - On-Device
   - Private Cloud Compute
4. Export:
   System Settings -> Privacy & Security -> Apple Intelligence Report
5. Inspect Apple_Intelligence_Report.json.
EOF
