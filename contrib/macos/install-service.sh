#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -eq 1 ]] || die 'Usage: sudo install-service.sh /absolute/private-config.json'
load_build
[[ $(manifest_value SourceDirty) == false ]] || die 'Commit changes and rebuild before installing a service.'
[[ $1 == /* && -f $1 ]] || die 'Supply an existing private JSON config with an absolute path.'
private_config=$1
service_user=_forgejo_runner
service_root=/Library/ForgejoRunner
label=io.github.cstenglein.forgejo-runner
plist="/Library/LaunchDaemons/$label.plist"
node_binary=''
for candidate in /opt/homebrew/opt/node@24/bin/node /usr/local/opt/node@24/bin/node; do
    if [[ -x $candidate ]]; then node_binary=$candidate; break; fi
done
[[ -n $node_binary ]] || die 'Install a service-accessible Node.js runtime first: brew install node@24'
[[ $("$node_binary" -p 'process.versions.node.split(".")[0]') == 24 ]] || die 'Node.js 24 is required.'
/usr/bin/plutil -lint "$MACOS_SCRIPT_DIR/launchdaemon.plist"
FORGEJO_SERVICE_VALIDATE_ONLY=1 "$node_binary" "$MACOS_SCRIPT_DIR/service-config.js" "$private_config" "$service_root"
[[ $EUID -eq 0 ]] || die 'Administrator privileges are required. Run this script with sudo.'

if dscl . -read "/Users/$service_user" UniqueID >/dev/null 2>&1; then
    [[ $(dscl . -read "/Users/$service_user" NFSHomeDirectory) == "NFSHomeDirectory: $service_root/home" ]] || die 'Existing service account has an unexpected home.'
    [[ $(dscl . -read "/Users/$service_user" UserShell) == 'UserShell: /usr/bin/false' ]] || die 'Existing service account has an unexpected shell.'
    case " $(id -Gn "$service_user") " in *' admin '*) die 'The service account must not be an administrator.' ;; esac
else
    used_ids=$( { dscl . -list /Users UniqueID; dscl . -list /Groups PrimaryGroupID; } | awk '{print $NF}')
    account_id=400
    while printf '%s\n' "$used_ids" | grep -qx "$account_id"; do account_id=$((account_id + 1)); done
    [[ $account_id -lt 500 ]] || die 'No available system account ID between 400 and 499.'
    ! dscl . -read "/Groups/$service_user" >/dev/null 2>&1 || die 'A group with the service account name already exists.'
    dscl . -create "/Groups/$service_user"
    dscl . -create "/Groups/$service_user" PrimaryGroupID "$account_id"
    dscl . -create "/Groups/$service_user" GeneratedUID "$(uuidgen)"
    dscl . -create "/Users/$service_user"
    dscl . -create "/Users/$service_user" UniqueID "$account_id"
    dscl . -create "/Users/$service_user" PrimaryGroupID "$account_id"
    dscl . -create "/Users/$service_user" GeneratedUID "$(uuidgen)"
    dscl . -create "/Users/$service_user" RealName 'Forgejo Actions Runner'
    dscl . -create "/Users/$service_user" NFSHomeDirectory "$service_root/home"
    dscl . -create "/Users/$service_user" UserShell /usr/bin/false
    dscl . -create "/Users/$service_user" Password '*'
    dscl . -create "/Users/$service_user" AuthenticationAuthority ';DisabledUser;'
    dscl . -create "/Users/$service_user" IsHidden 1
fi

if launchctl print "system/$label" >/dev/null 2>&1; then
    launchctl bootout system "$plist"
fi
install -d -o root -g wheel -m 0755 "$service_root" "$service_root/bin"
install -d -o root -g "$service_user" -m 0750 "$service_root/etc"
for directory in home home/work home/cache home/logs home/tmp home/toolcache; do
    install -d -o "$service_user" -g "$service_user" -m 0700 "$service_root/$directory"
done
install -o root -g wheel -m 0755 "$BUILD_EXECUTABLE" "$service_root/bin/forgejo-runner"
"$node_binary" "$MACOS_SCRIPT_DIR/service-config.js" "$private_config" "$service_root"
chown "root:$service_user" "$service_root/etc/config.yaml" "$service_root/etc/runner-token"
chmod 0640 "$service_root/etc/config.yaml" "$service_root/etc/runner-token"
install -o root -g wheel -m 0644 "$MACOS_SCRIPT_DIR/launchdaemon.plist" "$plist"

# Verify tools with the actual service identity and a login-independent PATH.
service_path='/opt/homebrew/opt/node@24/bin:/usr/local/opt/node@24/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
sudo -u "$service_user" /usr/bin/env -i HOME="$service_root/home" PATH="$service_path" "$service_root/bin/forgejo-runner" --version
sudo -u "$service_user" /usr/bin/env -i HOME="$service_root/home" PATH="$service_path" node --version
sudo -u "$service_user" /usr/bin/env -i HOME="$service_root/home" PATH="$service_path" git --version
# Keep AC-powered server operation independent of display sleep and power outages.
pmset -c sleep 0 autorestart 1
logfile="$service_root/home/logs/runner.log"
log_offset=0
[[ ! -f $logfile ]] || log_offset=$(stat -f %z "$logfile")
launchctl enable "system/$label"
launchctl bootstrap system "$plist"
connected=false
for ((attempt=0; attempt<30; attempt++)); do
    if [[ -f $logfile ]] && tail -c "+$((log_offset + 1))" "$logfile" | grep -q 'declared successfully'; then connected=true; break; fi
    sleep 1
done
if [[ $connected != true ]]; then
    printf 'Service installed, but authenticated startup is not confirmed yet. Inspect the private service log with sudo.\n' >&2
    exit 1
fi
# This credential-free receipt is readable for later non-admin verification.
SERVICE_VERSION="$($service_root/bin/forgejo-runner --version)" "$node_binary" - "$service_root/status.json" <<'JS'
const fs = require('node:fs');
fs.writeFileSync(process.argv[2], JSON.stringify({
  version: process.env.SERVICE_VERSION,
  authenticatedStartup: true,
  verifiedAt: new Date().toISOString(),
  user: '_forgejo_runner',
  label: 'io.github.cstenglein.forgejo-runner',
}, null, 2) + '\n', {mode: 0o644});
JS
printf 'Installed and started: %s\nUser: %s\nLogs: %s/home/logs/runner.log\n' "$label" "$service_user" "$service_root"
