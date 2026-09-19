#!/usr/bin/env node
/**
 * ingest-seatrace-public-packet.mjs
 * ---------------------------------
 * Public -> business "packet switch" for the CV chatbot.
 *
 * Reads the PUBLIC proof fixtures published by WSP001/MARKETING-SeaTrace-MSC-v007
 * (#CATCH / #HARVEST / finished-product / buyer reverse-trace scenarios), projects
 * them into plain-language knowledge chunks, runs them through the same
 * public/private boundary gate the SeaTrace harness enforces, and pushes them to
 * the CV vector store's `business_seatrace` partition via Cloud Run /ingest.
 *
 * Only the public rail crosses. Anything matching a private field name or a
 * blocked public claim aborts the run — nothing is "cleaned up" silently.
 * Embedding happens server-side in api_server.py (Gemini Embedding 2), so this
 * script needs no Gemini key and no LLM call: zero model cost.
 *
 * Usage:
 *   node scripts/ingest-seatrace-public-packet.mjs --fixtures ../MARKETING-SeaTrace-MSC-v007/data/fixtures --dry-run
 *   node scripts/ingest-seatrace-public-packet.mjs --fixtures <dir>            # push (needs VECTOR_ENGINE_URL, INGEST_SECRET)
 *   node scripts/ingest-seatrace-public-packet.mjs --fixtures <dir> --out packet.ndjson   # write packet only
 *
 * Exit codes: 0 ok · 2 boundary violation · 3 push failure · 1 usage/read error
 */

import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, basename } from 'node:path';
import { createHash } from 'node:crypto';

const PARTITION = 'business_seatrace';
const SOURCE_PREFIX = 'seatrace-msc-v007/public';
const PACKET_VERSION = 1;

// Mirror of MARKETING-SeaTrace-MSC-v007/src/seatrace_4p3l/gates/blocked_terms.py.
// Kept in sync by hand; a drift here fails closed (we block MORE, never less).
const BLOCKED_PUBLIC_PATTERNS = [
  'SIMP-certified', 'verified by NOAA', 'verified by USDA', 'verified by FDA',
  'live API', 'exact coordinates', 'price per pound', 'SeaTrace003', 'SeaTrace-ODOO',
  'federal verification', 'compliance guaranteed', '$CHECK', '$BOOK',
];
const PRIVATE_FIELD_NAMES = new Set([
  'private_identity_ref', 'exact_gps_track', 'captain_name', 'vessel_registration',
  'private_assertion_ref', 'crew_notes', 'hold_map_detail', 'exception_notes',
  'private_invoice_ref', 'unit_price', 'margin', 'customer_terms', 'unit_cost',
  'invoice_line_id', 'commercial_calculation',
]);

const log = (m) => console.log(m);
const warn = (m) => console.warn(`⚠️  ${m}`);

// ─── ARGS ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { fixtures: null, dryRun: false, out: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--fixtures') args.fixtures = argv[++i];
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--dry-run') args.dryRun = true;
    else if (a === '--help' || a === '-h') return null;
    else { console.error(`Unknown argument: ${a}`); return null; }
  }
  if (!args.fixtures) return null;
  return args;
}

// ─── BOUNDARY GATE ────────────────────────────────────────────────────────────

export function findViolations(fixtureName, value, path = '') {
  const violations = [];
  if (Array.isArray(value)) {
    value.forEach((v, i) => violations.push(...findViolations(fixtureName, v, `${path}[${i}]`)));
  } else if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value)) {
      if (PRIVATE_FIELD_NAMES.has(k)) {
        violations.push(`${fixtureName}: private field "${path ? path + '.' : ''}${k}" present in public fixture`);
      }
      violations.push(...findViolations(fixtureName, v, path ? `${path}.${k}` : k));
    }
  } else if (typeof value === 'string') {
    const lowered = value.toLowerCase();
    for (const term of BLOCKED_PUBLIC_PATTERNS) {
      if (lowered.includes(term.toLowerCase())) {
        violations.push(`${fixtureName}: blocked public term "${term}" at ${path}`);
      }
    }
  }
  return violations;
}

// ─── PROJECTION (public fixture -> plain-language knowledge chunk) ────────────

const line = (label, v) => (v === undefined || v === null || v === '' ? null : `${label}: ${v}`);
const join = (lines) => lines.filter(Boolean).join('\n');

