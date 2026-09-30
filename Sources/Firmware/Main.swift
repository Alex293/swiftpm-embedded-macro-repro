@freestanding(expression)
macro doubled(_ n: Int) -> Int = #externalMacro(module: "Macros", type: "DoubledMacro")

@main
struct Main {
    static func main() {
        print("REPRO-BANNER")  // Embedded Swift's print writes through putchar (Support.c)
        print(#doubled(21))
    }
}
