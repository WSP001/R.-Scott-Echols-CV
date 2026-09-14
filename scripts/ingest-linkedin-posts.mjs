#!/usr/bin/env node
/**
 * ingest-linkedin-posts.mjs — LinkedIn Shares.csv → linkedin_history partition
 * FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
 *
 * STAGE 1 of the social pipeline. This is what gives SirScottA2A-STUDIO
 * Scott's actual writing voice instead of a generic LLM register:
 *
 *   Shares.csv → linkedin_history (pgvector)
 *              → SirScottA2A /query linkedin_history(5)
 *              → generated posts that sound like Scott
 *
 * Getting the export:
 *   LinkedIn → Settings → Data privacy → Get a copy of your data
 *            → "Posts" → Shares.csv
 *
 * Usage:
 *   node scripts/ingest-linkedin-posts.mjs --csv Shares.csv            # dry run
 *   node scripts/ingest-linkedin-posts.mjs --csv Shares.csv --commit   # ingest
 *
 * Environment (only needed with --commit):
 *   VECTOR_ENGINE_URL   Cloud Run retrieval base URL
 *   INGEST_SECRET       read from the Cloud Run secret, exported for one shell
 *
 * Dry run is the default. Nothing is sent without --commit.
 */

import { readFileSync, existsSync } from "node:fs";
import { basename } from "node:path";
import { runBatch, parseArgs } from "./lib/ingest-client.mjs";

const PARTITION = "linkedin_history";
const MIN_LENGTH = 80; // below this a post is a link drop, not voice signal

/**
 * RFC 4180 CSV parser.
 *
 * Written by hand rather than split(",") because LinkedIn post bodies contain
 * commas, embedded newlines and escaped double quotes as a matter of course —
 * a naive split shreds roughly every post with a line break in it.
 */
function parseCSV(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  const source = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text; // strip BOM

  for (let i = 0; i < source.length; i++) {
    const ch = source[i];

    if (inQuotes) {
      if (ch === '"') {
        if (source[i + 1] === '"') {
          field += '"';
          i++;
        } else inQuotes = false;
      } else field += ch;
      continue;
    }

    if (ch === '"') inQuotes = true;
    else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && source[i + 1] === "\n") i++;
      row.push(field);
      field = "";
      if (row.some((f) => f.length > 0)) rows.push(row);
      row = [];
    } else field += ch;
  }
  row.push(field);
  if (row.some((f) => f.length > 0)) rows.push(row);

  if (rows.length === 0) return [];
  const header = rows[0].map((h) => h.trim());
  return rows.slice(1).map((r) => {
    const obj = {};
    header.forEach((h, i) => {
      obj[h] = (r[i] ?? "").trim();
    });
    return obj;
  });
}

/** Column names differ slightly between LinkedIn export vintages. */
function pick(row, candidates) {
  for (const name of candidates) {
    for (const key of Object.keys(row)) {
      if (key.toLowerCase().replace(/[^a-z]/g, "") === name) return row[key];
    }
  }
  return "";
}

function buildChunks(rows, sourceName) {
  const chunks = [];
  let skippedShort = 0;
  let skippedReshare = 0;

  for (const row of rows) {
    const commentary = pick(row, ["sharecommentary", "commentary", "text"]);
    const date = pick(row, ["date", "shareddate", "createdat"]);
    const url = pick(row, ["sharedurl", "url", "link"]);
    const visibility = pick(row, ["visibility"]);
    const mediaCategory = pick(row, ["sharemediacategory", "mediacategory"]);

    const content = commentary.replace(/\r\n/g, "\n").trim();

    // A reshare with no commentary is someone else's voice, not Scott's.
    // Ingesting it would teach the generator the wrong style.
    if (!content) {
      skippedReshare++;
      continue;
    }
    if (content.length < MIN_LENGTH) {
      skippedShort++;
      continue;
    }

    chunks.push({
      content,
      partition: PARTITION,
      source: `linkedin:${date || "undated"}`,
      modality: "text",
      metadata: {
        partition: PARTITION,
        platform: "linkedin",
        type: "original_post",
        date: date || null,
        shared_url: url || null,
        visibility: visibility || null,
        media_category: mediaCategory || null,
        ingest_source: sourceName,
        character_count: content.length,
      },
    });
  }

  return { chunks, skippedShort, skippedReshare };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const csvPath = args.csv || process.env.WSP001_LINKEDIN_CSV;

  if (!csvPath || csvPath === true) {
    console.error("Usage: node scripts/ingest-linkedin-posts.mjs --csv <Shares.csv> [--commit]");
    console.error("\nGet Shares.csv from: LinkedIn → Settings → Data privacy → Get a copy of your data → Posts");
    process.exit(1);
  }
  if (!existsSync(csvPath)) {
    console.error(`✗ File not found: ${csvPath}`);
    process.exit(1);
  }

  console.log(`Parsing ${basename(csvPath)}`);
  const rows = parseCSV(readFileSync(csvPath, "utf-8"));
  console.log(`  ${rows.length} rows`);
  if (rows.length > 0) {
    console.log(`  Columns: ${Object.keys(rows[0]).join(", ")}`);
  }

  const { chunks, skippedShort, skippedReshare } = buildChunks(rows, basename(csvPath));

  console.log(`\n  ${chunks.length} original posts with commentary`);
  console.log(`  ${skippedReshare} skipped — reshare with no commentary (not Scott's voice)`);
  console.log(`  ${skippedShort} skipped — under ${MIN_LENGTH} characters (link drop, no voice signal)`);

  if (chunks.length === 0) {
    console.error("\n✗ Nothing to ingest. Check that the CSV is the 'Shares' export.");
    process.exit(1);
  }

  const stats = await runBatch(chunks, { dryRun: !args.commit, label: "LinkedIn posts" });

  if (!stats.dryRun && stats.ingested > 0) {
    console.log("\nVerify the voice corpus is queryable:");
    console.log('  curl -s -X POST "$VECTOR_ENGINE_URL/query" -H "Content-Type: application/json" \\');
    console.log('    -d \'{"query":"producer voice","partitions":["linkedin_history"],"n_results":5}\'');
    console.log("\nIt must return non-empty context_chunks. Empty means ingest did not land.");
  }
}

main().catch((err) => {
  console.error(`\n✗ ${err.message}`);
  process.exit(1);
});
