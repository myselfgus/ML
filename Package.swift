// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppleMLStarter",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "MLFeaturePipeline",
            targets: ["MLFeaturePipeline"]
        ),
        .library(
            name: "MLInferenceCore",
            targets: ["MLInferenceCore"]
        ),
        .executable(
            name: "AppleMLStarterApp",
            targets: ["AppleMLStarterApp"]
        ),
    ],
    targets: [
        .target(
            name: "MLFeaturePipeline"
        ),
        .target(
            name: "MLInferenceCore",
            dependencies: ["MLFeaturePipeline"],
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "AppleMLStarterApp",
            dependencies: ["MLFeaturePipeline", "MLInferenceCore"]
        ),
        .testTarget(
            name: "MLFeaturePipelineTests",
            dependencies: ["MLFeaturePipeline"]
        ),
        .testTarget(
            name: "MLInferenceCoreTests",
            dependencies: ["MLFeaturePipeline", "MLInferenceCore"]
        ),
    ]
)
