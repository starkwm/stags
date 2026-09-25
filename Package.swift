// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "stags",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "stags", targets: ["Stags"])],
  dependencies: [
    .package(url: "https://github.com/starkwm/stark-ipc", from: "0.0.5")
  ],
  targets: [
    .executableTarget(
      name: "Stags",
      dependencies: ["StagsCore", .product(name: "StarkIPC", package: "stark-ipc")]
    ),
    .target(
      name: "StagsCore",
      dependencies: [.product(name: "StarkIPC", package: "stark-ipc")]
    ),
    .testTarget(name: "StagsCoreTests", dependencies: ["StagsCore"]),
  ],
  swiftLanguageModes: [.v6]
)
