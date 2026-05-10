import MLInferenceCore
import Observation
import SwiftUI

@Observable
@MainActor
final class DemoInferenceViewModel {
    var availabilityText = "Checking..."
    var selectedProviderID = "apple.foundation-models.xpc-host"
    var prompt = "Explique em 3 linhas o que é Apple Intelligence."
    var responseText = ""
    var errorText: String?
    var isGenerating = false

    @ObservationIgnored
    private let xpcProvider = AppleHostXPCInferenceProvider()
    private let directProvider = AppleFoundationModelProvider()
    @ObservationIgnored
    private let registry = InferenceProviderRegistry()
    @ObservationIgnored
    private let router: InferenceRouter

    init() {
        self.router = InferenceRouter(registry: registry)

        Task { [registry, xpcProvider, directProvider] in
            do {
                try await registry.register(xpcProvider, policy: .replaceExisting)
                try await registry.register(directProvider, policy: .replaceExisting)

                let xpcAvailability = await xpcProvider.availability()
                let directAvailability = await directProvider.availability()
                await MainActor.run {
                    switch xpcAvailability {
                    case .available:
                        self.selectedProviderID = xpcProvider.id.rawValue
                        self.availabilityText = "xpc-host: available"
                    case let .unavailable(reason):
                        self.selectedProviderID = directProvider.id.rawValue
                        switch directAvailability {
                        case .available:
                            self.availabilityText = "xpc-host unavailable (\(reason)); fallback direct available"
                        case let .unavailable(directReason):
                            self.availabilityText = "xpc-host unavailable (\(reason)); direct unavailable (\(directReason))"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.availabilityText = "registration failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func generate() {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            errorText = "Prompt vazio."
            return
        }

        let request = InferenceRequest(
            prompt: trimmedPrompt,
            systemPrompt: "Você é um assistente técnico objetivo.",
            preferredProviderID: InferenceProviderID(rawValue: selectedProviderID)
        )

        isGenerating = true
        errorText = nil

        Task { [router] in
            do {
                let response = try await router.generate(request)
                await MainActor.run {
                    self.responseText = response.text
                    self.errorText = nil
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.responseText = ""
                    self.errorText = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
}

struct DemoInferenceView: View {
    @State private var viewModel = DemoInferenceViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AppleMLStarterDemo")
                .font(.title2.weight(.semibold))

            LabeledContent("Provider") { Text("apple.foundation-models") }
            LabeledContent("Selected Provider") { Text(viewModel.selectedProviderID) }
            LabeledContent("Availability") { Text(viewModel.availabilityText) }

            Text("Prompt")
                .font(.headline)
            TextEditor(text: $viewModel.prompt)
                .font(.body.monospaced())
                .frame(minHeight: 140)
                .padding(8)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button(viewModel.isGenerating ? "Gerando..." : "Gerar") {
                    viewModel.generate()
                }
                .disabled(viewModel.isGenerating)
            }

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .foregroundStyle(.red)
            } else if !viewModel.responseText.isEmpty {
                Text("Resposta")
                    .font(.headline)
                ScrollView {
                    Text(viewModel.responseText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 540)
    }
}

@main
struct AppleMLStarterDemoApp: App {
    var body: some Scene {
        WindowGroup("Apple ML Starter Demo") {
            DemoInferenceView()
        }
    }
}
