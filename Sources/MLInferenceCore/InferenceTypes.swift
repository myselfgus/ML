import Foundation
import MLFeaturePipeline

/// Stable identifier for a pluggable inference provider.
public struct InferenceProviderID: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

/// Generic capabilities that an inference provider can expose.
public enum InferenceCapability: String, CaseIterable, Hashable, Sendable, Codable {
    case textGeneration
}

/// Generic request options for provider-agnostic inference calls.
public struct InferenceOptions: Sendable, Equatable {
    public let temperature: Double?
    public let maxOutputTokens: Int?
    public let timeout: Duration?

    public init(
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        timeout: Duration? = nil
    ) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.timeout = timeout
    }
}

/// Generic request model for inference routing.
public struct InferenceRequest: Sendable, Equatable {
    public let prompt: String
    public let systemPrompt: String?
    public let capability: InferenceCapability
    public let preferredProviderID: InferenceProviderID?
    public let options: InferenceOptions
    public let metadata: [String: String]

    public init(
        prompt: String,
        systemPrompt: String? = nil,
        capability: InferenceCapability = .textGeneration,
        preferredProviderID: InferenceProviderID? = nil,
        options: InferenceOptions = .init(),
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.capability = capability
        self.preferredProviderID = preferredProviderID
        self.options = options
        self.metadata = metadata
    }
}

/// Completion signal from a provider response.
public enum InferenceFinishReason: String, Sendable, Equatable, Codable {
    case completed
    case truncated
    case cancelled
    case unknown
}

/// Provider-agnostic inference response.
public struct InferenceResponse: Sendable, Equatable {
    public let text: String
    public let providerID: InferenceProviderID
    public let finishReason: InferenceFinishReason?
    public let metadata: [String: String]

    public init(
        text: String,
        providerID: InferenceProviderID,
        finishReason: InferenceFinishReason? = nil,
        metadata: [String: String] = [:]
    ) {
        self.text = text
        self.providerID = providerID
        self.finishReason = finishReason
        self.metadata = metadata
    }
}

/// Runtime availability state for providers.
public enum InferenceProviderAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
}

/// Pluggable provider contract exposed by MLInferenceCore.
public protocol InferenceProvider: Sendable {
    var id: InferenceProviderID { get }
    var capabilities: Set<InferenceCapability> { get }
    func availability() async -> InferenceProviderAvailability
    func generate(_ request: InferenceRequest) async throws -> InferenceResponse
}

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

public enum InferenceError: LocalizedError, Equatable, Sendable {
    case emptyInput
    case providerUnavailable(id: InferenceProviderID, reason: String)
    case noCompatibleProvider(capability: InferenceCapability)
    case providerNotFound(id: InferenceProviderID)
    case capabilityNotSupported(id: InferenceProviderID, capability: InferenceCapability)
    case allProvidersUnavailable(capability: InferenceCapability)
    case generationFailed(id: InferenceProviderID, message: String)
    case timeout
    case cancelled
    case internalError(message: String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input vazio. Forneca texto antes de rodar a inferencia."
        case let .providerUnavailable(id, reason):
            return "Provider '\(id.rawValue)' indisponivel: \(reason)"
        case let .noCompatibleProvider(capability):
            return "Nenhum provider compativel para capability '\(capability.rawValue)'."
        case let .providerNotFound(id):
            return "Provider '\(id.rawValue)' nao encontrado."
        case let .capabilityNotSupported(id, capability):
            return "Provider '\(id.rawValue)' nao suporta capability '\(capability.rawValue)'."
        case let .allProvidersUnavailable(capability):
            return "Todos os providers compativeis para '\(capability.rawValue)' estao indisponiveis."
        case let .generationFailed(id, message):
            return "Falha de geracao no provider '\(id.rawValue)': \(message)"
        case .timeout:
            return "Tempo limite excedido durante a inferencia."
        case .cancelled:
            return "Inferencia cancelada."
        case let .internalError(message):
            return "Erro interno de inferencia: \(message)"
        }
    }
}

public protocol Predicting: Sendable {
    var descriptor: ModelDescriptor { get }
    var modelAssetStatus: ModelAssetStatus { get }
    func predict(input: PredictionInput) throws -> PredictionResult
}
