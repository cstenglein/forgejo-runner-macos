#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared helpers. Compatible with the Bash 3.2 shipped by macOS.

MACOS_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$MACOS_SCRIPT_DIR/../.." && pwd)
BUILD_DIR="$PROJECT_ROOT/dist/macos"
BUILD_MANIFEST="$BUILD_DIR/build-manifest.json"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_macos() {
    [[ $(uname -s) == Darwin ]] || die 'This script requires macOS.'
}

validate_version() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die 'Invalid version.'
}

prepare_go() {
    require_macos
    command -v go >/dev/null || die 'Install Go first.'
    # Use the upstream toolchain unless explicitly overridden by the caller.
    GOTOOLCHAIN=${GOTOOLCHAIN:-$(awk '$1 == "toolchain" {print $2; exit}' "$PROJECT_ROOT/go.mod")}
    [[ -n $GOTOOLCHAIN ]] || die 'No toolchain found in go.mod.'
    export GOTOOLCHAIN
    GOARCH=$(go env GOHOSTARCH)
    case "$GOARCH" in arm64|amd64) ;; *) die "Unsupported architecture: $GOARCH" ;; esac
    # Do not inherit Linux-oriented build tags or force the pure-Go DNS resolver.
    GOOS=darwin
    CGO_ENABLED=1
    GOFLAGS=''
    export GOOS GOARCH CGO_ENABLED GOFLAGS
}

manifest_value() {
    /usr/bin/plutil -extract "$1" raw -o - "$BUILD_MANIFEST"
}

load_build() {
    require_macos
    [[ -f $BUILD_MANIFEST ]] || die 'Build first: ./contrib/macos/build.sh'
    BUILD_VERSION=$(manifest_value Version)
    validate_version "$BUILD_VERSION"
    BUILD_ARCH=$(manifest_value Architecture)
    case "$BUILD_ARCH" in arm64|amd64) ;; *) die 'Invalid build architecture.' ;; esac
    BUILD_NAME="forgejo-runner-$BUILD_VERSION-darwin-$BUILD_ARCH"
    [[ $(manifest_value Binary) == "$BUILD_NAME" ]] || die 'Unexpected binary name in manifest.'
    BUILD_EXECUTABLE="$BUILD_DIR/$BUILD_NAME"
    [[ -x $BUILD_EXECUTABLE ]] || die 'Build executable is missing.'
    [[ $(shasum -a 256 "$BUILD_EXECUTABLE" | awk '{print $1}') == "$(manifest_value BinarySHA256)" ]] || die 'Binary checksum mismatch.'
}
