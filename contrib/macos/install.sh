#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -le 1 ]] || die 'Usage: install.sh [/absolute/install/prefix]'
load_build
prefix=${1:-"$HOME/.local"}
[[ $prefix == /* ]] || die 'Installation prefix must be absolute.'
# Install the verified local binary only. Service setup is a separate operation.
install -d "$prefix/bin"
install -m 0755 "$BUILD_EXECUTABLE" "$prefix/bin/forgejo-runner"
printf 'Installed: %s/bin/forgejo-runner\n' "$prefix"
