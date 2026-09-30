#!/bin/sh
# Summarises a verbose build log: which modules were planned for which
# architecture, which -target triples the compile lines carry, and where the
# toolset's flags landed. Usage: ./analyze.sh logs/swiftbuild.log
set -eu
LOG="${1:?usage: $0 <log>}"

echo "== exit line"
grep -E '^== exit' "$LOG" || true

echo "== Planning lines by architecture"
grep -oE 'Planning [A-Za-z ]+ module [A-Za-z0-9_]+ \([a-z0-9_]+\)' "$LOG" | sort | uniq -c | sort -rn || true

echo "== -target values on compile lines"
grep -oE -- '-target [a-z0-9_.-]+' "$LOG" | sort | uniq -c || true

echo "== lines mentioning a host destination (arm64-apple, (arm64), -tool build dirs)"
grep -cE 'arm64-apple|\(arm64\)|Macros-tool' "$LOG" || true

echo "== compile lines carrying the Embedded flag, by -module-name"
grep -- 'enable-experimental-feature Embedded' "$LOG" | grep -oE -- '-module-name [A-Za-z0-9_]+' | sort | uniq -c || true

echo "== Support.c (root C target) compile line: target and toolset C flags present?"
grep -E 'clang .*Sources/Support/Support\.c' "$LOG" | head -1 | grep -oE -- '(-target [a-z0-9_.-]+|-isysroot [^ ]+|-mthumb|-nostdlib|-Werror|-Wall|-I[^ ]*clang-runtimes[^ ]*|@[^ ]+common-args|-fno-common|-fno-stack-protector)' | sort -u || true

echo "== _SwiftSyntaxCShims (PlatformMutex.c) compile line: target and flags present?"
grep -E 'clang .*PlatformMutex\.c' "$LOG" | head -1 | grep -oE -- '(-target [a-z0-9_.-]+|-isysroot [^ ]+|-mthumb|-nostdlib|-Werror|-Wall|-I[^ ]*clang-runtimes[^ ]*|@[^ ]+common-args|-fno-common|-fno-stack-protector)' | sort -u || true

echo "== distinct error lines"
grep -E 'error' "$LOG" | grep -vE 'SwiftDriver|builtin-|Using response|^ *cd |clang -x' | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c || true
