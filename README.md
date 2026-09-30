# swiftpm-embedded-macro-repro

Minimal reproducer for a Swift Package Manager problem: a bare-metal
Embedded Swift firmware package (`--triple armv7em-none-none-eabi
--toolset toolset.json`, Cortex-M7) whose dependency graph contains a
**macro plugin** builds with `--build-system native` and fails with the
default build system (Swift Build).

Related upstream issues:

- swiftlang/swift-package-manager#10588 — Swift Build builds host-only
  helpers for the destination under a `--triple` build.
- swiftlang/swift-package-manager#10524 — swift-embedded-examples do not
  build with swiftbuild (`unable to load standard library`).
- swiftlang/swift-package-manager#10206 / #10222, fixed by PR #10207 —
  toolset flags reaching macro targets (toolsets now apply to the
  destination only).

## What is in the package

| Target     | Kind                | Role |
|------------|---------------------|------|
| `Macros`   | `.macro`            | Host tool. One freestanding expression macro `#doubled(n)`; depends on swift-syntax `603.0.1..<604.0.0`. |
| `Lib`      | library             | Declares the macro and calls it (`#doubled(21)`). Compiled for the firmware. |
| `Support`  | C                   | Cortex-M vector table, reset handler, `putchar` (volatile store), `_exit`. Includes `<unistd.h>` from picolibc. Guarded by `__ARM_ARCH_7EM__` so it compiles for the host too. |
| `Firmware` | executable          | `@main`; prints a banner and `#doubled(21)` through `putchar`, then loops. |

Two traits, `VariantA` and `VariantB`, select the banner; exactly one
must be enabled. They are incidental to the bug (`--traits VariantA` is
all the commands below need).

No Embedded, C or linker flag is in `Package.swift`: they all live in
`toolset.json` (rendered from `toolset.json.in` with absolute paths).
`_Concurrency` is not imported and the Swift Concurrency runtime is not
linked.

## Prerequisites

1. **Swift toolchain** `swift-DEVELOPMENT-SNAPSHOT-2026-09-21-a`
   (`Apple Swift version 6.5-dev (LLVM a0a7653f4c0c1a0, Swift ac2207a7efaa55c)`,
   SwiftPM `Swift 6.5.0-dev`), on macOS:

   ```sh
   swiftly install main-snapshot-2026-09-21
   ```

   `.swift-version` pins it, so `~/.swiftly/bin/swift` picks it up in
   this directory.

2. **LLVM Embedded Toolchain for Arm 19.1.5**, for the picolibc headers
   and the link step only. Download
   `LLVM-ET-Arm-19.1.5-Darwin-universal.dmg` from the GitHub release
   [`release-19.1.5`](https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases/tag/release-19.1.5),
   open it and copy the `LLVM-ET-Arm-19.1.5-Darwin-universal` folder
   somewhere (next to this README, or anywhere and point `LLVM_ET` at it).

3. Render the toolset (SwiftPM resolves a toolset's relative paths
   against the working directory, so the paths are made absolute):

   ```sh
   LLVM_ET=/path/to/LLVM-ET-Arm-19.1.5-Darwin-universal ./render.sh
   ```

## The two commands

Same package, same arguments, only the build system differs. Separate
scratch paths keep the two from sharing intermediates.

```sh
# 1. native build system: succeeds (exit 0; ~4 min cold, swift-syntax from source)
swift build --configuration release --scratch-path .build/native --triple armv7em-none-none-eabi \
    --toolset toolset.json --product Firmware --traits VariantA --verbose --build-system native

# 2. default build system (Swift Build): fails (exit 1; ~3 s, never reaches the firmware target)
swift build --configuration release --scratch-path .build/swiftbuild --triple armv7em-none-none-eabi \
    --toolset toolset.json --product Firmware --traits VariantA --verbose
```

`./build.sh native` and `./build.sh swiftbuild` run exactly these into
`logs/<name>.log`; `./analyze.sh logs/<name>.log` summarises a log
(planned modules per architecture, `-target` values, where the toolset's
C flags landed).

## Observed results (2026-09-30, macOS 27.0, Xcode 27 SDK)

### 1. `--build-system native`: exit 0

Cold build 3 min 56 s. Compile invocations by `-target`: 37 ×
`arm64-apple-macosx12.0` (swift-syntax), 5 × `arm64-apple-macosx15.0`
(`Macros` and the manifest), 6 × `armv7em-none-none-eabi` (`Lib`,
`Firmware`, `Support`). Lines carrying `-enable-experimental-feature
Embedded`: `Firmware` 3, `Lib` 2, nothing else. The plugin is built at
`.build/native/arm64-apple-macosx/release/Macros-tool` and loaded with
`-load-plugin-executable …/arm64-apple-macosx/release/Macros-tool#Macros`.
The root C target's compile line carries the toolset's C flags
(`-nostdlib … -I<LLVM-ET>/lib/clang-runtimes/…/include -mthumb -Werror
-Wall … -fno-common`).

```
$ llvm-objcopy -O binary .build/native/armv7em-none-none-eabi/release/Firmware Firmware.bin
$ llvm-strings Firmware.bin | grep REPRO-BANNER
REPRO-BANNER-VARIANT-A
$ llvm-size .build/native/armv7em-none-none-eabi/release/Firmware
   text	   data	    bss	    dec	    hex	filename
   1536	    928	      0	   2464	    9a0	.build/native/armv7em-none-none-eabi/release/Firmware
```

The deprecation warning, printed once per build:

```
warning: '--build-system native' has been deprecated and will be removed in a future release; please report an issue at https://github.com/swiftlang/swift-package-manager/issues if you are unable to adopt the default build system.
```

