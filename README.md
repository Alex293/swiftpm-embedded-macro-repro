# swiftpm-embedded-macro-repro

A bare-metal Embedded Swift package (`--triple armv7em-none-none-eabi --toolset toolset.json`)
whose graph contains a **macro plugin** builds with `--build-system native` and fails under
Swift Build (the default). Data point for swiftlang/swift-package-manager#10588 and #10524;
related: #10206 / #10222 (fixed by #10207), #9638.

Three targets: `Macros` (`.macro`, swift-syntax 603), `Support` (C: `putchar`, `_exit`,
one picolibc include), `Firmware` (`@main`, declares and uses `#doubled(21)`). All Embedded,
C and linker flags are in `toolset.json`; the manifest has none.

## Setup

```sh
swiftly install main-snapshot-2026-09-21          # pinned by .swift-version
# LLVM Embedded Toolchain for Arm 19.1.5 (picolibc headers, libc, builtins for the link):
# https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases/tag/release-19.1.5
# -> LLVM-ET-Arm-19.1.5-Darwin-universal.dmg, copy the folder anywhere.
LLVM_ET=/path/to/LLVM-ET-Arm-19.1.5-Darwin-universal
sed "s|@LLVM_ET@|$LLVM_ET|g" toolset.json.in > toolset.json   # absolute paths on purpose
```

## Run

```sh
swift build -c release --scratch-path .build/native     --triple armv7em-none-none-eabi --toolset toolset.json --product Firmware --verbose --build-system native
swift build -c release --scratch-path .build/swiftbuild --triple armv7em-none-none-eabi --toolset toolset.json --product Firmware --verbose
```

## Observed (2026-09-30, macOS 27.0, `Apple Swift version 6.5-dev (LLVM a0a7653f4c0c1a0, Swift ac2207a7efaa55c)`, SwiftPM `Swift 6.5.0-dev`)

**native: exit 0** (~4 min cold). swift-syntax compiled for `arm64-apple-macosx12.0`, `Macros`
for `arm64-apple-macosx15.0`, `Firmware` and `Support` for `armv7em-none-none-eabi`; only the
armv7em lines carry `-enable-experimental-feature Embedded`; the plugin is loaded with
`-load-plugin-executable .build/native/arm64-apple-macosx/release/Macros-tool#Macros`.
`llvm-strings` finds `REPRO-BANNER` in the linked ELF (text 6448, data 20, bss 36).

**Swift Build: exit 1** in ~3 s, before `Firmware` is reached, two independent ways:

1. **No host destination.** The 24-target graph is planned once, for armv7em; `Macros` and the
   21 swift-syntax targets are in it. `-target` values on compile lines: 13 ×
   `armv7em-none-macos12.0-eabi`, 2 × `armv7em-none-none-eabi` (`Support`), none for the host.
   The swift-syntax modules get the toolset's Swift flags and the macOS SDK:

   ```
   Planning Swift module SwiftSyntax509 (armv7em)
       builtin-SwiftDriver -- …/swiftc -module-name SwiftSyntax509 … -Osize -enable-experimental-feature Embedded -Xfrontend -disable-stack-protector -Xclang-linker -nostdlib -Xclang-linker -fuse-ld=lld … -sdk …/MacOSX27.0.sdk -target armv7em-none-macos12.0-eabi …
   error: unable to resolve module dependency: 'Swift'
   error: SwiftDriver SwiftSyntax509 normal armv7em com.apple.xcode.tools.swift.compiler failed with a nonzero exit code.
   ```

   swift-syntax's `_SwiftSyntaxCShims/PlatformMutex.c` is compiled `(armv7em)` with the same
   triple (`'os/lock.h' file not found` when it gets that far).

2. **The toolset's `cCompiler.extraCLIOptions` land on the wrong C target.** `Support` gets
   `-target armv7em-none-none-eabi` but `-isysroot /` and none of the toolset's C flags; the
   flags are in `_SwiftSyntaxCShims`' response file instead
   (`…/swift-syntax.build/Release/_SwiftSyntaxCShims-t.build/Objects-normal/armv7em/*-common-args.resp`
   contains `-nostdlib -I<LLVM_ET>/…/include`; `…/Support-t.build/…/*-common-args.resp` does not).

   ```
   Sources/Support/Support.c:1:10: fatal error: 'unistd.h' file not found
   ```

   This half reproduces without the macro.

Whether the toolset's Swift flags would reach `Firmware` correctly under Swift Build is unknown:
the build never gets there.
