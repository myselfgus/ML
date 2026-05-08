import CoreML
import Foundation
import MLFeaturePipeline
import NaturalLanguage
import OSLog
import SoundAnalysis
import Vision

public final class AppleLocalInferenceEngine: Predicting {
    public let descriptor: ModelDescriptor
    public let modelAssetStatus: ModelAssetStatus

    private let featureExtractor: any TextFeatureExtracting
    private let logger: Logger

    public init(
        descriptor: ModelDescriptor = .starter,
        featureExtractor: any TextFeatureExtracting = DefaultTextFeatureExtractor()
    ) {
        self.descriptor = descriptor
        self.featureExtractor = featureExtractor
        self.modelAssetStatus = Self.detectModelAsset(named: descriptor.name)
        self.logger = Logger(
            subsystem: "com.healthos.applemlstarter",
            category: "Inference"
        )
    }

    public func predict(input: PredictionInput) throws -> PredictionResult {
        let trimmedInput = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw InferenceError.emptyInput
        }

        let start = DispatchTime.now().uptimeNanoseconds
        let features = featureExtractor.extract(from: PredictionInput(text: trimmedInput, requestID: input.requestID))
        let classification = classify(features: features)
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
        let latencyMilliseconds = Double(elapsedNanoseconds) / 1_000_000

        let result = PredictionResult(
            predictedClass: classification.label,
            confidence: classification.confidence,
            metrics: InferenceMetrics(latencyMilliseconds: latencyMilliseconds),
            model: descriptor,
            usedFallback: true,
            metadata: [
                "tokenCount": String(features.tokens.count),
                "normalizedLength": String(features.characterCount),
                "modelAssetPresent": String(modelAssetStatus.isPresent),
                "inferenceRuntime": "heuristic-fallback",
            ]
        )

        let latencyText = String(format: "%.2f", latencyMilliseconds)
        logger.notice(
            "prediction model=\(self.descriptor.name, privacy: .public) version=\(self.descriptor.version, privacy: .public) label=\(result.predictedClass, privacy: .public) latency_ms=\(latencyText, privacy: .public)"
        )

        return result
    }

    private func classify(features: TextFeatures) -> (label: String, confidence: Double) {
        let positiveWords: Set<String> = [
            "good", "great", "safe", "stable", "healthy", "better", "fast", "success",
            "positivo", "otimo", "ótimo", "seguro", "saudavel", "saudável", "melhor"
        ]
        let negativeWords: Set<String> = [
            "bad", "slow", "broken", "error", "fail", "unsafe", "worse",
            "ruim", "lento", "erro", "falha", "instavel", "instável", "pior"
        ]

        let positiveHits = features.tokens.filter { positiveWords.contains($0) }.count
        let negativeHits = features.tokens.filter { negativeWords.contains($0) }.count
        let score = positiveHits - negativeHits

        let label: String
        switch score {
        case let value where value > 0:
            label = "positive"
        case let value where value < 0:
            label = "negative"
        default:
            label = "neutral"
        }

        let confidence = min(0.99, 0.60 + (Double(abs(score)) * 0.08))
        return (label, confidence)
    }

    private static func detectModelAsset(named modelName: String) -> ModelAssetStatus {
        guard let modelsURL = Bundle.module.resourceURL?.appendingPathComponent("Models") else {
            return ModelAssetStatus(
                isPresent: false,
                detectedPath: nil,
                note: "Diretorio de resources nao encontrado no bundle."
            )
        }

        let candidateExtensions = ["mlmodelc", "mlmodel", "mlpackage"]
        for candidateExtension in candidateExtensions {
            let candidateURL = modelsURL.appendingPathComponent("\(modelName).\(candidateExtension)")
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return ModelAssetStatus(
                    isPresent: true,
                    detectedPath: candidateURL.path,
                    note: "Asset localizado. Adicione agora um adapter tipado do schema exportado."
                )
            }
        }

        return ModelAssetStatus(
            isPresent: false,
            detectedPath: nil,
            note: "Nenhum modelo bundleado ainda. O app usa fallback local ate voce exportar um .mlmodel do Create ML."
        )
    }
}
