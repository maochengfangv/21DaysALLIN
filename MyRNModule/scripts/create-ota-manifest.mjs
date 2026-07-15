#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (!item.startsWith('--')) {
      continue;
    }
    const key = item.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      args[key] = 'true';
      continue;
    }
    args[key] = next;
    index += 1;
  }
  return args;
}

function ensureRequired(args, keys) {
  const missing = keys.filter(key => !args[key]);
  if (missing.length > 0) {
    throw new Error(`缺少必要参数: ${missing.join(', ')}`);
  }
}

function sha256(filePath) {
  const hash = crypto.createHash('sha256');
  hash.update(fs.readFileSync(filePath));
  return hash.digest('hex');
}

function canonicalize(value) {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map(item => canonicalize(item)).join(',')}]`;
  }

  return `{${Object.entries(value)
    .filter(([, fieldValue]) => fieldValue !== undefined)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, fieldValue]) => `${JSON.stringify(key)}:${canonicalize(fieldValue)}`)
    .join(',')}}`;
}

function signPayload(payload, privateKeyPath) {
  const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
  return crypto
    .sign('RSA-SHA256', Buffer.from(payload), privateKey)
    .toString('base64');
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  ensureRequired(args, [
    'platform',
    'channel',
    'version',
    'label',
    'package-url',
    'package-file',
    'bundle-file',
    'bundle-file-path',
    'output',
  ]);

  const manifest = {
    id: `${args.platform}-${args.channel}-${args.version}-${args.label}`,
    label: args.label,
    platform: args.platform,
    channel: args.channel,
    version: args.version,
    packageUrl: args['package-url'],
    packageSha256: sha256(args['package-file']),
    bundleFile: args['bundle-file'],
    bundleSha256: sha256(args['bundle-file-path']),
    description: args.description || '',
    mandatory: args.mandatory === 'true',
    rollout: Number(args.rollout || '100'),
    minNativeVersion: args['min-native-version'] || args.version,
    packageType: args['package-type'] || 'full',
    createdAt: new Date().toISOString(),
  };

  if (args['private-key']) {
    const payload = canonicalize(manifest);
    manifest.signatureAlgorithm = 'RSA-SHA256';
    manifest.signature = signPayload(payload, args['private-key']);
  }

  const outputPath = path.resolve(args.output);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
  process.stdout.write(`Manifest 已生成: ${outputPath}\n`);
}

main();
