/**
 * verify-cv-site.mjs
 * WSP001 — CV site local verifier
 * Run: node scripts/verify-cv-site.mjs
 *
 * Checks public/index.html for all required elements without needing a browser.
 * Architecture: Scott Echols / WSP001 — Commons Good
 * Engineering: Claude Sonnet 4.6
 */

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const HTML = join(ROOT, 'public', 'index.html');

const html = readFileSync(HTML, 'utf8');

let passed = 0;
let failed = 0;

function check(label, condition, detail = '') {
  if (condition) {
    console.log(`  ✅ ${label}${detail ? ' — ' + detail : ''}`);
    passed++;
  } else {
    console.log(`  ❌ ${label}${detail ? ' — ' + detail : ''}`);
    failed++;
  }
}

console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(' CV Site Verifier — WSP001');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

// ── Cards ──────────────────────────────────────────────────────────────────
console.log('PROJECT CARDS:');
check('Sir James Adventures card', html.includes('Sir James Adventures'));
check('LearnQuest card', html.includes('LearnQuest'));
check('SeaTrace card', html.includes('SeaTrace'));
check('SirTrav card', html.includes('SirTrav'));
check('SeaTrace role tag', html.includes('Founder') && html.includes('SeaTrace'));
check('SirTrav tagline', html.includes('seven-agent A2A'));

// ── Stats ──────────────────────────────────────────────────────────────────
console.log('\nSTATS:');
check('Years Experience 39+', html.includes('data-count="39"'));

// ── Chat ───────────────────────────────────────────────────────────────────
console.log('\nCHAT WIRING:');
check('chat-send element', html.includes('id="chat-send"') || html.includes("id='chat-send'"));
check('chat-input element', html.includes('id="chat-input"') || html.includes("id='chat-input'"));
// Scripts are at bottom of <body> — DOM is ready when they run. No DOMContentLoaded required.
check('Scripts at bottom of body (DOM-safe)', html.indexOf('<script') > html.indexOf('chat-send'));
check('/api/chat endpoint', html.includes('/api/chat'));

// ── Audio ──────────────────────────────────────────────────────────────────
console.log('\nAUDIO:');
check('Audio player element', html.includes('id="sjAudio"'));
check('Audio base path set', html.includes('/audio/sir-james/'));
const audioDir = join(ROOT, 'public', 'audio', 'sir-james');
check('Audio directory exists', existsSync(audioDir));
const expectedFiles = [
  'Sir James Adventures.mp3',
  "_Sir James' Adventure Song004.mp3",
  "_Sir James' Adventure Song006.mp3",
];
const missingFiles = expectedFiles.filter(f => !existsSync(join(audioDir, f)));
check('Audio files deployed', missingFiles.length === 0,
  missingFiles.length > 0 ? `MISSING: ${missingFiles.join(', ')}` : 'all present');

// ── URLs ───────────────────────────────────────────────────────────────────
console.log('\nKEY URLS:');
check('worldseafoodproducers.com', html.includes('worldseafoodproducers.com'));
check('sirtrav-a2a-studio.netlify.app', html.includes('sirtrav-a2a-studio.netlify.app'));
check('sirjamesadventures link', html.includes('sirjames'));
check('seatrace link', html.includes('seatrace.worldseafoodproducers.com'));

// ── Identity ───────────────────────────────────────────────────────────────
console.log('\nIDENTITY:');
const identityPath = join(ROOT, 'public', 'data', 'identity.json');
if (existsSync(identityPath)) {
  const identity = JSON.parse(readFileSync(identityPath, 'utf8'));
  check('yearsExperience: 39', identity.yearsExperience === 39);
  check('planned_projects has LearnQuest', identity.planned_projects?.includes('LearnQuest'));
  check('public_projects has SirJamesAdventures', identity.public_projects?.includes('SirJamesAdventures'));
} else {
  check('identity.json exists', false, 'file missing');
}

// ── Summary ────────────────────────────────────────────────────────────────
console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(` Result: ${passed} passed, ${failed} failed`);
if (failed === 0) {
  console.log(' ✅ ALL CHECKS PASS — ready for deploy');
} else {
  console.log(` ⚠️  ${failed} issue(s) need attention`);
}
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

process.exit(failed > 0 ? 1 : 0);
