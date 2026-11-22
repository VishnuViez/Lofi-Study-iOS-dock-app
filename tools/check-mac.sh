#!/bin/zsh
# Type-checks the app's shared sources, runs the Swift Testing suite and
# renders preview images/audio, all on macOS with only the Command Line Tools.
# (SwiftPM is not used: `swift test` fails to link its manifest on this CLT.)
#
#   tools/check-mac.sh [output-dir]
#
# Everything except LofiDockApp.swift is compiled, so iOS-only code must sit
# behind `#if os(iOS)` / `#if canImport(UIKit)`.
set -euo pipefail

ROOT=${0:A:h:h}
# Output and module cache stay inside the project (on the external drive);
# the internal disk on this Mac is small.
OUT=${1:-$ROOT/build/mac-check}
CLT=/Library/Developer/CommandLineTools
FW=$CLT/Library/Developer/Frameworks
TARGET=arm64-apple-macosx14.0
# The macOS 27 SDK turns @State into a macro whose plugin (SwiftUIMacros) ships
# only with Xcode, so prefer the 26 SDK, where @State is a plain property wrapper.
SDK=$CLT/SDKs/MacOSX26.sdk
[[ -d $SDK ]] || SDK=$(xcrun --show-sdk-path)
mkdir -p "$OUT"

SOURCES=( ${(f)"$(find "$ROOT/LofiDock" -name '*.swift' ! -name 'LofiDockApp.swift' | sort)"} )
TESTS=( "$ROOT"/LofiDockTests/*.swift )
COMMON=( -swift-version 5 -sdk "$SDK" -target $TARGET -parse-as-library -module-cache-path "$OUT/ModuleCache" )

echo "==> Building LofiDock module (${#SOURCES} files)"
swiftc $COMMON -O -module-name LofiDock -enable-testing -emit-library \
  -emit-module -emit-module-path "$OUT/LofiDock.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLofiDock.dylib \
  "${SOURCES[@]}" -o "$OUT/libLofiDock.dylib"

echo "==> Building and running tests"
swiftc $COMMON -I "$OUT" -L "$OUT" -lLofiDock -F "$FW" \
  -plugin-path "$CLT/usr/lib/swift/host/plugins/testing" \
  -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$CLT/Library/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$OUT" \
  "${TESTS[@]}" "$ROOT/tools/TestRunner.swift" -o "$OUT/run-tests"
"$OUT/run-tests"

echo "==> Rendering previews"
swiftc $COMMON -O -module-name MacPreview "${SOURCES[@]}" "$ROOT/tools/MacPreview/main.swift" -o "$OUT/mac-preview"
"$OUT/mac-preview" "$OUT" "$ROOT/LofiDock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" 
