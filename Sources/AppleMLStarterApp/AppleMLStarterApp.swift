import MLFeaturePipeline
import MLInferenceCore
import Observation
import SwiftUI

@Observable
@MainActor
final class InferenceViewModel {
    var inputText = "The local Apple ML pipeline looks stable and fast."
    var latestResult: PredictionResult?
    var errorMessage: String?

    private let engine = AppleLocalInferenceEngine()

    var modelStatus: ModelAssetStatus {
        engine.modelAssetStatus
    }

    func runPrediction() {
        do {
            errorMessage = nil
            latestResult = try engine.predict(input: PredictionInput(text: inputText))
        } catch {
            latestResult = nil
            errorMessage = error.localizedDescription
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
        GroupBox("Model bundle status") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Modelo detectado") {
                    Text(viewModel.modelStatus.isPresent ? "sim" : "nao")
                }
                LabeledContent("Versao esperada") {
                    Text("\(ModelDescriptor.starter.name) @ \(ModelDescriptor.starter.version)")
                }
                if let path = viewModel.modelStatus.detectedPath {
                    LabeledContent("Path") {
                        Text(path)
                            .textSelection(.enabled)
                    }
                }
                Text(viewModel.modelStatus.note)
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
                    LabeledContent("Classe") {
                        Text(result.predictedClass)
                    }
                    LabeledContent("Confianca") {
                        Text(result.confidence.formatted(.percent.precision(.fractionLength(0))))
                    }
                    LabeledContent("Latencia") {
                        Text("\(result.metrics.latencyMilliseconds.formatted(.number.precision(.fractionLength(2)))) ms")
                    }
                    LabeledContent("Fallback ativo") {
                        Text(result.usedFallback ? "sim" : "nao")
                    }

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
