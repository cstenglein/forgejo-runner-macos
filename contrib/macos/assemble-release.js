// SPDX-License-Identifier: GPL-3.0-or-later
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const [artifacts, output] = process.argv.slice(2);
const tag = process.env.RELEASE_TAG || '';
if (!artifacts || !output || !/^v\d+\.\d+\.\d+-macos\.\d+$/.test(tag)) throw new Error('Expected artifact/output directories and a macOS release tag.');
const version = tag.slice(1);
const revision = process.env.GITHUB_SHA;
if (!/^[0-9a-f]{40}$/.test(revision || '')) throw new Error('A full release source revision is required.');
if (fs.existsSync(output)) throw new Error('Refusing to overwrite a release directory.');
fs.mkdirSync(output);
const sha256 = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for (const arch of ['arm64', 'amd64']) {
  const directory = path.join(artifacts, `darwin-${arch}`);
  const manifestPath = path.join(directory, 'build-manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const binary = `forgejo-runner-${version}-darwin-${arch}`;
  if (manifest.Version !== version || manifest.SourceRevision !== revision || manifest.SourceDirty !== false || manifest.Architecture !== arch || manifest.Binary !== binary) throw new Error(`Unexpected provenance for ${arch}.`);
  if (sha256(path.join(directory, binary)) !== manifest.BinarySHA256) throw new Error(`Checksum mismatch for ${arch}.`);
  // Validate every per-platform asset before assembling the public release.
  for (const line of fs.readFileSync(path.join(directory, 'SHA256SUMS'), 'utf8').trim().split('\n')) {
    const match = line.match(/^([0-9a-f]{64})  ([^/]+)$/);
    if (!match || sha256(path.join(directory, match[2])) !== match[1]) throw new Error(`Invalid checksums for ${arch}.`);
  }
  fs.copyFileSync(path.join(directory, binary), path.join(output, binary));
  fs.copyFileSync(manifestPath, path.join(output, `build-manifest-darwin-${arch}.json`));
  if (arch === 'arm64') {
    for (const name of [`forgejo-runner-${version}-source.tar.gz`, 'LICENSE.txt']) fs.copyFileSync(path.join(directory, name), path.join(output, name));
  }
}
const sums = fs.readdirSync(output).sort().map(name => `${sha256(path.join(output, name))}  ${name}`).join('\n') + '\n';
fs.writeFileSync(path.join(output, 'SHA256SUMS'), sums);
fs.writeFileSync('release-notes.txt', `Community macOS build of Forgejo Runner ${version}.\n\nBuilt from commit ${revision}. Native ARM64 and Intel builds pass the upstream short tests (Docker/LXC disabled) and the native shell/Node.js smoke workflow.\n\nIncludes per-architecture build manifests, matching source, GPL license and SHA-256 checksums. Uses native macOS DNS. Upstream officially supports Linux. No Developer ID signing or notarization is provided.\n\nSee contrib/macos/SERVICE.md in the source for unattended LaunchDaemon installation. Private instance credentials are never included.\n`);
console.log(`Verified release assets assembled for ${tag}.`);
