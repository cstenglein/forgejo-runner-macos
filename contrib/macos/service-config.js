// SPDX-License-Identifier: GPL-3.0-or-later
// Convert private JSON (also valid YAML) into the service's private config.
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');

const [input, root] = process.argv.slice(2);
if (!input || !root || !path.isAbsolute(root)) throw new Error('Usage: service-config.js private-config.json /service/root');
const config = JSON.parse(fs.readFileSync(input, 'utf8'));
const connections = Object.values(config.server?.connections || {});
if (connections.length !== 1) throw new Error('This installer supports exactly one private connection.');
const connection = connections[0];
const url = new URL(connection.url);
if (url.protocol !== 'https:' || url.username || url.password) throw new Error('An HTTPS instance URL without credentials is required.');
if (!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(connection.uuid || '')) throw new Error('A valid runner UUID is required.');
if (connection.token || !connection.token_url) throw new Error('Supply the token through a private file URL.');
const tokenURL = new URL(connection.token_url);
if (tokenURL.protocol !== 'file:') throw new Error('The token URL must reference a local file.');
const token = fs.readFileSync(tokenURL, 'utf8').trim();
if (!/^[0-9a-f]{40}$/i.test(token)) throw new Error('Expected a 40-character runner token.');
const home = path.join(root, 'home');
const tokenDestination = path.join(root, 'etc', 'runner-token');
connection.token_url = pathToFileURL(tokenDestination).href;
config.runner = {...config.runner, capacity: 1, file: path.join(home, 'registration.json'), env_file: '', shutdown_timeout: '30s', insecure: false};
// A label is a routing hint, not an isolation boundary. Restrict native host
// execution to trusted repositories at registration time.
if (!Array.isArray(config.runner.labels) || !config.runner.labels.length || config.runner.labels.some(label => typeof label !== 'string' || !label.endsWith(':host'))) throw new Error('Explicit native host labels are required.');
config.host = {...config.host, workdir_parent: path.join(home, 'work')};
config.cache = {...config.cache, dir: path.join(home, 'cache'), host: '127.0.0.1'};
config.container = {...config.container, docker_host: '-'};
if (process.env.FORGEJO_SERVICE_VALIDATE_ONLY === '1') {
  console.log('Private service configuration validated; no credentials displayed or copied.');
} else {
  fs.writeFileSync(tokenDestination, token + '\n', {mode: 0o600});
  fs.writeFileSync(path.join(root, 'etc', 'config.yaml'), JSON.stringify(config, null, 2) + '\n', {mode: 0o600});
}
