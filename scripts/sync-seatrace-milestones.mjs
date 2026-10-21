#!/usr/bin/env node
/**
 * sync-seatrace-milestones.mjs — SeaTrace milestones → business_seatrace
 * FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
 *
 * The packethander (SeaTrace) integration point. Requires NO changes to
 * packethander itself — it reads a milestone export and turns each entry into
 * a narrative chunk the chatbot can discuss and the social pipeline can post
 * about.
 *
 *   SeaTrace milestone → business_seatrace (pgvector)
 *                      → /api/chat can discuss real operational status
 *                      → /api/social-generate can draft a post about it
 *
 * TIER NOTE: business_seatrace is a BUSINESS partition. Nothing ingested here
 * is reachable by a public chat request — that boundary is enforced in
 * scripts/api_server.py, not here. Do not move this to a public partition to
 * "make the chatbot more useful"; commercial operational data is gated on
 * purpose.
 *
 * Usage:
 *   node scripts/sync-seatrace-milestones.mjs --file milestones.json
 *   node scripts/sync-seatrace-milestones.mjs --file milestones.json --commit
 *   node scripts/sync-seatrace-milestones.mjs --sample            # see the shape
 *
 * Input shape (JSON array, or { milestones: [...] }):
 *   {
 *     "event": "500th catch verification processed",
 *     "date": "2026-09-01",
 *     "pillar": "DeckSide",
 *     "compliance": ["NOAA SIMP", "FDA FSMA 204"],
 *     "detail": "optional extra sentence, used verbatim if present"
 *   }
 *
 * STATUS: the live packethander pull is NOT wired — the milestone export
 * endpoint has not been specified. This script is complete for the file path
 * and tested against the --sample fixture. When the endpoint exists, add a
 * fetch in loadMilestones() and nothing else needs to change.
 */

import { readFileSync, existsSync } from "node:fs";
import { runBatch, parseArgs } from "./lib/ingest-client.mjs";

const PARTITION = "business_seatrace";

const PILLARS = {
  SeaSide: "vessel and catch origin",
  DeckSide: "at-sea verification and species mapping",
  DockSide: "landing, compliance and chain of custody",
  MarketSide: "consumer traceability and settlement",
};

const SAMPLE = [
  {
    event: "500th catch verification processed",
    date: "2026-09-01",
    pillar: "DeckSide",
    compliance: ["NOAA SIMP", "FDA FSMA 204"],
  },
  {
    event: "QR traceability rollout to three distribution partners",
    date: "2026-08-14",
    pillar: "MarketSide",
    compliance: ["FDA FSMA 204"],
  },
];

/**
 * Milestone → narrative chunk.
 *
 * Retrieval quality depends on the chunk reading like prose, not like a record.
 * An embedding of `{"event":"500th catch verification","pillar":"DeckSide"}`
 * sits nowhere near the vector for "how many catches have you verified?" — the
 * sentence form does.
 */
function toChunk(m, sourceName) {
  const date = m.date || "an unspecified date";
  const pillar = m.pillar && PILLARS[m.pillar] ? m.pillar : null;
  const pillarPhrase = pillar ? ` in the ${pillar} stage (${PILLARS[pillar]})` : "";
  const compliance = Array.isArray(m.compliance) ? m.compliance.filter(Boolean) : [];
  const compliancePhrase = compliance.length
    ? ` This work is carried out under ${compliance.join(" and ")} requirements.`
    : "";
  const detail = m.detail ? ` ${String(m.detail).trim()}` : "";

  const content =
    `SeaTrace milestone: ${m.event}${pillarPhrase}, recorded ${date}.` +
    `${compliancePhrase}${detail}` +
    ` SeaTrace is the marine traceability platform operated by World Seafood Producers,` +
    ` structured as a four-stage pipeline: SeaSide, DeckSide, DockSide and MarketSide.`;

  return {
    content,
    partition: PARTITION,
    source: `seatrace_operational:${m.date || "undated"}`,
    modality: "text",
    metadata: {
      partition: PARTITION,
      source: "seatrace_operational",
      date: m.date || null,
      pillar: pillar,
      compliance,
      event: m.event,
      synced_by: "sync-seatrace-milestones.mjs",
      ingest_source: sourceName,
    },
  };
}

function loadMilestones(args) {
  if (args.sample) return { items: SAMPLE, name: "--sample fixture" };

  if (!args.file || args.file === true) {
    console.error("Usage: node scripts/sync-seatrace-milestones.mjs --file <milestones.json> [--commit]");
    console.error("       node scripts/sync-seatrace-milestones.mjs --sample");
    process.exit(1);
  }
  if (!existsSync(args.file)) {
    console.error(`✗ File not found: ${args.file}`);
    process.exit(1);
  }
  const parsed = JSON.parse(readFileSync(args.file, "utf-8"));
  const items = Array.isArray(parsed) ? parsed : parsed?.milestones;
  if (!Array.isArray(items)) {
    console.error("✗ Expected a JSON array, or an object with a `milestones` array.");
    process.exit(1);
  }
  return { items, name: args.file };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const { items, name } = loadMilestones(args);

  const valid = [];
  let rejected = 0;
  for (const m of items) {
    if (!m?.event || typeof m.event !== "string") {
      rejected++;
      continue;
    }
    valid.push(toChunk(m, name));
  }

  console.log(`Source: ${name}`);
  console.log(`  ${valid.length} milestones, ${rejected} rejected (missing \`event\`)`);
  if (args.sample && !args.commit) {
    console.log("\nGenerated chunk text:\n");
    console.log(`  ${valid[0].content}\n`);
  }

  if (valid.length === 0) process.exit(1);
  await runBatch(valid, { dryRun: !args.commit, label: "SeaTrace milestones" });
}

main().catch((err) => {
  console.error(`\n✗ ${err.message}`);
  process.exit(1);
});
