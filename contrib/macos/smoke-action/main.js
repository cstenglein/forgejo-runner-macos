// SPDX-License-Identifier: GPL-3.0-or-later
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

assert.equal(process.platform, 'darwin');
const expectedArch = process.arch === 'arm64' ? 'ARM64' : 'X64';
assert.equal(process.env.RUNNER_OS, 'macOS');
assert.equal(process.env.RUNNER_ARCH, expectedArch);
assert.equal(process.env.EXPECTED_RUNNER_OS, 'macOS');
assert.equal(process.env.EXPECTED_RUNNER_ARCH, expectedArch);

const fixture = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP, 'macos smoke '));
// Save cleanup state first, so a failing assertion can still be cleaned up.
fs.appendFileSync(process.env.GITHUB_STATE, `fixture=${fixture}\n`);
fs.writeFileSync(path.join(fixture, 'macos-runner-smoke-tool'), '#!/bin/sh\nprintf "%s\\n" ok\n', { mode: 0o755 });
fs.appendFileSync(process.env.GITHUB_PATH, `${fixture}\n`);
fs.appendFileSync(process.env.GITHUB_ENV, 'MACOS_NODE_SMOKE=ok\n');
fs.appendFileSync(process.env.GITHUB_OUTPUT, 'multiline<<SMOKE_EOF\nfirst line\nsecond line\nSMOKE_EOF\n');
console.log(`Native Node.js action passed: ${process.platform}/${process.arch}`);
