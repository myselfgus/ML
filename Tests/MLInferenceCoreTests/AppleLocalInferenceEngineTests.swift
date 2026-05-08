import MLFeaturePipeline
import MLInferenceCore
import Testing

struct AppleLocalInferenceEngineTests {
    @Test
    func returnsPositivePredictionForPositiveLanguage() throws {
        let engine = AppleLocalInferenceEngine()

        let result = try engine.predict(
            input: PredictionInput(text: "The rollout looks safe, fast, and stable.")
        )

        #expect(result.predictedClass == "positive")
        #expect(result.usedFallback)
        #expect(result.model == .starter)
        #expect(result.metrics.latencyMilliseconds >= 0)
    }

    @Test
    func rejectsEmptyInput() {
        let engine = AppleLocalInferenceEngine()

        #expect(throws: InferenceError.emptyInput) {
            try engine.predict(input: PredictionInput(text: "   "))
        }
    }
}
