import Foundation

/// XPC contract for the Apple Foundation Models host service.
@objc public protocol AppleXPCInferenceServiceProtocol {
    /// Health check that verifies the service is alive and can report provider readiness.
    func ping(_ reply: @escaping (Bool, NSString?) -> Void)

    /// Runs text generation and returns response text, metadata, and an optional error string.
    func generate(
        prompt: NSString,
        systemPrompt: NSString?,
        reply: @escaping (NSString?, NSDictionary?, NSString?) -> Void
    )
}
