// A library compiled for the firmware destination (armv7em, Embedded Swift)
// that uses the host-built macro. The macro expands at compile time; nothing
// of swift-syntax may reach this target's build.

@freestanding(expression)
public macro doubled(_ value: Int) -> Int = #externalMacro(module: "Macros", type: "DoubledMacro")

/// 42, via the macro. Kept opaque so the constant survives to the image.
public func doubledTwentyOne() -> Int {
    #doubled(21)
}