export function projectFixture(fixtureName, data) {
  const scenario = data.scenario_id ?? 'unknown-scenario';
  const chunks = [];

  if (data.seaside) {
    const s = data.seaside;
    chunks.push({
      pillar: 'SeaSide',
      text: join([
        `SeaTrace public proof — SeaSide (origin context), scenario ${scenario}.`,
        line('Trip', s.trip_id),
        line('Trip window', s.trip_window_start && s.trip_window_end ? `${s.trip_window_start} to ${s.trip_window_end}` : null),
        line('General region', s.general_region),
        line('Vessel class', s.vessel_class),
        line('Gear category', s.gear_category),
        line('Origin confidence', s.origin_confidence_label),
        line('Provenance hash', s.provenance_hash),
        'Boundary: general region and vessel class only; no exact GPS track, captain, or registration is published.',
      ]),
    });
  }

  if (data.deckside) {
    const d = data.deckside;
    chunks.push({
      pillar: 'DeckSide',
      text: join([
        `SeaTrace public proof — DeckSide #CATCH estimate, scenario ${scenario}.`,
        line('Catch estimate', d.catch_estimate_id),
        line('Species', d.species_common_name),
        line('Estimated weight', d.estimated_weight != null ? `${d.estimated_weight} ${d.estimated_weight_uom ?? ''}`.trim() : null),
        line('Estimate method', d.estimate_method),
        line('Status', d.mutable_status),
        line('Provenance hash', d.provenance_hash),
        'A #CATCH is a mutable at-sea estimate; it is not the accepted measured event.',
      ]),
    });
  }

  if (data.dockside) {
    const k = data.dockside;
    chunks.push({
      pillar: 'DockSide',
      text: join([
        `SeaTrace public proof — DockSide #HARVEST (accepted measured event), scenario ${scenario}.`,
        line('Harvest index', k.harvest_index_id),
        line('Traceability lot', k.traceability_lot_code),
        line('Landing date', k.landing_date),
        line('Received weight', k.received_weight != null ? `${k.received_weight} ${k.received_weight_uom ?? ''}`.trim() : null),
        line('Product', k.species_or_market_name),
        line('Harvest date range', k.harvest_date_range),
        line('Harvest location (general)', k.harvest_location_general),
        line('Variance vs estimate', k.variance_percent != null ? `${k.variance_percent}% (${k.variance_label ?? 'unlabelled'})` : null),
        line('Provenance hash', k.provenance_hash),
        'The #HARVEST event is the measured anchor every downstream proof cites back to.',
      ]),
    });
  }

  if (data.sku_label || data.source_spine) {
    chunks.push({
      pillar: 'DockSide',
      text: join([
        `SeaTrace public proof — finished product index, scenario ${scenario}.`,
        line('SKU', data.sku_label),
        line('Package format', data.package_format),
        line('Case count band', data.case_count_band),
        line('QR status', data.qr_status),
        line('Source harvest', data.source_harvest_id),
        line('Traceability lot', data.traceability_lot_code),
        line('Provenance hash', data.provenance_hash),
        'Case counts are published as bands, not exact counts; no cost or margin data is part of the public rail.',
      ]),
    });
  }

  if (data.marketside) {
    const m = data.marketside;
    chunks.push({
      pillar: 'MarketSide',
      text: join([
        `SeaTrace public proof — MarketSide buyer reverse trace, scenario ${scenario}.`,
        line('Buyer proof', m.buyer_proof_id),
        line('Product', m.product_description),
        line('Quantity', m.quantity != null ? `${m.quantity} ${m.quantity_uom ?? ''}`.trim() : null),
        line('Ship from (general)', m.ship_from_location_general),
        line('Ship to (general)', m.ship_to_location_general),
        line('Reverse trace status', m.reverse_trace_status),
        line('Proof packet status', m.proof_packet_status),
        line('Chain continuity', m.chain_continuity_summary),
        line('Reverse trace path', Array.isArray(m.reverse_trace_path) ? m.reverse_trace_path.join(' -> ') : m.reverse_trace_path),
        line('Claim summary', m.claim_summary),
        line('Provenance hash', m.provenance_hash),
        'Retail proof traces back to the #HARVEST origin; prices, invoices, and customer terms stay on the private rail.',
      ]),
    });
  }

  return chunks.map((c) => ({
    ...c,
    scenario_id: scenario,
    source: `${SOURCE_PREFIX}/${fixtureName}#${c.pillar.toLowerCase()}`,
    content_hash: createHash('sha256').update(c.text).digest('hex').slice(0, 16),
  }));
}

