# Forgejo Runner for macOS

Community macOS build tooling and an editable source fork of Forgejo Runner,
starting from upstream **v13.2.1**. This repository retains the full upstream
history. Builds compile the source in this checkout so future local fixes can
be included and reviewed.

**Status:** Native ARM64 builds and local host workflow checks pass on macOS 27.2
with Go 1.26.8 and Node.js 24.22.2. Upstream short tests pass with Docker/LXC
features disabled. The runner's Go source is unchanged from v13.2.1; the macOS
build manifest tooling includes a compatibility fix for `plutil`.
GitHub Actions builds and tests Apple Silicon and Intel executables natively;
see the [Actions runs](https://github.com/cstenglein/forgejo-runner-macos/actions)
for current platform results. An authenticated end-to-end Forgejo job remains a
separate deployment check.

This is not an official Forgejo macOS release. Upstream officially supports and
tests Linux. macOS packaging is also available independently through Homebrew.

## Use a release

Download your platform's executable and `SHA256SUMS` from
[Releases](https://github.com/cstenglein/forgejo-runner-macos/releases):

- Apple Silicon: `forgejo-runner-<version>-darwin-arm64`
- Intel: `forgejo-runner-<version>-darwin-amd64`

Compare the executable's `shasum -a 256` output with its entry in `SHA256SUMS`,
mark it executable with `chmod +x`, and run it with `--version` before configuring
it. Each release includes matching source, license and build manifests. These
community executables have no Developer ID signature or Apple notarization.

## Build, test and package

Install Git, Xcode or Command Line Tools, and Go, then:

```sh
git clone https://github.com/cstenglein/forgejo-runner-macos.git
cd forgejo-runner-macos
./contrib/macos/build.sh 13.2.1-macos.1
./contrib/macos/test.sh
```

See [macOS build tools](contrib/macos/README.md) for verification coverage,
prerequisites, the DNS probe, installation and packaging. Build output is in
`dist/macos/`.

The macOS build omits `netgo` and Linux static-linker flags. The runner's Go code,
dependency files and upstream Makefile remain unchanged.

No Forgejo instance address, runner credential or personal GitHub token is needed
to build. Keep deployment configuration outside this public checkout. `.local/`,
local credential files and runner state are ignored by Git.

## Follow upstream

The upstream base is tag `v13.2.1`, commit
`c4a92ffa5e3a400ae7e9c40a2914e649eb338ad7`.

```sh
git remote add upstream https://code.forgejo.org/forgejo/runner.git
git fetch upstream --tags
# Merge a reviewed upstream release in a branch and rerun the macOS checks.
```

Use a new `macos.N` suffix for community releases based on the same upstream
version. Do not move published release tags. Pushes to `main`, pull requests and
manual workflow runs build and test both architectures. Pushing a tag such as
`v13.2.1-macos.1` publishes that exact commit after both builds pass, with matching
source, per-architecture provenance, license and aggregate SHA-256 checksums.

## Run as an unattended server

See [LaunchDaemon installation](contrib/macos/SERVICE.md). The service starts at
boot as a dedicated non-admin user and restarts when it exits. Private instance
configuration is stored outside this checkout. Building and publishing releases
do not require your Forgejo URL or runner credentials.

## License and original documentation

The upstream source and macOS additions are distributed under GPL-3.0-or-later;
existing per-file notices are retained. See [LICENSE](LICENSE), the original
[upstream README](README.upstream.md), and [CONTRIBUTING.md](CONTRIBUTING.md).
The [Windows sibling project](https://github.com/cstenglein/forgejo-runner-windows)
provides the reference structure for this community fork.

---

## Upstream Forgejo Runner

A daemon that connects to a Forgejo instance and runs jobs for continuous integration. The [installation and usage instructions](https://forgejo.org/docs/next/admin/actions/) are part of the Forgejo documentation. Forgejo Runner can also run workflows locally and act as a cache.

Forgejo Runner is distributed under the terms of the [GPL version 3.0](LICENSE) or any later version.

## Issues

* [Feature requests](https://code.forgejo.org/forgejo/forgejo-actions-feature-requests)
* [Runner-specific issues](https://code.forgejo.org/forgejo/runner/issues)
* [Forgejo Actions issues](https://codeberg.org/forgejo/forgejo/issues?q=&type=all&labels=96148&state=open)

It is totally okay to report issues in the "wrong" place; identifying the right place is hard. In the worst case, we will ask you to open it somewhere else because issues cannot be transferred between instances.

### Reporting Security Vulnerabilities

Please report security-related issues to [security@forgejo.org](mailto:security@forgejo.org) using [encryption](https://keyoxide.org/security@forgejo.org).

## Contributing

See the [contribution guide](CONTRIBUTING.md).

## Architectures & OS

The Forgejo runner is supported and tested on `amd64` and `arm64` ([binaries](https://code.forgejo.org/forgejo/runner/releases) and [containers](https://code.forgejo.org/forgejo/-/packages/container/runner/versions)) on Operating Systems based on the Linux kernel.

Work may be in progress for other architectures and you can browse the corresponding issues to figure out how they make progress. If you are interested in helping them move forward, open an issue. The most challenging part is to setup and maintain a native runner long term. Once it is supported by Forgejo, the runner is expected to be available 24/7 which can be challenging. Otherwise debugging any architecture specific problem won't be possible.

- [linux-s390x](https://code.forgejo.org/forgejo/runner/issues?labels=969)
- [linux-powerpc64le](https://code.forgejo.org/forgejo/runner/issues?labels=968)
- [linux-riscv64](https://code.forgejo.org/forgejo/runner/issues?labels=970)
- [Windows](https://code.forgejo.org/forgejo/runner/issues?labels=365)

## Development

The Forgejo runner is a dependency of the [setup-forgejo action](https://code.forgejo.org/actions/setup-forgejo). See [the full dependency graph](https://code.forgejo.org/actions/cascading-pr/#forgejo-dependencies) for a global view.

### Building

- Install [Go](https://go.dev/doc/install) and `make(1)`
- `make build`

### Linting

- `make lint-check`
- `make lint` # will fix some lint errors

### Testing

There are three kinds of tests for Forgejo Runner:

* Unit tests
* Integration tests
* [End-to-end tests](https://code.forgejo.org/forgejo/end-to-end/) that involve a running Forgejo instance

Unit and integration tests are included in this repository, whereas [end-to-end tests](https://code.forgejo.org/forgejo/end-to-end/) are maintained separately.

Tests can either be run using predefined GNU Make targets or `go test`. 

#### Running Tests

To run all unit tests with GNU Make, run:

```shell
$ make test
```

Or with `go test`, run:

```shell
$ go test -short ./...
```

To run all integration tests with GNU Make, run:

```shell
$ make integration-test
```

Or with `go test`, run:

```shell
$ go test ./...
```

#### Toggling Tests by Feature

Forgejo Runner integrates with various technologies like [Docker](https://docker.com/) and [LXC](https://linuxcontainers.org/). They are not available on all platforms that Forgejo Runner can run on. The related tests take a long time to execute, too. It is possible to enable or disable the tests with the help of the test argument `-features`. **All feature-related tests are enabled by default**.

`-features` takes a list of comma-separated feature names. For example, to run all tests including those related to `docker` and `lxc`, invoke:

```shell
$ go test ./... -args -features "docker,lxc"
```

If all feature-related tests should be skipped, run:

```shell
$ go test ./... -args -features "-"
```

If `-features` is not present, all feature-related tests will be enabled.

List of all feature toggles:

| Key      | Purpose                                                                                   |
|----------|-------------------------------------------------------------------------------------------|
| `docker` | Toggles tests that require [Docker](https://docker.com/) or [Podman](https://podman.io/). |
| `lxc`    | Toggles tests that require [LXC](https://linuxcontainers.org/).                           |

#### Running End-to-End Tests

For running end-to-end tests during development, please see the instructions in the respective [repository where the end-to-end tests are maintained](https://code.forgejo.org/forgejo/end-to-end/).

During CI, the end-to-end tests can be triggered for a particular pull request by attaching the label [`run-end-to-end-tests`](https://code.forgejo.org/forgejo/runner/pulls?labels=1032).
