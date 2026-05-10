import Foundation
import MLInferenceCore

private final class InferenceXPCService: NSObject, AppleXPCInferenceServiceProtocol {
    private let provider = AppleFoundationModelProvider()

    private final class PingReplyBox: @unchecked Sendable {
        let reply: (Bool, NSString?) -> Void
        init(_ reply: @escaping (Bool, NSString?) -> Void) {
            self.reply = reply
        }
    }

    private final class GenerateReplyBox: @unchecked Sendable {
        let reply: (NSString?, NSDictionary?, NSString?) -> Void
        init(_ reply: @escaping (NSString?, NSDictionary?, NSString?) -> Void) {
            self.reply = reply
        }
    }

    func ping(_ reply: @escaping (Bool, NSString?) -> Void) {
        let provider = self.provider
        let replyBox = PingReplyBox(reply)
        Task {
            let availability = await provider.availability()
            switch availability {
            case .available:
                replyBox.reply(true, nil)
            case let .unavailable(reason):
                replyBox.reply(false, reason as NSString)
            }
        }
    }

    func generate(
        prompt: NSString,
        systemPrompt: NSString?,
        reply: @escaping (NSString?, NSDictionary?, NSString?) -> Void
    ) {
        let provider = self.provider
        let replyBox = GenerateReplyBox(reply)
        let promptText = String(prompt)
        let systemPromptText = systemPrompt.map(String.init)
        Task {
            let request = InferenceRequest(
                prompt: promptText,
                systemPrompt: systemPromptText,
                capability: .textGeneration
            )

            do {
                let response = try await provider.generate(request)
                var metadata = response.metadata
                metadata["provider"] = response.providerID.rawValue
                metadata["transport"] = "xpc"
                replyBox.reply(response.text as NSString, metadata as NSDictionary, nil)
            } catch {
                replyBox.reply(nil, nil, error.localizedDescription as NSString)
            }
        }
    }
}

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let exportedObject = InferenceXPCService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: AppleXPCInferenceServiceProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

let listener = NSXPCListener.service()
private let delegate = ServiceDelegate()
listener.delegate = delegate
listener.resume()
dispatchMain()
