# Unattended macOS service

The LaunchDaemon starts at boot without a desktop login. `KeepAlive` restarts
the runner if it exits; launchd throttles restarts to ten-second intervals.
The runner runs as the hidden non-admin `_forgejo_runner` account, not root.
Installation and authenticated startup have been verified on macOS 27.2 ARM64.
The boot registration is installed and enabled; a physical reboot is not part
of the automated verification.

## Prepare

Install Node.js independently of interactive NVM initialization:

```sh
brew install node@24
```

Build a committed source revision using `build.sh`. Store your runner connection
in a private **JSON** file outside this checkout. JSON is also valid YAML for
Forgejo Runner. A minimal input is:

```json
{
  "runner": {"labels": ["macos-arm64:host"]},
  "cache": {"enabled": true},
  "server": {
    "connections": {
      "forgejo": {
        "url": "https://forgejo.example.com/",
        "uuid": "00000000-0000-0000-0000-000000000000",
        "token_url": "file:///absolute/private/runner-token"
      }
    }
  }
}
```

Put the runner token in that separate file, restrict both input files to mode
`600`, and obtain the real UUID/token through Forgejo's runner settings.
Use `macos-amd64:host` for an Intel runner. Keep host runners limited to trusted
repositories. A label does not provide a security boundary.

## Install

```sh
sudo ./contrib/macos/install-service.sh /absolute/private/config.json
```

The installer validates the inputs without printing secrets, creates the
dedicated account, installs a root-owned executable and LaunchDaemon plist,
copies the private connection into `/Library/ForgejoRunner/etc/`, and creates
runner-owned working/cache/log directories under `/Library/ForgejoRunner/home/`.
Config and token are readable only by root and the service group. No credentials
are put into the public plist or this repository. Keep the source input private.

It also disables automatic system sleep on AC power and enables restart after
a power failure. Display sleep is unaffected. An existing service is stopped
gracefully before an update. Run installation outside active CI jobs.
The installer waits up to 30 seconds for authenticated startup and writes a
credential-free verification receipt to `/Library/ForgejoRunner/status.json`.

## Inspect and manage

```sh
sudo launchctl print system/io.github.cstenglein.forgejo-runner
sudo tail -n 50 /Library/ForgejoRunner/home/logs/runner.log
# Stop (the plist remains installed for the next boot):
sudo launchctl bootout system /Library/LaunchDaemons/io.github.cstenglein.forgejo-runner.plist
# Start again:
sudo launchctl bootstrap system /Library/LaunchDaemons/io.github.cstenglein.forgejo-runner.plist
# Disable automatic startup and stop it:
sudo launchctl disable system/io.github.cstenglein.forgejo-runner
sudo launchctl bootout system /Library/LaunchDaemons/io.github.cstenglein.forgejo-runner.plist
```

Service logs are local and are not uploaded to GitHub. Monitor their size; log
rotation is not configured by this initial installer. No reboot, automatic
desktop login, FileVault change, Tailscale configuration change or macOS privacy
permission change is performed. If the instance is on a VPN, make sure the VPN
can connect without a desktop login. A locked FileVault startup volume must be
unlocked before the daemon can run.
