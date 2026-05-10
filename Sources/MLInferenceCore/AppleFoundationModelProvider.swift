import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationModelProvider: InferenceProvider {
    public let id: InferenceProviderID = "apple.foundation-models"
    public let capabilities: Set<InferenceCapability> = [.textGeneration]

    public init() {}

    public func availability() async -> InferenceProviderAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available {
                return .available
            }
            return .unavailable(reason: "SystemLanguageModel availability: \(String(describing: model.availability))")
        }
        return .unavailable(reason: "Foundation Models requer macOS 26+ ou iOS 26+.")
        #else
        return .unavailable(reason: "Framework FoundationModels indisponivel neste SDK.")
        #endif
    }

    public func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw InferenceError.emptyInput
        }

        let status = await availability()
        guard status.isAvailable else {
            if case let .unavailable(reason) = status {
                throw InferenceError.providerUnavailable(id: id, reason: reason)
            }
            throw InferenceError.providerUnavailable(id: id, reason: "Indisponivel.")
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            do {
                let prompt = mergedPrompt(systemPrompt: request.systemPrompt, prompt: trimmedPrompt)
                let session = LanguageModelSession()
                let result = try await session.respond(to: prompt)

                return InferenceResponse(
                    text: result.content,
                    providerID: id,
                    finishReason: .completed,
                    metadata: [
                        "provider": id.rawValue,
                        "runtime": "foundationmodels-system",
                    ]
                )
            } catch is CancellationError {
                throw InferenceError.cancelled
            } catch {
                throw InferenceError.generationFailed(id: id, message: String(describing: error))
            }
        }
        #endif

        throw InferenceError.providerUnavailable(id: id, reason: "Foundation Models indisponivel em runtime.")
    }

    private func mergedPrompt(systemPrompt: String?, prompt: String) -> String {
        guard let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return prompt
        }
        return "[System]\n\(systemPrompt)\n\n[User]\n\(prompt)"
    }
}
