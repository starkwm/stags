// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "stags",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "stags", targets: ["Stags"])],
  dependencies: [
    .package(url: "https://github.com/starkwm/stark-ipc", from: "0.0.5"),
    .package(url: "https://github.com/starkwm/stark-skylight", exact: "0.0.3"),
  ],
  targets: [
    .executableTarget(
      name: "Stags",
      dependencies: ["StagsCore", .product(name: "StarkIPC", package: "stark-ipc")]
    ),
    .target(
      name: "StagsCore",
      dependencies: [
        .product(name: "StarkIPC", package: "stark-ipc"),
        .product(name: "StarkSkyLight", package: "stark-skylight"),
      ]
    ),
    .testTarget(
      name: "StagsCoreTests",
      dependencies: ["StagsCore", .product(name: "StarkSkyLight", package: "stark-skylight")]
    ),
  ],
  swiftLanguageModes: [.v6]
)
