import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

/// `#doubled(n)` expands to `((n) * 2)`. Its only job is to put swift-syntax in the graph.
public struct DoubledMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        "((\(node.arguments.first!.expression)) * 2)"
    }
}

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [DoubledMacro.self]
}
