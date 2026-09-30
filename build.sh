#!/bin/sh
# Runs the firmware build with one build system, verbose, into logs/<name>.log,
# and prints the exit status. Separate scratch paths so the two build systems
# never share intermediate files.
#
#   ./build.sh native       swift build ... --build-system native   (expected: exit 0)
#   ./build.sh swiftbuild   swift build ...                          (Swift Build, the default; observed: exit 1)
#
# Requires toolset.json (./render.sh) and swift from swiftly's bin directory
# (the toolchain is pinned by .swift-version).

set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
SWIFT="${SWIFTLY_BIN_DIR:-$HOME/.swiftly/bin}/swift"
NAME="${1:-}"
LOG="$ROOT/logs/$NAME.log"
mkdir -p "$ROOT/logs"

case "$NAME" in
native)     EXTRA="--build-system native" ;;
swiftbuild) EXTRA="" ;;
*) echo "usage: $0 native|swiftbuild" >&2; exit 2 ;;
esac

# CLEAN=1 removes the build products of that scratch path (the swift-syntax
# checkout stays) so the log covers the whole plan.
if [ "${CLEAN:-0}" = "1" ]; then
    rm -rf "$ROOT/.build/$NAME/out" "$ROOT/.build/$NAME/arm64-apple-macosx" \
           "$ROOT/.build/$NAME/armv7em-none-none-eabi" "$ROOT/.build/$NAME/release"
fi

set +e
# shellcheck disable=SC2086
"$SWIFT" build --configuration release --scratch-path "$ROOT/.build/$NAME" \
    --triple armv7em-none-none-eabi --toolset "$ROOT/toolset.json" \
    --product Firmware --traits VariantA --verbose $EXTRA > "$LOG" 2>&1
STATUS=$?
set -e
echo "== exit $STATUS" | tee -a "$LOG"
echo "log: $LOG ($(wc -l < "$LOG" | tr -d ' ') lines)"
exit "$STATUS"
