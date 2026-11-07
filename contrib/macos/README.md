# macOS build tools

These scripts compile the actual source in this checkout. They do not download
a prebuilt runner or copy the Windows fork's source fixes. The runner code is
unchanged from upstream v13.2.1.

## Status

Verified locally on 2026-11-07 using macOS 27.2 ARM64, Go 1.26.8 and Node.js
24.22.2:

- Native ARM64 executable, version output and JSON build manifest.
- Upstream short test suite with Docker and LXC feature tests disabled.
- Host workflow with the default shell and explicit POSIX `sh`.
- Local checkout copying, native Node.js action, runner OS/architecture context,
  environment files, multiline outputs and PATH entries containing spaces.
- Expected step failure with `continue-on-error`, and post-action state/cleanup.
- Native Go DNS and certificate-verified HTTPS access to a private instance.

No upstream runner source fix was needed. The build manifest is populated as an
XML plist and then converted to JSON because editing JSON directly with `plutil`
failed on the target Mac.

Intel, LaunchDaemon deployment, an authenticated end-to-end Forgejo job, remote
checkout, cache action round trips and artifact upload/download are not yet
verified. Local `runner exec` copies the checkout itself; it does not run a real
remote checkout action. No release has been published.

## Requirements

- macOS on Apple Silicon or Intel, Git, and Xcode or Command Line Tools with its
  license accepted.
- Go. The scripts select `toolchain` from `go.mod` (currently `go1.26.8`), which Go
  may download on first use. An explicit `GOTOOLCHAIN` override is supported and
  the actual compiler version is recorded in the build manifest.
- Node.js 24 on the service's PATH for the smoke workflow's JavaScript action.

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
settings. No upstream runner source bug fixes are included.

## Test

```sh
./contrib/macos/test.sh
# Optional DNS/HTTPS check with the same Go build settings:
./contrib/macos/test.sh https://instance.example/api/v1/version
```

This runs upstream short tests with Docker and LXC features disabled, validates
the smoke workflow/action, and executes it locally on the host. The deliberate
`exit 42` step is expected to show a failure, followed by a successful outcome
check and an overall successful job. Failures are not silently skipped. The
optional probe is a separate Go
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
