# Local ML Stack Verification

Data da verificacao inicial: `2026-05-07`
Atualizacao operacional: `2026-05-08`

## Apple baseline

- `Xcode 26.4.1`
- `Swift 6.3.1`
- SDK ativo: `macOS 26.4`
- `xed` presente em `/Applications/Xcode.app/Contents/Developer/usr/bin/xed`

## Create ML

Verificado localmente no bundle do Xcode:

- path: `/Applications/Xcode.app/Contents/Applications/Create ML.app`
- bundle id: `com.apple.CreateML`
- versao curta: `6.2`
- build: `178.2`
- minimo do sistema: `26.2`
- extensao de projeto suportada: `.mlproj`

Conclusao:

- `Create ML` esta disponivel nesta maquina.
- Ele nao apareceu como app separado em `/Applications`, porque fica embutido em `Xcode.app`.

## Frameworks Apple no SDK

Presentes no SDK `MacOSX26.4.sdk`:

- `CoreML.framework`
- `Vision.framework`
- `NaturalLanguage.framework`
- `SoundAnalysis.framework`

Conclusao:

- O runtime Apple-first necessario para fase 2 esta disponivel no SDK local.

## MLX

Estado antigo encontrado e removido:

- havia um `mlx-whisper` instalado por `pipx`
- path antigo: `/Users/gustavomendesesilva/.local/bin/mlx_whisper`
- venv antiga: `/Users/gustavomendesesilva/.local/pipx/venvs/mlx-whisper`
- esse caminho estava quebrado e foi removido

Estado atual instalado:

- ambiente limpo: `/Users/healthOS/ML/.venv-mlx`
- `mlx 0.31.2`
- `mlx-metal 0.31.2`
- `mlx-lm 0.31.3`
- `huggingface_hub 1.14.0`
- `transformers 5.8.0`
- `coremltools 9.0`

Verificacao funcional:

- `mx.default_device()` retornou `Device(gpu, 0)`
- `mx.metal.is_available()` retornou `True`
- operacao `x * 2` com `mx.eval(...)` executou corretamente e retornou `[2.0, 4.0, 6.0]`

Conclusao:

- `MLX` agora esta instalado corretamente e funcional nesta maquina.
- `MLX-LM` esta instalado e o CLI `mlx_lm.generate` esta disponivel.
- o problema anterior era da instalacao velha via `mlx-whisper`, nao do `MLX` atual.
- smoke test pronto em `script/mlx_smoke.py`
- geracao por MLX-LM pronta em `script/mlx_lm_generate.py`

## llama.cpp e Ollama

Estado instalado em `2026-05-08`:

- `llama.cpp 9070` instalado via Homebrew
- `llama-cli` inicializa backend Metal no Apple M1
- `Ollama 0.23.2` disponivel em `/Applications/Ollama.app`
- modelos Ollama locais detectados:
  - `gemma4:latest`
  - `gpt-oss:20b`

Conclusao:

- ha dois caminhos locais GGUF/Ollama disponiveis alem de MLX-LM.
- o download automatico de `qwen2.5:0.5b` foi interrompido porque a rede ficou instavel e estimou horas; o script `script/ollama_smoke.sh` suporta esse download com `OLLAMA_PULL_IF_MISSING=1`.

## Foundation Models

Verificacao local do runtime:

- framework presente no SDK: `FoundationModels.framework`
- `SystemLanguageModel.default.availability` retornou `available`
- `supportsLocale(en_US)` retornou `true`
- `supportsLocale(pt_BR)` retornou `true`

Verificacao de geracao real:

- `LanguageModelSession()` inicializou corretamente
- um smoke test real gerou resposta on-device
- script usado: `script/foundationmodels_smoke.swift`

Conclusao:

- Foundation Models esta funcional localmente nesta maquina.
- o caminho validado aqui e on-device.
- o smoke test compila com `xcrun swiftc`, porque `swiftc` direto neste shell nao selecionou o SDK macOS corretamente.

## Foundation Models e nuvem Apple

Conclusao pratica:

- a API de app que voce usa via `FoundationModels` e on-device
- `Private Cloud Compute` faz parte do Apple Intelligence em nivel de sistema
- nesta verificacao nao apareceu uma API publica equivalente para o desenvolvedor escolher ou invocar diretamente um modelo remoto Apple via `FoundationModels`
- entao, para produto/app, trate `FoundationModels` como runtime local e `Private Cloud Compute` como comportamento interno do ecossistema Apple Intelligence, nao como backend app-configurable

## Simulador

Estado observado nesta sessao shell:

- `CoreSimulatorService` nao respondeu ao `simctl`

Conclusao:

- A stack de build local esta funcional.
- A verificacao de execucao em simulador iOS continua pendente de um shell/sessao com `CoreSimulatorService` operacional.