### 2. Swift Build (default): exit 1 after ~3 s

Two independent failures, both before the firmware target is reached.
Whether the toolset's *Swift* flags reach `Firmware` correctly under
Swift Build is unknown: the build never gets there.

**(a) The macro plugin and its swift-syntax dependencies are planned in
the firmware destination; there is no host-tool destination.** The
target dependency graph (25 targets) lists `Macros` as an explicit
dependency of `Firmware-product` and `Lib`, and swift-syntax's 21
targets below it, all in one armv7em graph. Every compile line in the
log is either a manifest compile or armv7em; there is no `-tool`
build directory and no `(arm64)` task. `-target` values on compile
lines: 13 × `armv7em-none-macos12.0-eabi`, 2 × `armv7em-none-none-eabi`
(`Support`), 2 × `arm64-apple-macosx15.0` (`Package.swift`).

The six `SwiftSyntax5xx/6xx` version-marker modules are planned
`(armv7em)` with the **toolset's Swift flags**, the macOS SDK and the
malformed triple `armv7em-none-macos12.0-eabi`, and each fails:

```
Planning Swift module SwiftSyntax509 (armv7em)
    cd <repo>/..
    builtin-SwiftDriver -- <toolchain>/usr/bin/swiftc -parse-as-library -module-name SwiftSyntax509 -O -whole-module-optimization @<repo>/.build/swiftbuild/out/Intermediates.noindex/swift-syntax.build/Release/SwiftSyntax509-t.build/Objects-normal/armv7em/SwiftSyntax509.SwiftFileList -DSWIFT_PACKAGE -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -DXcode -Osize -Xfrontend -disable-stack-protector -enable-experimental-feature Embedded -enable-experimental-feature Extern -Xclang-linker -nostdlib -Xfrontend -function-sections -Xfrontend -enable-single-module-llvm-emission -assert-config Debug -Xclang-linker -fuse-ld\=lld … -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk -target armv7em-none-macos12.0-eabi -g … 
error: unable to resolve module dependency: 'Swift'
info: a dependency of main module 'SwiftSyntax509'
error: SwiftDriver SwiftSyntax509 normal armv7em com.apple.xcode.tools.swift.compiler failed with a nonzero exit code.
```

(Under `native` the same modules are compiled for `arm64-apple-macosx12.0`
with none of these flags.) swift-syntax's C shim `PlatformMutex.c` is
compiled `(armv7em)` with the same triple against the macOS SDK; in an
incremental run it got far enough to fail with
`PlatformMutex.c:24:10: fatal error: 'os/lock.h' file not found`.

**(b) The toolset's `cCompiler.extraCLIOptions` land on the wrong C
target.** The root package's own C target `Support` is compiled with the
correct `-target armv7em-none-none-eabi` but with none of the toolset's C
flags (no picolibc `-I`, no `-mthumb -nostdlib -Werror -Wall …`;
`-isysroot /` instead), so:

```
Compile Support.c (armv7em)
    <toolchain>/usr/bin/clang -x c -target armv7em-none-none-eabi … -isysroot / … @<repo>/.build/swiftbuild/out/Intermediates.noindex/swiftpm-embedded-macro-repro.build/Release-none-armv7em/Support-t.build/Objects-normal/armv7em/…-common-args.resp …
<repo>/Sources/Support/Support.c:15:10: fatal error: 'unistd.h' file not found
   15 | #include <unistd.h>  // picolibc: declares _exit; found via the toolset's -I
error: CompileC …/Support-t.build/Objects-normal/armv7em/Support.o <repo>/Sources/Support/Support.c normal armv7em c com.apple.compilers.llvm.clang.1_0.compiler failed with a nonzero exit code.
```

The very same flags are in the response file of swift-syntax's
`_SwiftSyntaxCShims` target (a dependency of the host plugin), compiled
for `armv7em-none-macos12.0-eabi` against the macOS SDK:

```
$ tr ' ' '\n' < .build/swiftbuild/out/Intermediates.noindex/swift-syntax.build/Release/_SwiftSyntaxCShims-t.build/Objects-normal/armv7em/*-common-args.resp | grep -E '^-(nostdlib|mthumb|static|fno-|ffunction|fdata|I.*clang-runtimes)'
-nostdlib
-ffunction-sections
-fdata-sections
-I<LLVM-ET>/lib/clang-runtimes/arm-none-eabi/armv7m_soft_fpv4_sp_d16_exn_rtti/include
-mthumb
-static
-fno-stack-protector
-fno-common
$ tr ' ' '\n' < .build/swiftbuild/out/Intermediates.noindex/swiftpm-embedded-macro-repro.build/Release-none-armv7em/Support-t.build/Objects-normal/armv7em/*-common-args.resp | grep -E '^-(nostdlib|mthumb|static|fno-|ffunction|fdata|I.*clang-runtimes)'
(nothing)
```

(`-Werror -Wall` from the toolset are on `_SwiftSyntaxCShims`'s command
line rather than in its response file.) Inverted on both counts; this
half does not need the macro to reproduce.

## Files

- `Package.swift` — tools-version 6.4, `import CompilerPluginSupport`.
- `toolset.json.in`, `render.sh` — the toolset (Swift, C and linker
  flags) with `@ROOT@` / `@LLVM_ET@` placeholders.
- `linkerscript.ld` — minimal Cortex-M7 layout (flash `0x08000000`, RAM
  `0x20000000`).
- `build.sh`, `analyze.sh` — the two commands and a log summary.
- `.swift-version` — pins the snapshot for swiftly.
