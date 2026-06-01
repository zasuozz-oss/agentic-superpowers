#!/usr/bin/env node

import { cpSync, rmSync, existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, chmodSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { homedir, platform } from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = join(__dirname, '..');

const GLOBAL_DIR = join(homedir(), '.gemini', 'config');
const GEMINI_MD = join(homedir(), '.gemini', 'GEMINI.md');

// ─── Helpers ───────────────────────────────────────────────

function log(icon, msg) {
  console.log(`   ${icon} ${msg}`);
}

function copyDir(src, dest) {
  cpSync(src, dest, { recursive: true, force: true });
}

function countItems(dir) {
  try {
    return readdirSync(dir).filter((f) => !f.startsWith('.')).length;
  } catch {
    return 0;
  }
}

// ─── Steps ─────────────────────────────────────────────────

function banner() {
  console.log('');
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║     Agentic Superpowers — Global Setup                     ║');
  console.log('║     npx @zasuo/agentic-superpowers                         ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log('');
}

function step1_createDir() {
  console.log('📁 Step 1: Creating global config directory...');
  mkdirSync(GLOBAL_DIR, { recursive: true });
  log('✓', `Created: ${GLOBAL_DIR}`);
  console.log('');
}

function step2_checkDuplicates() {
  const src = join(ROOT, 'global-config', 'skills');
  if (!existsSync(src)) return;

  console.log('🔍 Step 2: Checking for duplicate skills...');
  const names = new Map();

  for (const entry of readdirSync(src)) {
    const skillMd = join(src, entry, 'SKILL.md');
    if (!statSync(join(src, entry)).isDirectory() || !existsSync(skillMd)) continue;

    const content = readFileSync(skillMd, 'utf8');
    const match = content.match(/^name:\s*(.+)$/m);
    if (!match) continue;

    const name = match[1].trim();
    if (names.has(name)) {
      console.error(`❌ Duplicate skill name "${name}" found in:`);
      console.error(`   - ${names.get(name)}/SKILL.md`);
      console.error(`   - ${entry}/SKILL.md`);
      process.exit(1);
    }
    names.set(name, entry);
  }

  log('✓', `${names.size} skills checked, no duplicates`);
  console.log('');
}

function step3_installSkills() {
  const src = join(ROOT, 'global-config', 'skills');
  const dest = join(GLOBAL_DIR, 'skills');

  if (!existsSync(src)) {
    console.error('❌ Error: global-config/skills/ not found');
    process.exit(1);
  }

  console.log('📚 Step 3: Installing skills...');
  if (existsSync(dest)) rmSync(dest, { recursive: true, force: true });
  copyDir(src, dest);
  log('✓', `${countItems(dest)} skills installed`);
  console.log('');
}

function step4_installScripts() {
  const src = join(ROOT, 'scripts');
  const dest = join(GLOBAL_DIR, 'scripts');

  console.log('⚙️  Step 4: Installing scripts...');
  if (existsSync(dest)) rmSync(dest, { recursive: true, force: true });
  copyDir(src, dest);

  // chmod +x on unix
  if (platform() !== 'win32') {
    try {
      readdirSync(dest)
        .filter((f) => f.endsWith('.sh'))
        .forEach((f) => chmodSync(join(dest, f), 0o755));
    } catch {
      // ignore chmod errors
    }
  }

  log('✓', `${countItems(dest)} scripts installed`);
  console.log('');
}

function step5_updateGeminiMd() {
  console.log('📝 Step 5: Updating global GEMINI.md...');

  const ruleFile = join(ROOT, 'global-config', 'gemini_rule.md');

  mkdirSync(dirname(GEMINI_MD), { recursive: true });

  // Always overwrite — GEMINI.md is a generated file
  let content = '';
  if (existsSync(ruleFile)) {
    content = readFileSync(ruleFile, 'utf8');
  }
  writeFileSync(GEMINI_MD, content, 'utf8');
  log('✓', `Written: ${GEMINI_MD}`);
  console.log('');
}

function step6_cleanup() {
  const rulesDir = join(GLOBAL_DIR, 'rules');
  const workflowsDir = join(GLOBAL_DIR, 'global_workflows');

  if (existsSync(rulesDir) || existsSync(workflowsDir)) {
    console.log('🧹 Step 6: Cleaning up old rules/workflows...');
    if (existsSync(rulesDir)) rmSync(rulesDir, { recursive: true, force: true });
    if (existsSync(workflowsDir)) rmSync(workflowsDir, { recursive: true, force: true });
    log('✓', 'Removed legacy rules and workflows');
    console.log('');
  }
}

function step7_verify() {
  console.log('✅ Verification...');
  log('', `Skills:    ${countItems(join(GLOBAL_DIR, 'skills'))}`);
  log('', `Scripts:   ${countItems(join(GLOBAL_DIR, 'scripts'))}`);
  log('', `GEMINI.md: ✓`);
  console.log('');
}

function footer() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║     Installation Complete                                  ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log('');
  console.log('🚀 Next steps:');
  console.log('   1. Open Antigravity in any project');
  console.log('   2. Skills auto-load via ~/.gemini/GEMINI.md');
  console.log('');
  console.log('✅ Done!');
}

// ─── Main ──────────────────────────────────────────────────

function main() {
  banner();
  step1_createDir();
  step2_checkDuplicates();
  step3_installSkills();
  step4_installScripts();
  step5_updateGeminiMd();
  step6_cleanup();
  step7_verify();
  footer();
}

main();
