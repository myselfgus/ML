import MLInferenceCore
import Testing

private struct MockInferenceProvider: InferenceProvider {
    enum Behavior: Sendable {
        case success(String)
        case fail(String)
    }

    let id: InferenceProviderID
    let capabilities: Set<InferenceCapability>
    let availabilityState: InferenceProviderAvailability
    let behavior: Behavior

    func availability() async -> InferenceProviderAvailability {
        availabilityState
    }

    func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        switch behavior {
        case let .success(text):
            return InferenceResponse(
                text: text,
                providerID: id,
                finishReason: .completed
            )
        case let .fail(message):
            throw InferenceError.generationFailed(id: id, message: message)
        }
    }
}

struct InferenceRoutingTests {
    @Test
    func registryRegistersAndFindsProviderByID() async throws {
        let registry = InferenceProviderRegistry()
        let provider = MockInferenceProvider(
            id: "mock.a",
            capabilities: [.textGeneration],
            availabilityState: .available,
            behavior: .success("ok")
        )
        try await registry.register(provider)

        let found = await registry.provider(id: "mock.a")
        #expect(found != nil)
        #expect(found?.id == "mock.a")
    }

    @Test
    func registryFiltersByCapability() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "mock.a",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("ok")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "mock.b",
                capabilities: [],
                availabilityState: .available,
                behavior: .success("ok")
            )
        )

        let filtered = await registry.providers(supporting: .textGeneration)
        #expect(filtered.map(\.id).contains("mock.a"))
        #expect(!filtered.map(\.id).contains("mock.b"))
    }

    @Test
    func registryReplaceExistingDoesNotDuplicateOrder() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "same",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("first")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "same",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("second")
            ),
            policy: .replaceExisting
        )

        let providers = await registry.allProviders()
        #expect(providers.count == 1)
        #expect(providers.first?.id == "same")
    }

    @Test
    func routerThrowsWhenNoProviderExists() async {
        let router = InferenceRouter(registry: InferenceProviderRegistry())
        await #expect(throws: InferenceError.noCompatibleProvider(capability: .textGeneration)) {
            _ = try await router.generate(.init(prompt: "Hello"))
        }
    }

    @Test
    func routerThrowsWhenExplicitProviderDoesNotExist() async {
        let router = InferenceRouter(registry: InferenceProviderRegistry())
        await #expect(throws: InferenceError.providerNotFound(id: "missing")) {
            _ = try await router.generate(
                .init(prompt: "Hello", preferredProviderID: "missing")
            )
        }
    }

    @Test
    func routerThrowsWhenExplicitProviderLacksCapability() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "empty",
                capabilities: [],
                availabilityState: .available,
                behavior: .success("ok")
            )
        )

        let router = InferenceRouter(registry: registry)
        await #expect(throws: InferenceError.capabilityNotSupported(id: "empty", capability: .textGeneration)) {
            _ = try await router.generate(.init(prompt: "Hello", preferredProviderID: "empty"))
        }
    }

    @Test
    func routerThrowsWhenExplicitProviderIsUnavailable() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "offline",
                capabilities: [.textGeneration],
                availabilityState: .unavailable(reason: "maintenance"),
                behavior: .success("unused")
            )
        )

        let router = InferenceRouter(registry: registry)
        await #expect(throws: InferenceError.providerUnavailable(id: "offline", reason: "maintenance")) {
            _ = try await router.generate(.init(prompt: "Hello", preferredProviderID: "offline"))
        }
    }

    @Test
    func routerFallsBackFromUnavailableToAvailableProvider() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "unavailable",
                capabilities: [.textGeneration],
                availabilityState: .unavailable(reason: "offline"),
                behavior: .success("should-not-run")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "available",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("final-answer")
            )
        )

        let response = try await InferenceRouter(registry: registry).generate(
            .init(prompt: "Hello")
        )
        #expect(response.providerID == "available")
        #expect(response.text == "final-answer")
    }

    @Test
    func routerFallsBackWhenFirstProviderFailsGeneration() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "fails",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .fail("boom")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "works",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("ok")
            )
        )

        let response = try await InferenceRouter(registry: registry).generate(
            .init(prompt: "Hello")
        )
        #expect(response.providerID == "works")
        #expect(response.text == "ok")
    }

    @Test
    func routerThrowsWhenAllCompatibleProvidersAreUnavailable() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "offline-1",
                capabilities: [.textGeneration],
                availabilityState: .unavailable(reason: "offline"),
                behavior: .success("unused")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "offline-2",
                capabilities: [.textGeneration],
                availabilityState: .unavailable(reason: "offline"),
                behavior: .success("unused")
            )
        )

        let router = InferenceRouter(registry: registry)
        await #expect(throws: InferenceError.allProvidersUnavailable(capability: .textGeneration)) {
            _ = try await router.generate(.init(prompt: "Hello"))
        }
    }

    @Test
    func routerDoesNotFallbackWhenFallbackDisabled() async throws {
        let registry = InferenceProviderRegistry()
        try await registry.register(
            MockInferenceProvider(
                id: "fails",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .fail("boom")
            )
        )
        try await registry.register(
            MockInferenceProvider(
                id: "works",
                capabilities: [.textGeneration],
                availabilityState: .available,
                behavior: .success("ok")
            )
        )

        let router = InferenceRouter(registry: registry, fallbackOnGenerationError: false)
        await #expect(throws: InferenceError.generationFailed(id: "fails", message: "boom")) {
            _ = try await router.generate(.init(prompt: "Hello"))
        }
    }

    @Test
    func appleProviderUnavailableIsHandledSafelyWhenRuntimeIsUnavailable() async {
        let provider = AppleFoundationModelProvider()
        let availability = await provider.availability()

        if case .unavailable = availability {
            do {
                _ = try await provider.generate(.init(prompt: "Hello"))
                Issue.record("Era esperado erro de indisponibilidade")
            } catch let error as InferenceError {
                if case let .providerUnavailable(id, _) = error {
                    #expect(id == provider.id)
                } else {
                    Issue.record("Erro inesperado: \(error)")
                }
            } catch {
                Issue.record("Erro inesperado: \(error)")
            }
        }
    }

    @Test
    func xpcProviderHandlesMissingServiceSafely() async {
        let provider = AppleHostXPCInferenceProvider(
            serviceName: "com.myselfgus.DoesNotExistXPCService",
            defaultTimeout: .seconds(1)
        )

        let availability = await provider.availability()
        if case .unavailable = availability {
            do {
                _ = try await provider.generate(.init(prompt: "Hello"))
                Issue.record("Era esperado erro para serviceName inexistente.")
            } catch let error as InferenceError {
                if case .generationFailed = error {
                    // expected
                } else if case .timeout = error {
                    // expected
                } else {
                    Issue.record("Erro inesperado: \(error)")
                }
            } catch {
                Issue.record("Erro inesperado: \(error)")
            }
        }
    }
}
