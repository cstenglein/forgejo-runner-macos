# macOS build tools

These scripts compile the actual source in this checkout. They do not download
a prebuilt runner or copy the Windows fork's source fixes. The runner code is
initially unchanged from upstream v13.2.1.

## Status

Build tooling has been prepared. No macOS build, runner test, service installation
or release has been completed yet. The scripts and smoke workflow still need to
be exercised on the target Mac. ARM64 is the first target; Intel support must be
verified separately before being advertised as tested.

## Requirements

- macOS on Apple Silicon or Intel, Git, and Xcode or Command Line Tools with its
  license accepted.
- Go. The scripts select `toolchain` from `go.mod` (currently `go1.26.8`), which Go
  may download on first use. An explicit `GOTOOLCHAIN` override is supported and
  the actual compiler version is recorded in the build manifest.
- Node.js on the service's PATH for JavaScript actions. The minimal smoke workflow
  does not exercise Node actions, remote checkout, cache or artifacts.

Scripts use `/bin/bash` and macOS tools, including `plutil` and `shasum`. Homebrew
Bash, Python and Docker are not required for this native host setup.

## Build

```sh
./contrib/macos/build.sh
# Or assign a community version explicitly:
./contrib/macos/build.sh 13.2.1-macos.1
```

Build output is in `dist/macos/`. The JSON manifest records the revision, dirty
source state, version, architecture, compiler, build tags, CGO and binary SHA-256.
The build omits `netgo` and Linux static-linker flags and uses native macOS build
settings. No source bug fixes are included at this initial stage.

## Test

```sh
./contrib/macos/test.sh
# Optional DNS/HTTPS check with the same Go build settings:
./contrib/macos/test.sh https://instance.example/api/v1/version
```

This runs upstream short tests with Docker and LXC features disabled, validates
the smoke workflow, and executes it locally on the host. Failures must be
investigated; this initial tooling does not skip macOS failures or claim that
the full suite is already compatible. The optional probe is a separate Go
program, not an authenticated runner connection or an end-to-end Forgejo job.

Host execution runs workflow commands as the current user. Keep the runner
limited to trusted repositories. The example label is `macos-arm64:host`.

## Package

Commit changes, rebuild the clean source revision, then run:

```sh
./contrib/macos/package.sh
```

Files are written to `dist/release/<version>/darwin-<arch>/`: the executable,
matching committed source archive, GPL license, build manifest and `SHA256SUMS`.
Packaging refuses dirty builds, a changed revision, checksum mismatches and an
existing output directory. The source archive contains only files from Git.
No Developer ID signing, notarization, publishing or release tagging is performed.

## Install a local build

```sh
./contrib/macos/install.sh                # ~/.local/bin/forgejo-runner
./contrib/macos/install.sh /custom/prefix # /custom/prefix/bin/forgejo-runner
```

The script checks the build checksum and installs only the binary, replacing an
existing binary at that destination. It does not request sudo, register a runner,
write credentials, modify PATH or start a service.

Registration and the server's LaunchDaemon setup are separate deployment steps.
For unattended operation, use a dedicated non-admin account, an explicit PATH
(interactive NVM initialization is not loaded by launchd), and private runtime
configuration outside this repository. A service configuration and lifecycle
commands will be added when deployment has been tested.
