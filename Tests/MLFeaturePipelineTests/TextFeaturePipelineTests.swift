import MLFeaturePipeline
import Testing

struct TextFeaturePipelineTests {
    @Test
    func normalizesAndTokenizesInput() {
        let extractor = DefaultTextFeatureExtractor()
        let input = PredictionInput(text: "  Apple ML Is Fast and Safe.  ")

        let features = extractor.extract(from: input)

        #expect(features.normalizedText == "apple ml is fast and safe.")
        #expect(features.tokens == ["apple", "ml", "is", "fast", "and", "safe"])
        #expect(features.characterCount == 26)
    }
}
