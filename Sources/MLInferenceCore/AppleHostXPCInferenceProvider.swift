import Foundation

/// Routes inference through a local XPC host process that owns Foundation Models runtime context.
public struct AppleHostXPCInferenceProvider: InferenceProvider {
    public let id: InferenceProviderID
    public let capabilities: Set<InferenceCapability> = [.textGeneration]
    public let serviceName: String
    public let defaultTimeout: Duration
    private static let connectionPool = LockedXPCConnectionPool()

    public init(
        id: InferenceProviderID = "apple.foundation-models.xpc-host",
        serviceName: String = "com.myselfgus.AppleMLStarterDemo.InferenceXPCService",
        defaultTimeout: Duration = .seconds(30)
    ) {
        self.id = id
        self.serviceName = serviceName
        self.defaultTimeout = defaultTimeout
    }

    public func availability() async -> InferenceProviderAvailability {
        #if os(macOS)
        do {
            let ping = try await ping(timeout: defaultTimeout)
            return ping ? .available : .unavailable(reason: "XPC service respondeu indisponivel.")
        } catch {
            return .unavailable(reason: "XPC host indisponivel: \(error.localizedDescription)")
        }
        #else
        return .unavailable(reason: "AppleHostXPCInferenceProvider suporta apenas macOS.")
        #endif
    }

    public func generate(_ request: InferenceRequest) async throws -> InferenceResponse {
        let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw InferenceError.emptyInput
        }

        #if os(macOS)
        let requestID = UUID().uuidString
        let start = Date()
        let timeout = request.options.timeout ?? defaultTimeout
        do {
            let (text, metadata) = try await sendGenerate(
                prompt: trimmedPrompt,
                systemPrompt: request.systemPrompt,
                timeout: timeout
            )
            var responseMetadata = metadata
            responseMetadata["request_id"] = requestID
            responseMetadata["latency_ms"] = String(Int(Date().timeIntervalSince(start) * 1000))
            return InferenceResponse(
                text: text,
                providerID: id,
                finishReason: .completed,
                metadata: responseMetadata
            )
        } catch let error as InferenceError {
            throw error
        } catch is CancellationError {
            throw InferenceError.cancelled
        } catch {
            throw InferenceError.generationFailed(id: id, message: error.localizedDescription)
        }
        #else
        throw InferenceError.providerUnavailable(id: id, reason: "Provider XPC disponivel apenas em macOS.")
        #endif
    }

    private func makeConnection() -> NSXPCConnection {
        Self.connectionPool.connection(serviceName: serviceName)
    }

    private func invalidateConnection() {
        Self.connectionPool.invalidate(serviceName: serviceName)
    }

    private func makeFreshConnection() -> NSXPCConnection {
        invalidateConnection()
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: AppleXPCInferenceServiceProtocol.self)
        connection.resume()
        Self.connectionPool.store(connection: connection, serviceName: serviceName)
        return connection
    }

    private func ping(timeout: Duration) async throws -> Bool {
        do {
            return try await pingOnce(timeout: timeout, forceFreshConnection: false)
        } catch {
            return try await pingOnce(timeout: timeout, forceFreshConnection: true)
        }
    }

    private func sendGenerate(
        prompt: String,
        systemPrompt: String?,
        timeout: Duration
    ) async throws -> (String, [String: String]) {
        do {
            return try await sendGenerateOnce(
                prompt: prompt,
                systemPrompt: systemPrompt,
                timeout: timeout,
                forceFreshConnection: false
            )
        } catch {
            return try await sendGenerateOnce(
                prompt: prompt,
                systemPrompt: systemPrompt,
                timeout: timeout,
                forceFreshConnection: true
            )
        }
    }

    private func pingOnce(timeout: Duration, forceFreshConnection: Bool) async throws -> Bool {
        try await withTimeout(timeout) {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    let connection = if forceFreshConnection {
                        makeFreshConnection()
                    } else {
                        makeConnection()
                    }
                    let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                        invalidateConnection()
                        continuation.resume(throwing: InferenceError.providerUnavailable(id: id, reason: error.localizedDescription))
                    } as? AppleXPCInferenceServiceProtocol

                    guard let proxy else {
                        invalidateConnection()
                        continuation.resume(throwing: InferenceError.providerUnavailable(id: id, reason: "Falha ao criar proxy XPC."))
                        return
                    }

                    proxy.ping { available, errorText in
                        if let errorText, errorText.length > 0 {
                            continuation.resume(throwing: InferenceError.providerUnavailable(id: id, reason: String(errorText)))
                            return
                        }
                        continuation.resume(returning: available)
                    }
                }
            }
        }
    }

    private func sendGenerateOnce(
        prompt: String,
        systemPrompt: String?,
        timeout: Duration,
        forceFreshConnection: Bool
    ) async throws -> (String, [String: String]) {
        try await withTimeout(timeout) {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    let connection = if forceFreshConnection {
                        makeFreshConnection()
                    } else {
                        makeConnection()
                    }
                    let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                        invalidateConnection()
                        continuation.resume(throwing: InferenceError.generationFailed(id: id, message: error.localizedDescription))
                    } as? AppleXPCInferenceServiceProtocol

                    guard let proxy else {
                        invalidateConnection()
                        continuation.resume(throwing: InferenceError.generationFailed(id: id, message: "Falha ao criar proxy XPC."))
                        return
                    }

                    proxy.generate(prompt: prompt as NSString, systemPrompt: systemPrompt as NSString?) { text, metadata, errorText in
                        if let errorText, errorText.length > 0 {
                            continuation.resume(throwing: InferenceError.generationFailed(id: id, message: String(errorText)))
                            return
                        }

                        guard let text else {
                            continuation.resume(throwing: InferenceError.generationFailed(id: id, message: "Resposta vazia do host XPC."))
                            return
                        }

                        let responseMetadata: [String: String]
                        if let metadata = metadata as? [String: String] {
                            responseMetadata = metadata
                        } else {
                            responseMetadata = [:]
                        }

                        continuation.resume(returning: (String(text), responseMetadata))
                    }
                }
            }
        }
    }

    private func withTimeout<T: Sendable>(
        _ timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw InferenceError.timeout
            }

            guard let first = try await group.next() else {
                throw InferenceError.internalError(message: "TaskGroup sem resultado.")
            }
            group.cancelAll()
            return first
        }
    }
}

private final class LockedXPCConnectionPool: @unchecked Sendable {
    private var connections: [String: NSXPCConnection] = [:]
    private let lock = NSLock()

    func connection(serviceName: String) -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }
        if let existing = connections[serviceName] {
            return existing
        }

        let newConnection = NSXPCConnection(serviceName: serviceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppleXPCInferenceServiceProtocol.self)
        newConnection.interruptionHandler = { [weak newConnection] in
            newConnection?.invalidate()
        }
        newConnection.invalidationHandler = { [weak newConnection] in
            newConnection?.invalidationHandler = nil
            newConnection?.interruptionHandler = nil
        }
        newConnection.resume()
        connections[serviceName] = newConnection
        return newConnection
    }

    func store(connection: NSXPCConnection, serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        connections[serviceName] = connection
    }

    func invalidate(serviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let connection = connections.removeValue(forKey: serviceName) else {
            return
        }
        connection.invalidationHandler = nil
        connection.interruptionHandler = nil
        connection.invalidate()
    }
}
