import Foundation
import MLFeaturePipeline

public struct ModelDescriptor: Sendable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    public static let starter = ModelDescriptor(
        name: "StarterTextClassifier",
        version: "0.1.0"
    )
}

public struct ModelAssetStatus: Sendable, Equatable {
    public let isPresent: Bool
    public let detectedPath: String?
    public let note: String

    public init(isPresent: Bool, detectedPath: String?, note: String) {
        self.isPresent = isPresent
        self.detectedPath = detectedPath
        self.note = note
    }
}

public struct InferenceMetrics: Sendable, Equatable {
    public let latencyMilliseconds: Double

    public init(latencyMilliseconds: Double) {
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public struct PredictionResult: Sendable, Equatable {
    public let predictedClass: String
    public let confidence: Double
    public let metrics: InferenceMetrics
    public let model: ModelDescriptor
    public let usedFallback: Bool
    public let metadata: [String: String]

    public init(
        predictedClass: String,
        confidence: Double,
        metrics: InferenceMetrics,
        model: ModelDescriptor,
        usedFallback: Bool,
        metadata: [String: String]
    ) {
        self.predictedClass = predictedClass
        self.confidence = confidence
        self.metrics = metrics
        self.model = model
        self.usedFallback = usedFallback
        self.metadata = metadata
    }
}

public enum InferenceError: LocalizedError, Equatable {
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input vazio. Forneca texto antes de rodar a inferencia."
        }
    }
}

public protocol Predicting: Sendable {
    var descriptor: ModelDescriptor { get }
    var modelAssetStatus: ModelAssetStatus { get }
    func predict(input: PredictionInput) throws -> PredictionResult
}
