import Foundation
import NaturalLanguage

public struct PredictionInput: Sendable, Equatable {
    public let text: String
    public let requestID: UUID

    public init(text: String, requestID: UUID = UUID()) {
        self.text = text
        self.requestID = requestID
    }
}

public struct TextFeatures: Sendable, Equatable {
    public let normalizedText: String
    public let tokens: [String]
    public let characterCount: Int

    public init(normalizedText: String, tokens: [String], characterCount: Int) {
        self.normalizedText = normalizedText
        self.tokens = tokens
        self.characterCount = characterCount
    }
}

public protocol TextFeatureExtracting: Sendable {
    func extract(from input: PredictionInput) -> TextFeatures
}

public struct DefaultTextFeatureExtractor: TextFeatureExtracting {
    public init() {}

    public func extract(from input: PredictionInput) -> TextFeatures {
        let normalized = input.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalized

        var tokens: [String] = []
        let range = normalized.startIndex..<normalized.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let token = String(normalized[tokenRange])
            if !token.isEmpty {
                tokens.append(token)
            }
            return true
        }

        return TextFeatures(
            normalizedText: normalized,
            tokens: tokens,
            characterCount: normalized.count
        )
    }
}
