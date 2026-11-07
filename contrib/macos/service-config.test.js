// SPDX-License-Identifier: GPL-3.0-or-later
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {pathToFileURL} = require('node:url');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'forgejo service '));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  const root = path.join(directory, 'service');
  fs.mkdirSync(path.join(root, 'etc'), {recursive: true});
  const token = path.join(directory, 'private token');
  fs.writeFileSync(token, 'a'.repeat(40) + '\n', {mode: 0o600});
  const config = {
    runner: {labels: ['macos-arm64:host']},
    server: {connections: {example: {
      url: 'https://forgejo.example.com/',
      uuid: '00000000-0000-0000-0000-000000000000',
      token_url: pathToFileURL(token).href,
    }}},
  };
  const input = path.join(directory, 'input.json');
  const run = (extraEnv = {}) => {
    fs.writeFileSync(input, JSON.stringify(config), {mode: 0o600});
    return spawnSync(process.execPath, [path.join(__dirname, 'service-config.js'), input, root], {
      encoding: 'utf8', env: {...process.env, FORGEJO_SERVICE_VALIDATE_ONLY: '', ...extraEnv},
    });
  };
  return {root, config, run};
}

test('migrates file-based credentials and all runtime paths without logging secrets', t => {
  const {root, run} = fixture(t);
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  const destination = path.join(root, 'etc', 'config.yaml');
  const config = JSON.parse(fs.readFileSync(destination, 'utf8'));
  assert.equal(config.server.connections.example.token, undefined);
  assert.equal(config.server.connections.example.token_url, pathToFileURL(path.join(root, 'etc', 'runner-token')).href);
  assert.equal(config.host.workdir_parent, path.join(root, 'home', 'work'));
  assert.equal(config.cache.host, '127.0.0.1');
  assert.equal(fs.statSync(destination).mode & 0o777, 0o600);
  assert.equal(fs.statSync(path.join(root, 'etc', 'runner-token')).mode & 0o777, 0o600);
  assert.equal(result.stdout + result.stderr, '');
});

test('validation-only mode does not create runtime credentials', t => {
  const {root, run} = fixture(t);
  const result = run({FORGEJO_SERVICE_VALIDATE_ONLY: '1'});
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(fs.readdirSync(path.join(root, 'etc')), []);
});

test('rejects non-HTTPS connections before writing runtime credentials', t => {
  const {root, config, run} = fixture(t);
  config.server.connections.example.url = 'http://forgejo.example.com/';
  assert.notEqual(run().status, 0);
  assert.deepEqual(fs.readdirSync(path.join(root, 'etc')), []);
});
