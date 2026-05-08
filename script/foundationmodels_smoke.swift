import Foundation
import FoundationModels

@main
struct FoundationModelsSmoke {
    static func main() async {
        let model = SystemLanguageModel.default
        print("availability=\(model.availability)")
        print("supports_en_US=\(model.supportsLocale(Locale(identifier: "en_US")))")
        print("supports_pt_BR=\(model.supportsLocale(Locale(identifier: "pt_BR")))")

        guard model.availability == .available else {
            return
        }

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: "What is 2 + 2? Answer with one short sentence."
            )
            print("response=\(response.content)")
        } catch {
            print("error=\(error)")
        }
    }
}
