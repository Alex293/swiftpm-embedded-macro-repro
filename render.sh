#!/bin/sh
# Renders toolset.json from toolset.json.in with absolute paths.
#
# SwiftPM resolves a toolset's relative paths against the current working
# directory, not the toolset file, so the paths are rendered absolute.
#
#   LLVM_ET   path to the LLVM Embedded Toolchain for Arm 19.1.5 (the folder
#             that contains bin/ and lib/clang-runtimes/). Default: a copy
#             of the release DMG's folder next to this script.

set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
LLVM_ET="${LLVM_ET:-$ROOT/LLVM-ET-Arm-19.1.5-Darwin-universal}"

if [ ! -d "$LLVM_ET/lib/clang-runtimes/arm-none-eabi" ]; then
    echo "LLVM Embedded Toolchain for Arm not found at $LLVM_ET; set LLVM_ET (see README.md)" >&2
    exit 1
fi

sed -e "s|@ROOT@|$ROOT|g; s|@LLVM_ET@|$LLVM_ET|g" "$ROOT/toolset.json.in" > "$ROOT/toolset.json"
echo "rendered $ROOT/toolset.json (LLVM_ET=$LLVM_ET)"
