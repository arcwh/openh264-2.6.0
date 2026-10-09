#!/bin/bash
set -euo pipefail

# ============================================================
# OpenH264 2.6.0 Android build script (v2)
#
# Put this script in the root directory of openh264-2.6.0:
#   chmod +x build_openh264_android_v2.sh
#   ./build_openh264_android_v2.sh
#
# Output:
#   android/armeabi-v7a/
#   android/arm64-v8a/
#
# Important:
#   This version DOES NOT call OpenH264's Android "make clean"
#   target, because that target invokes ndk-build/Gradle and may
#   trigger the quarantined NDK bundled make on macOS.
# ============================================================

NDK="/Users/anathan/Documents/android-ndk-r28c"
API=23
TARGET="android-${API}"

# Force the top-level GNU Make to macOS system make.
MAKE_BIN="/usr/bin/make"
export GNUMAKE="$MAKE_BIN"
export MAKE="$MAKE_BIN"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/android"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# ------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------
if [ ! -f "$ROOT_DIR/Makefile" ]; then
    echo "ERROR: Makefile not found: $ROOT_DIR/Makefile"
    echo "Put this script in the OpenH264 source root."
    exit 1
fi

if [ ! -f "$ROOT_DIR/codec/api/wels/codec_api.h" ]; then
    echo "ERROR: OpenH264 headers not found."
    echo "Expected: $ROOT_DIR/codec/api/wels/codec_api.h"
    exit 1
fi

if [ ! -d "$NDK" ]; then
    echo "ERROR: Android NDK not found: $NDK"
    exit 1
fi

if [ ! -x "$MAKE_BIN" ]; then
    echo "ERROR: GNU Make not executable: $MAKE_BIN"
    exit 1
fi

if [ ! -d "$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin" ]; then
    echo "ERROR: NDK LLVM toolchain not found."
    echo "Expected: $NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

# ------------------------------------------------------------
# Clean only OpenH264 build artifacts.
#
# Do NOT use:
#   make OS=android ... clean
#
# OpenH264's Android clean target invokes ndk-build and Gradle.
# We only need to remove ABI-dependent object/library files before
# switching from arm -> arm64.
# ------------------------------------------------------------
clean_build_artifacts() {
    echo "Cleaning previous OpenH264 build artifacts..."

    find "$ROOT_DIR/codec" -type f \
        \( -name '*.o' -o -name '*.d' -o -name '*.obj' \) \
        -delete 2>/dev/null || true

    find "$ROOT_DIR/module" -type f \
        \( -name '*.o' -o -name '*.d' -o -name '*.obj' \) \
        -delete 2>/dev/null || true

    find "$ROOT_DIR/test" -type f \
        \( -name '*.o' -o -name '*.d' -o -name '*.obj' \) \
        -delete 2>/dev/null || true

    rm -f \
        "$ROOT_DIR"/*.a \
        "$ROOT_DIR"/*.so \
        "$ROOT_DIR"/*.so.* \
        "$ROOT_DIR"/*.dylib \
        "$ROOT_DIR"/*.pc \
        "$ROOT_DIR"/*.map \
        "$ROOT_DIR"/*.res \
        "$ROOT_DIR/codec/common/inc/version_gen.h" \
        2>/dev/null || true
}

build_for_abi() {
    local ABI="$1"
    local ARCH
    local PREFIX="$OUTPUT_DIR/$ABI"

    case "$ABI" in
        armeabi-v7a)
            ARCH="arm"
            ;;
        arm64-v8a)
            ARCH="arm64"
            ;;
        *)
            echo "ERROR: Unsupported ABI: $ABI"
            exit 1
            ;;
    esac

    echo
    echo "============================================================"
    echo "Building OpenH264 2.6.0"
    echo "ABI       : $ABI"
    echo "ARCH      : $ARCH"
    echo "API       : $API"
    echo "NDK       : $NDK"
    echo "PREFIX    : $PREFIX"
    echo "MAKE      : $MAKE_BIN"
    echo "GNUMAKE   : $GNUMAKE"
    echo "============================================================"

    clean_build_artifacts
    rm -rf "$PREFIX"

    # Build + install libraries/headers/pkg-config metadata only.
    # The 'install' target does NOT require Android demo APKs or unit tests.
    "$MAKE_BIN" -j"$JOBS" \
        OS=android \
        NDKROOT="$NDK" \
        TARGET="$TARGET" \
        NDKLEVEL="$API" \
        ARCH="$ARCH" \
        PREFIX="$PREFIX" \
        BUILDTYPE=Release \
        V=No \
        install

    # --------------------------------------------------------
    # Verify expected output
    # --------------------------------------------------------
    if [ ! -f "$PREFIX/lib/libopenh264.so" ]; then
        echo "ERROR: Missing $PREFIX/lib/libopenh264.so"
        exit 1
    fi

    if [ ! -f "$PREFIX/lib/libopenh264.a" ]; then
        echo "ERROR: Missing $PREFIX/lib/libopenh264.a"
        exit 1
    fi

    if [ ! -f "$PREFIX/include/wels/codec_api.h" ]; then
        echo "ERROR: Missing installed OpenH264 headers"
        exit 1
    fi

    if [ ! -f "$PREFIX/lib/pkgconfig/openh264.pc" ]; then
        echo "ERROR: Missing $PREFIX/lib/pkgconfig/openh264.pc"
        exit 1
    fi

    echo
    echo "SUCCESS: $ABI"
    echo "  Shared : $PREFIX/lib/libopenh264.so"
    echo "  Static : $PREFIX/lib/libopenh264.a"
    echo "  Headers: $PREFIX/include/wels"
    echo "  pkgconf: $PREFIX/lib/pkgconfig/openh264.pc"
}

ABIS=("armeabi-v7a" "arm64-v8a")

for ABI in "${ABIS[@]}"; do
    build_for_abi "$ABI"
done

# Clean source tree artifacts after the last ABI as well.
clean_build_artifacts

echo
echo "============================================================"
echo "All OpenH264 Android builds completed successfully."
echo "Output directory: $OUTPUT_DIR"
echo
find "$OUTPUT_DIR" -maxdepth 4 -type f \
    \( -name 'libopenh264.so' \
       -o -name 'libopenh264.a' \
       -o -name 'openh264.pc' \
       -o -name 'codec_api.h' \) \
    -print | sort
echo "============================================================"
