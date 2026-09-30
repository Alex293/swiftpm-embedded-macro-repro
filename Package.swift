// swift-tools-version: 6.4
// Embedded, C and linker flags live in toolset.json (see README), not here.
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swiftpm-embedded-macro-repro",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.1"..<"604.0.0"),
    ],
    targets: [
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]),
        .target(name: "Support", publicHeadersPath: "."),  // C: putchar and _exit for picolibc
        .executableTarget(name: "Firmware", dependencies: ["Macros", "Support"]),
    ]
)
