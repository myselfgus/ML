import Foundation

/// Resolves requests to providers by explicit ID or capability with optional fallback.
public struct InferenceRouter: Sendable {
    public let registry: InferenceProviderRegistry
    public let fallbackOnGenerationError: Bool

    public init(
        registry: InferenceProviderRegistry,
        fallbackOnGenerationError: Bool = true
    ) {
        self.registry = registry
        self.fallbackOnGenerationError = fallbackOnGenerationError
    }

    public func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        let candidates = try await candidateProviders(for: request)
        var lastGenerationError: InferenceError?
        var hadCompatibleProvider = false

        for provider in candidates {
            hadCompatibleProvider = true
            let availability = await provider.availability()
            guard availability.isAvailable else { continue }

            do {
                var response = try await provider.generate(request)
                if response.providerID.rawValue.isEmpty {
                    response = InferenceResponse(
                        text: response.text,
                        providerID: provider.id,
                        finishReason: response.finishReason,
                        metadata: response.metadata
                    )
                }
                return response
            } catch is CancellationError {
                throw InferenceError.cancelled
            } catch let error as InferenceError {
                if !fallbackOnGenerationError {
                    throw error
                }
                lastGenerationError = error
            } catch {
                let wrapped = InferenceError.generationFailed(
                    id: provider.id,
                    message: String(describing: error)
                )
                if !fallbackOnGenerationError {
                    throw wrapped
                }
                lastGenerationError = wrapped
            }
        }

        if let lastGenerationError {
            throw lastGenerationError
        }

        if let preferredID = request.preferredProviderID {
            if let provider = await registry.provider(id: preferredID) {
                let availability = await provider.availability()
                if case let .unavailable(reason) = availability {
                    throw InferenceError.providerUnavailable(id: preferredID, reason: reason)
                }
                throw InferenceError.generationFailed(id: preferredID, message: "Falha sem detalhe adicional.")
            }
            throw InferenceError.providerNotFound(id: preferredID)
        }

        if hadCompatibleProvider {
            throw InferenceError.allProvidersUnavailable(capability: request.capability)
        }

        throw InferenceError.noCompatibleProvider(capability: request.capability)
    }

    private func candidateProviders(for request: InferenceRequest) async throws -> [any InferenceProvider] {
        if let preferredID = request.preferredProviderID {
            guard let provider = await registry.provider(id: preferredID) else {
                throw InferenceError.providerNotFound(id: preferredID)
            }
            guard provider.capabilities.contains(request.capability) else {
                throw InferenceError.capabilityNotSupported(id: preferredID, capability: request.capability)
            }
            return [provider]
        }

        return await registry.providers(supporting: request.capability)
    }
}
