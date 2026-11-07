#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -eq 0 ]] || die 'Usage: package.sh'
load_build
cd "$PROJECT_ROOT"
[[ $(manifest_value SourceDirty) == false ]] || die 'Commit source changes and rebuild before packaging.'
revision=$(manifest_value SourceRevision)
[[ $(git rev-parse HEAD) == "$revision" ]] || die 'Source revision changed; rebuild first.'
[[ -z $(git status --porcelain --untracked-files=normal) ]] || die 'Commit source changes and rebuild before packaging.'

output="$PROJECT_ROOT/dist/release/$BUILD_VERSION/darwin-$BUILD_ARCH"
[[ ! -e $output ]] || die "Release directory already exists: $output"
mkdir -p "$(dirname "$output")"
stage=$(mktemp -d "$(dirname "$output")/.package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
source_name="forgejo-runner-$BUILD_VERSION-source.tar.gz"
cp "$BUILD_EXECUTABLE" "$stage/$BUILD_NAME"
cp "$BUILD_MANIFEST" "$stage/build-manifest.json"
git show "$revision:LICENSE" > "$stage/LICENSE.txt"
# Archive committed files only, never local credentials, caches or runtime data.
git archive --format=tar "--prefix=forgejo-runner-$BUILD_VERSION/" "$revision" | gzip -n > "$stage/$source_name"
(
    cd "$stage"
    shasum -a 256 "$BUILD_NAME" build-manifest.json "$source_name" LICENSE.txt > SHA256SUMS
)
mv "$stage" "$output"
printf 'Release files: %s\n' "$output"
