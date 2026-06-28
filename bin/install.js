#!/usr/bin/env node
'use strict';
// Installs the gapes agent skill into an agent's skills directory.
//   bunx github:fguisso/gapes            # auto-detects Claude Code (~/.claude/skills)
//   bunx github:fguisso/gapes <dir>      # install into <dir>/gapes
//   bunx github:fguisso/gapes --with-cli # also install the gapes CLI (curl install.sh)
// Env: GAPES_SKILLS_DIR overrides the target base dir.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const log = (m) => process.stderr.write(m + '\n');

const repoRoot = path.join(__dirname, '..');
const src = path.join(repoRoot, 'skills', 'gapes');
if (!fs.existsSync(src)) {
  log('error: skills/gapes was not found next to this installer.');
  process.exit(1);
}

const args = process.argv.slice(2);
const withCli = args.includes('--with-cli');
const posArg = args.find((a) => !a.startsWith('-'));

let base = posArg || process.env.GAPES_SKILLS_DIR;
if (!base) {
  const claude = path.join(os.homedir(), '.claude');
  if (fs.existsSync(claude)) {
    base = path.join(claude, 'skills');
  } else {
    log('Could not auto-detect an agent skills directory.');
    log('Pass one explicitly, e.g.:');
    log('  bunx github:fguisso/gapes ~/.claude/skills');
    log('Codex: copy into your project and reference skills/gapes/SKILL.md from AGENTS.md.');
    process.exit(1);
  }
}

const dest = path.join(base, 'gapes');
fs.mkdirSync(base, { recursive: true });
fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });

const scriptsDir = path.join(dest, 'scripts');
if (fs.existsSync(scriptsDir)) {
  for (const f of fs.readdirSync(scriptsDir)) {
    if (f.endsWith('.sh')) fs.chmodSync(path.join(scriptsDir, f), 0o755);
  }
}
log('✓ gapes skill installed → ' + dest);

const hasCli = () => {
  try { execSync('command -v gapes', { stdio: 'ignore' }); return true; } catch { return false; }
};
if (hasCli()) {
  log('✓ gapes CLI already on PATH');
} else if (withCli) {
  log('installing gapes CLI …');
  execSync('curl -fsSL https://guisso.dev/gapes/install.sh | sh', { stdio: 'inherit' });
} else {
  log('');
  log('gapes CLI not found — install it with:');
  log('  curl -fsSL https://guisso.dev/gapes/install.sh | sh');
  log('  (or re-run this with --with-cli)');
}

log('');
log('Next: ask your agent to "set up the gapes CLI and deploy <dir>".');
