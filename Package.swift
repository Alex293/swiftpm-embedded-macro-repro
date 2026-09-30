// swift-tools-version: 6.4
//
// Minimal reproducer: a bare-metal firmware package (armv7em-none-none-eabi,
// Embedded Swift) whose dependency graph contains a macro plugin. All the
// Embedded, C and linker flags live in toolset.json (rendered by render.sh),
// not in this manifest, so that they are scoped to the destination build.
//
// Four targets:
//   Macros    a .macro target (host tool, depends on swift-syntax)
//   Lib       a library that declares and uses the macro
//   Support   C: vector table, reset handler, putchar, _exit
//   Firmware  the executable that prints a banner and #doubled(21)
//
// The two traits are incidental (a mutually exclusive variant switch); they
// only show that the trait is passed through. `--traits VariantA` is enough.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swiftpm-embedded-macro-repro",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Firmware", targets: ["Firmware"]),
    ],
    traits: [
        .trait(name: "VariantA", description: "Firmware banner variant A"),
        .trait(name: "VariantB", description: "Firmware banner variant B"),
    ],
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
        .target(name: "Lib", dependencies: ["Macros"]),
        .target(name: "Support"),
        .executableTarget(name: "Firmware", dependencies: ["Lib", "Support"]),
    ],
    swiftLanguageModes: [.v6]
)
