# Apple ML Starter

Starter Apple-first para ML local em producao sem Python: `Xcode + Swift + Core ML + frameworks nativos`.

## Baseline validado

- `Xcode 26.4.1`
- `Apple Swift 6.3.1`
- `xcode-select -> /Applications/Xcode.app/Contents/Developer`
- SDKs presentes: `macOS 26.4`, `iOS 26.4`, `iOS Simulator 26.4`
- `Create ML 6.2` em `/Applications/Xcode.app/Contents/Applications/Create ML.app`

## O que foi criado

- `Package.swift`
  Abre direto no Xcode como Swift Package.
- `OpenInXcode.command`
  Launcher explicito para abrir o starter no Xcode via `xed`.
- `AppleMLStarterApp`
  App macOS em SwiftUI para exercitar inferencia local e medir latencia.
- `MLFeaturePipeline`
  Camada de preprocessamento e feature extraction.
- `MLInferenceCore`
  Contrato de inferencia, versionamento do modelo, telemetria e fallback local.
- `script/build_and_run.sh`
  Build + bundle + launch local.
- `.codex/environments/environment.toml` ficou como passo opcional
  porque a criacao de pasta oculta foi bloqueada pelo sandbox desta sessao.

## Arquitetura

Separacao de camadas:

1. `MLFeaturePipeline`
   - `PredictionInput`
   - `TextFeatures`
   - `DefaultTextFeatureExtractor`
2. `MLInferenceCore`
   - `Predicting`
   - `AppleLocalInferenceEngine`
   - `PredictionResult`
   - `InferenceMetrics`
   - `ModelDescriptor`
3. `AppleMLStarterApp`
   - UI e fluxo de app
   - sem logica de modelo acoplada

Contrato principal:

```swift
func predict(input: PredictionInput) throws -> PredictionResult
```

## Como abrir

1. No Finder ou Xcode, abra `/Users/healthOS/ML/Package.swift`.
2. Aguarde o Xcode resolver o package.
3. Rode o target `AppleMLStarterApp`.

Opcao explicita de launcher:

1. Execute `/Users/healthOS/ML/OpenInXcode.command`.
2. Se preferir por terminal, rode `xed /Users/healthOS/ML/Package.swift`.

Tambem funciona por shell:

```bash
swift build
./script/build_and_run.sh
```

## Como plugar um modelo Create ML

Fluxo sugerido:

1. Treine um modelo pequeno no Create ML.
2. Exporte como `.mlmodel`.
3. Coloque o arquivo em:
   `Sources/MLInferenceCore/Resources/Models/<NomeDoModelo>.mlmodel`
4. Ajuste `ModelDescriptor.starter` em `MLInferenceCore` se quiser mudar nome/versao.
5. Troque o adapter fallback por um adapter tipado do modelo exportado.

Observacao importante:

- O starter detecta a presenca de asset de modelo no bundle.
- A inferencia atual usa um fallback heuristico pequeno para o projeto compilar e abrir agora, mesmo sem um `.mlmodel` real.
- Quando o modelo Create ML existir, o proximo passo e adicionar um adapter tipado do schema exportado.

## Frameworks Apple previstos neste starter

- `CoreML`
- `NaturalLanguage`
- `Vision`
- `SoundAnalysis`

No codigo atual:

- `CoreML` e `NaturalLanguage` ja entram no pipeline base.
- `Vision` e `SoundAnalysis` ficam prontos para targets futuros sem contaminar a UI atual.

## Verificacao local da stack

Resumo desta sessao:

- `Create ML` foi confirmado no bundle do Xcode
- `CoreML`, `Vision`, `NaturalLanguage` e `SoundAnalysis` estao presentes no SDK
- a instalacao antiga quebrada de `mlx-whisper` foi removida
- `MLX 0.31.2` e `mlx-metal 0.31.2` foram instalados em `.venv-mlx`
- `MLX` foi validado com `Device(gpu, 0)` e operacao real em GPU
- `Foundation Models` foi validado com `availability=available` e geracao real via `LanguageModelSession`
- o caminho confiavel para abrir no Xcode ficou sendo `xed Package.swift` via `OpenInXcode.command`

Detalhes completos:

- `docs/LOCAL-ML-STACK-VERIFICATION.md`

## Testes e validacao

Ja coberto:

- build do package
- metadado de latencia
- erro para input vazio

Pendente de ambiente local:

- `swift test` ficou bloqueado pelo sandbox deste shell, nao por erro de compilacao do projeto
- `CoreSimulatorService` estava indisponivel no shell atual, entao a validacao em simulador iOS nao ficou concluida aqui

## Proximos passos reais

1. Criar um `.mlproj` no `Create ML 6.2` com dataset pequeno de teste.
2. Exportar um modelo pequeno de texto ou classificacao tabular.
3. Substituir o fallback por um adapter Core ML tipado.
4. Se quiser trilha `MLX`, usar `.venv-mlx` e `script/mlx_smoke.py` como baseline local.
5. Rodar profiling com Instruments e coletar media/p95.

# ML
