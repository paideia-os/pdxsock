#!/usr/bin/env bash
# Per-repo build script. Mirrors tools/user/mkfs.pdxfs/tools/build.sh
# in the paideia-os monorepo (paideia-os issues #1976/#1977 --
# satellite-tool /bin seeding pipeline). Runs paideia-as build over
# every .pdx source, then links this repo's own objects (plus any
# --extra-obj-dir objects) into a flat ELF via `ld -T link.ld`.
#
# Resolves paideia-as via (in order):
#   1. $PAIDEIA_AS env var
#   2. paideia-os checkout sibling to this repo:
#      ../paideia-os/tools/paideia-as/target/release/paideia-as
#   3. $HOME/Development/PaideiaOS/tools/paideia-as/target/release/paideia-as
#   4. paideia-as on $PATH (must be >= 0.36.0)
#
# Requires paideia-as >= 0.36.0 (v1.1-A: real socket syscall bodies
# exercise mov_b + xor+cmp + rip-relative lea patterns that shipped
# stable in 0.36).
#
# Usage:
#   tools/build.sh [--extra-obj-dir DIR]... [--extra-archive PATH]...

set -euo pipefail
cd "$(dirname "$0")/.."

EXTRA_OBJECTS=()
EXTRA_ARCHIVES=()
OWN_OBJECTS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --extra-obj-dir)
            [ "$#" -ge 2 ] || { echo "[build] FAIL: --extra-obj-dir requires an argument" >&2; exit 2; }
            extra_dir="$2"
            shift 2
            shopt -s nullglob
            for obj in "$extra_dir"/*.o; do
                [ -f "$obj" ] && EXTRA_OBJECTS+=("$obj")
            done
            shopt -u nullglob
            ;;
        --extra-archive)
            [ "$#" -ge 2 ] || { echo "[build] FAIL: --extra-archive requires an argument" >&2; exit 2; }
            EXTRA_ARCHIVES+=("$2")
            shift 2
            ;;
        *)
            echo "[build] FAIL: unrecognized argument: $1" >&2
            exit 2
            ;;
    esac
done

MIN_VERSION="0.36.0"

resolve_paideia_as() {
    if [ -n "${PAIDEIA_AS:-}" ] && [ -x "$PAIDEIA_AS" ]; then
        echo "$PAIDEIA_AS"; return
    fi
    for cand in \
        "../paideia-os/tools/paideia-as/target/release/paideia-as" \
        "$HOME/Development/PaideiaOS/tools/paideia-as/target/release/paideia-as"
    do
        if [ -x "$cand" ]; then
            echo "$cand"; return
        fi
    done
    if command -v paideia-as >/dev/null 2>&1; then
        command -v paideia-as; return
    fi
    return 1
}

version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

PA="$(resolve_paideia_as || true)"
if [ -z "$PA" ]; then
    echo "[build] FAIL: paideia-as not found. Set PAIDEIA_AS or clone paideia-os as a sibling." >&2
    exit 2
fi
VER="$("$PA" --version | awk '{print $2}')"
if ! version_ge "$VER" "$MIN_VERSION"; then
    echo "[build] FAIL: paideia-as $VER is too old, need >= $MIN_VERSION (found $PA)" >&2
    exit 2
fi
echo "[build] paideia-as $VER at $PA"

BUILD_DIR="build-out"
mkdir -p "$BUILD_DIR"

FAIL=0
COUNT=0
for pdx in src/*.pdx; do
    [ -f "$pdx" ] || continue
    COUNT=$((COUNT + 1))
    obj="$BUILD_DIR/$(basename "$pdx" .pdx).o"
    OWN_OBJECTS+=("$obj")
    if ! "$PA" build --emit elf64 "$pdx" -o "$obj" 2>&1; then
        FAIL=$((FAIL + 1))
    fi
done

if [ -d tests ]; then
    for pdx in tests/*.pdx; do
        [ -f "$pdx" ] || continue
        COUNT=$((COUNT + 1))
        obj="$BUILD_DIR/tests-$(basename "$pdx" .pdx).o"
        if ! "$PA" build --emit elf64 "$pdx" -o "$obj" 2>&1; then
            FAIL=$((FAIL + 1))
        fi
    done
fi

echo "[build] $COUNT source(s), $FAIL failure(s)"
[ "$FAIL" -eq 0 ] || exit 1
echo "[build] OK"

if [ "$FAIL" -eq 0 ] && [ "${#OWN_OBJECTS[@]}" -gt 0 ]; then
    echo "[link] ld -T link.ld -> $BUILD_DIR/pdxsock.elf"
    ld -nostdlib --warn-common --fatal-warnings --gc-sections \
        -T link.ld \
        -o "$BUILD_DIR/pdxsock.elf" \
        "${OWN_OBJECTS[@]}" "${EXTRA_OBJECTS[@]}" "${EXTRA_ARCHIVES[@]}"
    echo "[link] OK -> $BUILD_DIR/pdxsock.elf"

    objcopy -O binary "$BUILD_DIR/pdxsock.elf" "$BUILD_DIR/pdxsock.bin"
    echo "[link] OK -> $BUILD_DIR/pdxsock.bin"
fi
