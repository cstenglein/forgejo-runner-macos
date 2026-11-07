#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -le 1 ]] || die 'Usage: build.sh [version]'
prepare_go
cd "$PROJECT_ROOT"
revision=$(git rev-parse HEAD)
version=${1:-13.2.1-dev.$(git rev-parse --short=8 HEAD)}
validate_version "$version"
binary="forgejo-runner-$version-darwin-$GOARCH"
module=$(awk '$1 == "module" {print $2; exit}' go.mod)
dirty=false
[[ -z $(git status --porcelain --untracked-files=normal) ]] || dirty=true

mkdir -p "$BUILD_DIR"
stage=$(mktemp -d "$BUILD_DIR/.build.XXXXXX")
trap 'rm -rf "$stage"' EXIT

# Compile this checkout. Neither netgo nor the static Linux linker flags apply.
go build -trimpath -ldflags "-s -w -X $module/internal/pkg/ver.version=v$version" -o "$stage/$binary" .
reported_version=$("$stage/$binary" --version)
[[ $reported_version == *"v$version"* ]] || die 'Binary reports an unexpected version.'

manifest="$stage/build-manifest.json"
# plutil cannot reliably edit JSON in place on all macOS versions. Populate an
# XML plist first, then convert the completed manifest to JSON.
/usr/bin/plutil -create xml1 "$manifest"
for key in Version Binary SourceRevision Architecture Go BuildTags BinarySHA256; do
    case "$key" in
        Version) value=$version ;;
        Binary) value=$binary ;;
        SourceRevision) value=$revision ;;
        Architecture) value=$GOARCH ;;
        Go) value=$(go version) ;;
        BuildTags) value='default (native macOS DNS)' ;;
        BinarySHA256) value=$(shasum -a 256 "$stage/$binary" | awk '{print $1}') ;;
    esac
    /usr/bin/plutil -insert "$key" -string "$value" "$manifest"
done
/usr/bin/plutil -insert SourceDirty -bool "$dirty" "$manifest"
/usr/bin/plutil -insert CGO -bool true "$manifest"
/usr/bin/plutil -convert json -r "$manifest"
mv "$stage/$binary" "$BUILD_DIR/$binary"
mv "$manifest" "$BUILD_MANIFEST"
printf '%s\nBuild output: %s\n' "$reported_version" "$BUILD_DIR/$binary"
