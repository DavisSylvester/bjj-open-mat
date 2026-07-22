#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const rootDir = path.resolve(fileURLToPath(new URL('.', import.meta.url)), '..');

function run(command, args, cwd) {
  console.log(`\n▶ ${command} ${args.join(' ')}  (${path.relative(rootDir, cwd) || '.'})`);
  const result = spawnSync([command, ...args].join(' '), { cwd, stdio: 'inherit', shell: true });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

// 1. Root Bun workspace (apps/api, packages/contract, etc.)
run('bun', ['install'], rootDir);

// 2. website is a standalone Bun project (its own bun.lock, not part of the root workspace)
const websiteDir = path.join(rootDir, 'website');
if (existsSync(path.join(websiteDir, 'package.json'))) {
  run('bun', ['install'], websiteDir);
}

// 3. apps/mobile is a Flutter project (pubspec.yaml, no package.json)
const mobileDir = path.join(rootDir, 'apps', 'mobile');
if (existsSync(path.join(mobileDir, 'pubspec.yaml'))) {
  run('flutter', ['pub', 'get'], mobileDir);
}

console.log('\n✔ All project dependencies installed.');
