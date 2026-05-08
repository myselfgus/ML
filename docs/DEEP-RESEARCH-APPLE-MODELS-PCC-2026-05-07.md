# Deep Research: Apple Models and Private Cloud Compute

Date: `2026-05-07`

## Executive conclusion

There are two distinct Apple model access paths that matter here:

1. `FoundationModels` framework for apps
   - Public developer API
   - On-device system language model
   - Verified locally on this machine

2. `Private Cloud Compute` in Apple Intelligence
   - Real Apple cloud inference path
   - Verified by Apple official docs as part of Apple Intelligence and Shortcuts
   - Not verified as a public app-embedded API equivalent to `FoundationModels`

The important nuance is:

- Apple absolutely does expose a user-facing path that can use `Private Cloud Compute` directly in Shortcuts.
- Apple does not, based on the public developer docs reviewed on `2026-05-07`, expose the same direct PCC selection path inside the `FoundationModels` app framework API.

So the correct product model today is:

- `FoundationModels` for app-native on-device inference
- `Shortcuts` for user automation that can explicitly choose `On-Device` or `Private Cloud Compute`
- `PCC` is a system capability of Apple Intelligence, not an app-selectable backend in the public `FoundationModels` API

## What was verified locally

Machine:

- macOS `26.3.1`
- Apple Silicon `M1`
- Xcode `26.4.1`

Foundation Models runtime:

- `FoundationModels.framework` exists in local SDK
- `SystemLanguageModel.default.availability == available`
- `SystemLanguageModel.default.contextSize == 4096`
- `SystemLanguageModel.default.supportedLanguages.count == 23`
- `supportsLocale(en_US) == true`
- `supportsLocale(pt_BR) == true`

Real generation test:

- `LanguageModelSession()` initialized successfully
- prompt executed successfully
- model generated a real response on this machine

MLX runtime:

- old broken `mlx-whisper` install removed
- fresh local environment created at `.venv-mlx`
- `mlx 0.31.2`
- `mlx-metal 0.31.2`
- verified with `Device(gpu, 0)` and simple tensor execution

## Foundation Models: what the public API is

Apple’s public developer documentation describes `FoundationModels` as access to the on-device language model behind Apple Intelligence.

Core properties of the public API:

- on-device language model
- text generation and understanding
- structured generation via `@Generable`
- tool calling via `Tool`
- session model via `LanguageModelSession`
- guardrails and safety controls
- adapter support for specialization

From the docs reviewed on `2026-05-07`, the framework language stays consistently on-device.

## What Foundation Models is good for

The public API is designed for:

- summarization
- extraction
- rewriting
- dialog and text generation
- structured output
- tool-calling grounded in app data
- multilingual usage
- local-first product features

This aligns with your Apple-first architecture goal.

## Important constraints of Foundation Models

### 1. It is on-device

The public framework is presented as on-device.

### 2. Availability is conditional

Apps need to handle:

- Apple Intelligence disabled
- model not ready
- device not eligible
- unsupported locale/language

### 3. Context is finite

Local runtime inspection on this machine returned `contextSize = 4096`.

### 4. Safety and policy constraints exist

Apple has explicit acceptable-use restrictions for the framework.

### 5. Adapters are version-coupled

Custom adapters are tied to a specific system model version.
When Apple updates the system model, adapters need retraining.

## Adapters: what changed the most in the current docs

As of `2026-05-07`, adapter training is much more concrete than the first beta wave:

- official adapter training toolkit exists
- current toolkit version listed is `26.0.0`
- toolkit versions track system model versions
- each adapter is compatible with a single specific system model version
- deployment requires the `com.apple.developer.foundation-model-adapter` entitlement
- adapters should not be bundled directly in the app binary
- Apple recommends Background Assets / asset packs

Operationally this matters a lot:

- adapters are viable, but expensive to maintain
- adapters are not “train once and forget”
- tool calling should usually be tried before adapter training

## Private Cloud Compute: what it is

Private Cloud Compute is Apple’s cloud inference path for Apple Intelligence when on-device processing is insufficient.

Apple’s own description is consistent across support and security materials:

- on-device is the default path
- more complex requests may go to PCC
- PCC runs on Apple silicon servers
- request data is processed ephemerally
- Apple says data is not stored
- the system uses attestation and public transparency for verifiability

## PCC security model

From Apple Security Research, the PCC design goals include:

- stateless computation on personal user data
- enforceable guarantees
- no privileged runtime access
- non-targetability
- verifiable transparency

That is a stronger and more inspectable claim set than a normal cloud AI service.

## The critical distinction: PCC exists, but not as a public app backend selector

This is the core conclusion.

Based on the public sources reviewed on `2026-05-07`:

- Apple Support explicitly says Shortcuts can choose between:
  - `On-Device`
  - `Private Cloud Compute`
  - `Extension Model` (ChatGPT)
- Apple Developer documentation for `FoundationModels` still describes the framework as access to the on-device model
- no public developer documentation reviewed here shows a `FoundationModels` API that lets an app explicitly pick `Private Cloud Compute` as a model backend

So your iPhone observation is consistent with the official docs:

- yes, Apple models can be used through PCC directly in Shortcuts
- that does not imply a parallel public SDK surface for arbitrary apps through `FoundationModels`

## Product implication

If your goal is a native app:

- treat `FoundationModels` as the public local inference API
- treat `PCC` as a system-managed Apple Intelligence capability outside the current public app SDK boundary

If your goal is automation or user workflows:

- Shortcuts is currently the clearest Apple-supported path for explicit `PCC` selection

## Recommended architecture decision

Use a three-lane model:

1. `FoundationModels`
   - default Apple-native inference lane for app features
   - local-first
   - predictable public SDK

2. `Core ML / Create ML`
   - deterministic custom local models
   - classification, tagging, ranking, embedding-like auxiliaries, narrow tasks

3. `MLX`
   - advanced local experimentation / custom model work on Apple Silicon
   - outside the public Apple Intelligence app runtime model

This gives you:

- public Apple-native shipping path
- deterministic local model path
- high-flexibility research path

## What I would not assume

Do not assume, without new public docs, that:

- `FoundationModels` silently upgrades your app requests to PCC
- your app can explicitly choose PCC the way Shortcuts can
- adapter training is a substitute for general remote-model capability

Those are different surfaces.

## Best next steps

1. Keep the current app starter on `FoundationModels` plus `Core ML`.
2. Add a separate `Shortcuts` experiment specifically to test `Use Model -> Private Cloud Compute`.
3. If needed, build an `MLX` research lane for custom local models.
4. Re-check Apple docs after every major OS / Xcode drop because this area is moving quickly.
