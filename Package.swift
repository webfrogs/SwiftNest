// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNest",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/webfrogs/Transformers.git", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/jpsim/SourceKitten.git", .upToNextMinor(from: "0.20.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftNest",
            dependencies: ["SwiftNestKit"]),
        .target(name: "SwiftNestKit",
            dependencies: ["Transformers", "SourceKittenFramework"]),
    ]
)
