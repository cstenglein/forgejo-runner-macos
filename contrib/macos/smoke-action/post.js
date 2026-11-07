// SPDX-License-Identifier: GPL-3.0-or-later
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const fixture = process.env.STATE_fixture;
assert.ok(fixture, 'Action state must reach the post step');
assert.ok(fs.existsSync(path.join(fixture, 'macos-runner-smoke-tool')));
fs.rmSync(fixture, { recursive: true });
console.log('Native Node.js post-action state and cleanup passed');
