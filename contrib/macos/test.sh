#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -le 1 ]] || die 'Usage: test.sh [https://instance.example/api/v1/version]'
load_build
prepare_go
[[ $BUILD_ARCH == "$GOARCH" ]] || die 'Run tests on the architecture that built the binary.'
cd "$PROJECT_ROOT"
[[ $(git rev-parse HEAD) == "$(manifest_value SourceRevision)" ]] || die 'Source revision changed; rebuild first.'

# Upstream feature flags explicitly disable Docker and LXC tests.
go test -short ./... -args -features=-
"$BUILD_EXECUTABLE" validate --workflow --path "$MACOS_SCRIPT_DIR/smoke.yml"
"$BUILD_EXECUTABLE" validate --action --path "$MACOS_SCRIPT_DIR/smoke-action/action.yml"
"$BUILD_EXECUTABLE" exec --directory "$PROJECT_ROOT" --workflows "$MACOS_SCRIPT_DIR/smoke.yml" --image=-self-hosted --event workflow_dispatch
if [[ $# -eq 1 ]]; then
    go run "$MACOS_SCRIPT_DIR/dns-probe/main.go" "$1"
fi
