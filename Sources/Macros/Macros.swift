// The macro plugin. It is a host tool: it must be built for the host
// (arm64-apple-macosx) and loaded by the compiler while it compiles the
// firmware targets for armv7em. One trivial freestanding expression macro,
// `#doubled(n)`, expanding to `((n) * 2)`; its only job is to put
// swift-syntax into the package's dependency graph.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct DoubledMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("#doubled needs one argument")
        }
        return "((\(argument)) * 2)"
    }
}

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [DoubledMacro.self]
}
