import Foundation

/// Actor-backed registry for provider discovery and deterministic fallback order.
public actor InferenceProviderRegistry {
    public enum RegistrationPolicy: Sendable {
        case rejectDuplicate
        case replaceExisting
    }

    private var providersByID: [InferenceProviderID: any InferenceProvider] = [:]
    private var providerOrder: [InferenceProviderID] = []

    public init(providers: [any InferenceProvider] = []) {
        for provider in providers {
            if providersByID[provider.id] == nil {
                providerOrder.append(provider.id)
            }
            providersByID[provider.id] = provider
        }
    }

    public func register(
        _ provider: any InferenceProvider,
        policy: RegistrationPolicy = .rejectDuplicate
    ) throws {
        if providersByID[provider.id] != nil, policy == .rejectDuplicate {
            throw InferenceError.internalError(
                message: "Provider '\(provider.id.rawValue)' ja registrado."
            )
        }
        if providersByID[provider.id] == nil {
            providerOrder.append(provider.id)
        }
        providersByID[provider.id] = provider
    }

    public func allProviders() -> [any InferenceProvider] {
        providerOrder.compactMap { providersByID[$0] }
    }

    public func provider(id: InferenceProviderID) -> (any InferenceProvider)? {
        providersByID[id]
    }

    public func providers(supporting capability: InferenceCapability) -> [any InferenceProvider] {
        allProviders().filter { $0.capabilities.contains(capability) }
    }
}
