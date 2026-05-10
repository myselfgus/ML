import MLInferenceCore
import Observation
import SwiftUI

@Observable
@MainActor
final class InferenceViewModel {
    var inputText = "The local Apple ML pipeline looks stable and fast."
    var latestResult: InferenceResponse?
    var errorMessage: String?
    var providerStatusText = "Checking..."

    private let registry: InferenceProviderRegistry
    private let router: InferenceRouter
    private let foundationProvider = AppleFoundationModelProvider()

    init() {
        let registry = InferenceProviderRegistry()
        self.registry = registry
        self.router = InferenceRouter(registry: registry)

        Task { [registry, foundationProvider] in
            do {
                try await registry.register(foundationProvider, policy: .replaceExisting)
                let availability = await foundationProvider.availability()
                await MainActor.run {
                    switch availability {
                    case .available:
                        self.providerStatusText = "available"
                    case let .unavailable(reason):
                        self.providerStatusText = "unavailable: \(reason)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.providerStatusText = "registration failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func runPrediction() {
        let router = self.router
        let request = InferenceRequest(
            prompt: inputText,
            systemPrompt: "You are a concise assistant. Reply in one short paragraph."
        )
        errorMessage = nil

        Task {
            do {
                let response = try await router.generate(request)
                await MainActor.run {
                    self.latestResult = response
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.latestResult = nil
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadSample(_ sample: String) {
        inputText = sample
        runPrediction()
    }
}

@main
struct AppleMLStarterApp: App {
    var body: some Scene {
        WindowGroup("Apple ML Starter") {
            InferenceRootView()
                .frame(minWidth: 880, minHeight: 620)
        }
    }
}

struct InferenceRootView: View {
    @State private var viewModel = InferenceViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header
                modelStatusCard
                inputCard
                resultCard
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Apple ML Starter")
        }
        .onAppear {
            if viewModel.latestResult == nil && viewModel.errorMessage == nil {
                viewModel.runPrediction()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple-first ML scaffold")
                .font(.largeTitle.weight(.semibold))
            Text("Xcode + Core ML + Create ML. UI desacoplada da inferencia, com contrato estavel para trocar versoes do modelo sem quebrar o fluxo do app.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var modelStatusCard: some View {
        GroupBox("Provider status") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Provider ID") {
                    Text("apple.foundation-models")
                }
                LabeledContent("Availability") {
                    Text(viewModel.providerStatusText)
                }
                Text("A app usa apenas a abstração de `MLInferenceCore`; o provider escolhe local/PCC conforme o stack da Apple.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputCard: some View {
        GroupBox("Inference input") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $viewModel.inputText)
                    .font(.body.monospaced())
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Button("Run prediction") {
                        viewModel.runPrediction()
                    }
                    .keyboardShortcut(.return, modifiers: [])

                    Button("Positive sample") {
                        viewModel.loadSample("This release feels safe, stable, and much better.")
                    }

                    Button("Negative sample") {
                        viewModel.loadSample("The app is slow, unstable, and full of error states.")
                    }
                }
            }
        }
    }

    private var resultCard: some View {
        GroupBox("Prediction result") {
            VStack(alignment: .leading, spacing: 12) {
                if let result = viewModel.latestResult {
                    LabeledContent("Provider usado") {
                        Text(result.providerID.rawValue)
                    }
                    Text(result.text)
                        .textSelection(.enabled)

                    Divider()

                    Text("Metadados")
                        .font(.headline)
                    ForEach(result.metadata.keys.sorted(), id: \.self) { key in
                        LabeledContent(key) {
                            Text(result.metadata[key] ?? "")
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Falha na inferencia",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ContentUnavailableView(
                        "Sem resultado",
                        systemImage: "brain",
                        description: Text("Rode uma inferencia para validar o fluxo local.")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
