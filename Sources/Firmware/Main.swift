// The firmware executable. It prints a trait-selected banner and the
// macro-expanded constant through `putchar` (Support), then loops forever.
// The image is only linked, never run; `putchar` does a volatile store so
// the optimizer keeps the print loop and the banner bytes at -Osize.

import Lib
import Support

#if VariantA && VariantB
#error("VariantA and VariantB are mutually exclusive; enable one trait")
#elseif VariantA
let banner: StaticString = "REPRO-BANNER-VARIANT-A"
#elseif VariantB
let banner: StaticString = "REPRO-BANNER-VARIANT-B"
#else
#error("enable exactly one of the traits VariantA or VariantB")
#endif

@main
struct Main {
    static func main() {
        let base = banner.utf8Start
        for i in 0..<banner.utf8CodeUnitCount {
            _ = putchar(CInt(base[i]))
        }
        _ = putchar(CInt(UInt8(ascii: " ")))
        // The macro-expanded constant (42), so the Lib object is linked.
        let value = doubledTwentyOne()
        _ = putchar(CInt(UInt8(ascii: "0")) + CInt(value / 10))
        _ = putchar(CInt(UInt8(ascii: "0")) + CInt(value % 10))
        _ = putchar(10)
        while true {}
    }
}