// ─── PUSH ─────────────────────────────────────────────────────────────────────

async function pushChunk(chunk, vectorEngineUrl, ingestSecret) {
  const res = await fetch(`${vectorEngineUrl}/ingest`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Ingest-Secret': ingestSecret },
    body: JSON.stringify({
      content: chunk.text,
      partition: PARTITION,
      source: chunk.source,
      modality: 'text',
    }),
    signal: AbortSignal.timeout(15000),
  });
  const bodyText = await res.text();
  if (!res.ok) return { ok: false, status: res.status, detail: bodyText.slice(0, 200) };
  let parsed;
  try { parsed = JSON.parse(bodyText); } catch { return { ok: false, status: res.status, detail: 'non-JSON /ingest body' }; }
  if (parsed?.status !== 'ingested' && parsed?.status !== 'skipped') {
    return { ok: false, status: res.status, detail: `unexpected status "${parsed?.status}"` };
  }
  return { ok: true, status: parsed.status, id: parsed.id };
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args) {
    console.error('Usage: node scripts/ingest-seatrace-public-packet.mjs --fixtures <dir> [--dry-run] [--out packet.ndjson]');
    process.exit(1);
  }

  const dir = resolve(args.fixtures);
  if (!existsSync(dir)) { console.error(`❌ fixtures dir not found: ${dir}`); process.exit(1); }
  const files = readdirSync(dir).filter((f) => f.endsWith('.public.json')).sort();
  if (files.length === 0) { console.error(`❌ no *.public.json fixtures in ${dir}`); process.exit(1); }
  log(`📦 SeaTrace public packet v${PACKET_VERSION} — ${files.length} public fixture(s) from ${dir}`);

  const violations = [];
  const chunks = [];
  for (const f of files) {
    const name = basename(f, '.public.json');
    const data = JSON.parse(readFileSync(resolve(dir, f), 'utf-8'));
    violations.push(...findViolations(name, data));
    const projected = projectFixture(name, data);
    violations.push(...projected.flatMap((c) => findViolations(`${name}#projection`, c.text, 'text')));
    chunks.push(...projected);
  }

  if (violations.length) {
    console.error(`❌ boundary gate FAILED (${violations.length}):`);
    violations.forEach((v) => console.error(`   - ${v}`));
    process.exit(2);
  }
  log(`✅ boundary gate passed — ${chunks.length} chunk(s), partition=${PARTITION}`);

  if (args.out) {
    const ndjson = chunks.map((c) => JSON.stringify({ partition: PARTITION, ...c })).join('\n') + '\n';
    writeFileSync(resolve(args.out), ndjson, 'utf-8');
    log(`💾 wrote ${chunks.length} chunk(s) to ${args.out}`);
  }

  if (args.dryRun) {
    chunks.forEach((c) => log(`  [dry-run] ${c.source} (${c.text.length} chars, hash ${c.content_hash})`));
    log('Dry run — nothing pushed.');
    return;
  }

  const vectorEngineUrl = process.env.VECTOR_ENGINE_URL;
  const ingestSecret = process.env.INGEST_SECRET;
  if (!vectorEngineUrl || !ingestSecret) {
    console.error(`❌ push disabled: VECTOR_ENGINE_URL set=${!!vectorEngineUrl}, INGEST_SECRET set=${!!ingestSecret}`);
    process.exit(3);
  }

  const summary = { ingested: 0, skipped: 0, failed: 0 };
  for (const c of chunks) {
    const r = await pushChunk(c, vectorEngineUrl.replace(/\/$/, ''), ingestSecret);
    if (!r.ok) { summary.failed++; warn(`${c.source}: HTTP ${r.status} ${r.detail}`); continue; }
    summary[r.status]++;
    log(`  ${r.status === 'ingested' ? '➕' : '↩️ '} ${c.source} -> ${r.id}`);
  }
  log(JSON.stringify({ event: 'seatrace_packet_ingest', partition: PARTITION, ...summary }));
  if (summary.failed > 0) process.exit(3);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => { console.error(`❌ ${e.message}`); process.exit(1); });
}
