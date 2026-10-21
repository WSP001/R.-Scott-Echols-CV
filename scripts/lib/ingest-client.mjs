/**
 * ingest-client.mjs — shared client for the Cloud Run POST /ingest endpoint
 * FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
 *
 * Used by:
 *   scripts/ingest-linkedin-posts.mjs      Shares.csv  → linkedin_history
 *   scripts/sync-seatrace-milestones.mjs   SeaTrace    → business_seatrace
 *   scripts/sync-published-posts.mjs       published   → social_published
 *
 * Contract (scripts/api_server.py):
 *   POST {VECTOR_ENGINE_URL}/ingest
 *   Header  X-Ingest-Secret: {INGEST_SECRET}
 *   Body    { content, partition, source, modality, metadata }
 *   Reply   { status: "ingested" | "skipped", id, partition }
 *
 * Dedupe is server-side on (partition, content_hash), so re-running any of
 * these scripts is safe and reports "skipped" instead of duplicating a chunk.
 *
 * SECURITY: INGEST_SECRET is read from the environment and sent as a header.
 * It is never printed, never written to a file, and never included in an
 * error message — HTTP failures report the status code only.
 */

const DEFAULT_TIMEOUT_MS = 60_000;

export class IngestError extends Error {}

/** Read config from the environment. Throws with a fixable message if unset. */
export function loadConfig({ requireSecret = true } = {}) {
  const baseUrl = (process.env.VECTOR_ENGINE_URL || "").trim().replace(/\/$/, "");
  const secret = (process.env.INGEST_SECRET || "").trim();

  if (!baseUrl) {
    throw new IngestError(
      "VECTOR_ENGINE_URL is not set. It is the Cloud Run retrieval service base URL.\n" +
        "  PowerShell:  $env:VECTOR_ENGINE_URL = '<cloud-run-url>'"
    );
  }
  if (requireSecret && !secret) {
    throw new IngestError(
      "INGEST_SECRET is not set. Read it from the Cloud Run secret, export it for\n" +
        "  this shell only, and remove it afterwards:\n" +
        "  PowerShell:  $env:INGEST_SECRET = '<secret>'  ...  Remove-Item Env:\\INGEST_SECRET"
    );
  }
  return { baseUrl, secret };
}

/** Ingest one chunk. Returns "ingested" | "skipped". */
export async function ingestChunk(config, { content, partition, source, modality = "text", metadata = {} }) {
  const body = JSON.stringify({ content, partition, source, modality, metadata });

  let resp;
  try {
    resp = await fetch(`${config.baseUrl}/ingest`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Ingest-Secret": config.secret,
      },
      body,
      signal: AbortSignal.timeout(DEFAULT_TIMEOUT_MS),
    });
  } catch (err) {
    throw new IngestError(
      `Ingest endpoint unreachable (${err?.name === "TimeoutError" ? "timeout" : "network error"}). ` +
        "Check VECTOR_ENGINE_URL and that Cloud Run is deployed and awake."
    );
  }

  if (!resp.ok) {
    // Status only. The response body can echo the submitted content.
    const hint =
      {
        401: "INGEST_SECRET does not match the value on Cloud Run.",
        400: "Unknown partition, or empty content.",
        502: "Embedding or database failure — check GEMINI_API_KEY and DATABASE_URL on Cloud Run.",
        503: "INGEST_SECRET or DATABASE_URL is not configured on Cloud Run.",
      }[resp.status] || "Unexpected status from the ingest endpoint.";
    throw new IngestError(`Ingest rejected with HTTP ${resp.status}. ${hint}`);
  }

  const result = await resp.json();
  return result?.status === "skipped" ? "skipped" : "ingested";
}

/** Report the live corpus state. Returns the /health payload. */
export async function health(config) {
  const resp = await fetch(`${config.baseUrl}/health`, {
    signal: AbortSignal.timeout(20_000),
  });
  return resp.json();
}

/**
 * Run a batch with dry-run support and honest reporting.
 *
 * dryRun defaults to TRUE everywhere (AGENTS.md: "Always dry-run first").
 * Nothing reaches the corpus until --commit is passed explicitly.
 */
export async function runBatch(chunks, { dryRun = true, label = "chunks" } = {}) {
  console.log(`\n${chunks.length} ${label} prepared.`);

  if (dryRun) {
    console.log("\nDRY RUN — nothing was sent. Pass --commit to ingest.\n");
    for (const [i, c] of chunks.slice(0, 3).entries()) {
      const preview = c.content.replace(/\s+/g, " ").slice(0, 160);
      console.log(`  [${i + 1}] partition=${c.partition} source=${c.source}`);
      console.log(`      ${preview}${c.content.length > 160 ? "..." : ""}`);
    }
    if (chunks.length > 3) console.log(`  ... and ${chunks.length - 3} more`);
    const partitions = [...new Set(chunks.map((c) => c.partition))];
    console.log(`\n  Target partitions: ${partitions.join(", ")}`);
    return { ingested: 0, skipped: 0, failed: 0, dryRun: true };
  }

  const config = loadConfig();
  const stats = { ingested: 0, skipped: 0, failed: 0, dryRun: false };

  for (const [i, chunk] of chunks.entries()) {
    const n = `${i + 1}/${chunks.length}`;
    try {
      const status = await ingestChunk(config, chunk);
      stats[status]++;
      console.log(`  ${status === "skipped" ? "→" : "✓"} ${n} ${status} (${chunk.partition})`);
    } catch (err) {
      stats.failed++;
      console.error(`  ✗ ${n} ${err.message}`);
      // A bad secret or missing table fails every remaining chunk identically.
      // Stop rather than emit hundreds of copies of the same error.
      if (err instanceof IngestError && /HTTP (401|503)/.test(err.message)) {
        console.error("\nAborting — this failure applies to every chunk.");
        break;
      }
    }
  }

  console.log(
    `\nDone. ${stats.ingested} ingested, ${stats.skipped} already present, ${stats.failed} failed.`
  );
  return stats;
}

/** Minimal flag parser — keeps the scripts dependency-free. */
export function parseArgs(argv) {
  const args = { _: [], commit: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--commit") args.commit = true;
    else if (a === "--dry-run") args.commit = false;
    else if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else args[key] = true;
    } else args._.push(a);
  }
  return args;
}
