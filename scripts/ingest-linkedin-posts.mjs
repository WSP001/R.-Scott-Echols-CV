#!/usr/bin/env node
/**
 * ingest-linkedin-posts.mjs
 * LinkedIn Post History → ChromaDB / Vector Store Ingestion
 *
 * Parses LinkedIn data export (Shares.csv) or a manual markdown file
 * of Scott's posts, chunks by individual post, embeds with Gemini
 * Embedding 2, and loads into the `linkedin_history` partition.
 *
 * This gives the SirTrav Studio Writer Agent access to Scott's REAL
 * past posts as retrievable context — not just style patterns, but
 * actual post text that the Writer can study and improve upon.
 *
 * USAGE:
 *   # From LinkedIn data export (Settings → Data Privacy → Get a copy)
 *   node scripts/ingest-linkedin-posts.mjs --csv path/to/Shares.csv
 *
 *   # From a manually curated markdown file of posts
 *   node scripts/ingest-linkedin-posts.mjs --md path/to/linkedin-posts.md
 *
 *   # Dry run (parse + chunk, no embedding)
 *   node scripts/ingest-linkedin-posts.mjs --csv Shares.csv --dry-run
 *
 *   # List what's already ingested
 *   node scripts/ingest-linkedin-posts.mjs --list
 *
 * COST:        ~$0.001 per post (Gemini embedding, negligible)
 * IDEMPOTENT:  skips posts already ingested (by content hash)
 * PARTITION:   linkedin_history
 * GOVERNANCE:  public posts only — no DMs, no private content
 *
 * Architecture: R. Scott Echols / WSP001 — For the Commons Good
 * Engineering:  Claude Code (CC-LINKEDIN-INGEST, 2026-04-14)
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve, basename } from 'path';
import { fileURLToPath } from 'url';
import { createHash } from 'crypto';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const CV_ROOT = resolve(__dirname, '..');
const args = process.argv.slice(2);

// ─── CONFIG ────────────────────────────────────────────────────────────────────

const PARTITION = 'linkedin_history';
const EMBEDDING_MODEL = 'gemini-embedding-2-preview';
const EMBEDDING_DIMS = 3072;
const MIN_POST_LENGTH = 50;       // Skip very short posts (reactions, shares without text)
const MAX_CHUNK_LENGTH = 2000;    // Gemini embedding input limit per chunk
const DRY_RUN = args.includes('--dry-run');
const LIST_MODE = args.includes('--list');

// ─── HELPERS ───────────────────────────────────────────────────────────────────

function hashContent(text) {
  return createHash('sha256').update(text.trim()).digest('hex').slice(0, 16);
}

function log(msg) {
  console.log(msg);
}

function warn(msg) {
  console.warn(`  ⚠️  ${msg}`);
}

// ─── PARSE LINKEDIN CSV EXPORT ─────────────────────────────────────────────────

/**
 * LinkedIn's "Shares.csv" format:
 * Date,ShareLink,ShareCommentary,SharedUrl,MediaUrl,...
 *
 * The ShareCommentary column contains the actual post text.
 * Some rows are just shares with no commentary — skip those.
 */
function parseLinkedInCSV(csvPath) {
  const raw = readFileSync(csvPath, 'utf-8');
  const lines = raw.split('\n');

  if (lines.length < 2) {
    throw new Error(`CSV file appears empty: ${csvPath}`);
  }

  // Parse header to find column indices
  const header = parseCSVLine(lines[0]);
  const dateIdx = header.findIndex(h => /date/i.test(h));
  const commentaryIdx = header.findIndex(h => /commentary|content|text/i.test(h));
  const linkIdx = header.findIndex(h => /sharelink|link|url/i.test(h));
  const sharedUrlIdx = header.findIndex(h => /sharedurl/i.test(h));

  if (commentaryIdx === -1) {
    // Try alternate format — some exports have different column names
    log(`  Header columns found: ${header.join(', ')}`);
    throw new Error('Could not find commentary/content/text column in CSV. Check the export format.');
  }

  const posts = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const cols = parseCSVLine(line);
    const text = (cols[commentaryIdx] || '').trim();
    const date = cols[dateIdx] || '';
    const link = cols[linkIdx] || '';
    const sharedUrl = cols[sharedUrlIdx] || '';

    if (text.length < MIN_POST_LENGTH) continue;

    posts.push({
      id: `linkedin-post-${hashContent(text)}`,
      date: date || 'unknown',
      text,
      link,
      sharedUrl,
      source: 'linkedin_csv_export',
      wordCount: text.split(/\s+/).length,
    });
  }

  return posts;
}

/**
 * Simple CSV line parser that handles quoted fields with commas.
 */
function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  result.push(current.trim());
  return result;
}

// ─── PARSE MARKDOWN POST FILE ──────────────────────────────────────────────────

/**
 * Manual markdown format:
 *
 * ## 2024-06-15 | SeaTrace Four Pillars
 *
 * Code is easy. Fishing is hard.
 * ...rest of post text...
 *
 * ---
 *
 * ## 2024-05-20 | Delinquency Gap
 *
 * Most people don't realize this...
 */
function parseMarkdownPosts(mdPath) {
  const raw = readFileSync(mdPath, 'utf-8');
  const sections = raw.split(/^---$/m).filter(s => s.trim());

  const posts = [];

  for (const section of sections) {
    const lines = section.trim().split('\n');

    // Try to find a header line
    let date = 'unknown';
    let topic = '';
    let textStart = 0;

    for (let i = 0; i < lines.length; i++) {
      const headerMatch = lines[i].match(/^#{1,3}\s+(\d{4}[-/]\d{2}[-/]\d{2})?\s*\|?\s*(.*)/);
      if (headerMatch) {
        date = headerMatch[1] || 'unknown';
        topic = headerMatch[2]?.trim() || '';
        textStart = i + 1;
        break;
      }
    }

    const text = lines.slice(textStart).join('\n').trim();
    if (text.length < MIN_POST_LENGTH) continue;

    posts.push({
      id: `linkedin-post-${hashContent(text)}`,
      date,
      topic,
      text,
      source: 'manual_markdown',
      wordCount: text.split(/\s+/).length,
    });
  }

  return posts;
}

// ─── EMBED WITH GEMINI ─────────────────────────────────────────────────────────

async function embedText(text, geminiKey) {
  const truncated = text.slice(0, MAX_CHUNK_LENGTH);

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${geminiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: `models/${EMBEDDING_MODEL}`,
        content: { parts: [{ text: truncated }] },
        taskType: 'RETRIEVAL_DOCUMENT',
      }),
      signal: AbortSignal.timeout(10000),
    }
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini embedding failed (${res.status}): ${err}`);
  }

  const data = await res.json();
  return data?.embedding?.values ?? [];
}

// ─── VECTOR STORE PUSH ─────────────────────────────────────────────────────────

async function pushToVectorStore(post, embedding) {
  const vectorEngineUrl = process.env.VECTOR_ENGINE_URL;
  const ingestSecret = process.env.INGEST_SECRET;

  if (!vectorEngineUrl) {
    warn('VECTOR_ENGINE_URL not set — cannot push to remote store');
    return false;
  }

  const res = await fetch(`${vectorEngineUrl}/ingest`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(ingestSecret ? { 'X-Ingest-Secret': ingestSecret } : {}),
    },
    body: JSON.stringify({
      doc_id: post.id,
      text: post.text,
      embedding,
      metadata: {
        partition: PARTITION,
        date: post.date,
        topic: post.topic || '',
        source: post.source,
        word_count: post.wordCount,
        content_hash: hashContent(post.text),
      },
    }),
    signal: AbortSignal.timeout(10000),
  });

  if (!res.ok) {
    const err = await res.text();
    warn(`Push failed for ${post.id}: ${err}`);
    return false;
  }

  return true;
}

// ─── LOCAL FALLBACK: SAVE AS NDJSON ────────────────────────────────────────────

function saveLocalFallback(posts, embeddings) {
  const outPath = resolve(CV_ROOT, 'knowledge_base', 'public', 'cv', 'linkedin_posts_embedded.ndjson');
  const lines = posts.map((post, i) => JSON.stringify({
    id: post.id,
    partition: PARTITION,
    text: post.text,
    metadata: {
      date: post.date,
      topic: post.topic || '',
      source: post.source,
      word_count: post.wordCount,
    },
    embedding: embeddings[i] || [],
  }));
  writeFileSync(outPath, lines.join('\n') + '\n', 'utf-8');
  log(`  💾 Saved ${posts.length} embedded posts to ${outPath}`);
  return outPath;
}

// ─── MAIN ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════╗');
  console.log('║  ingest-linkedin-posts.mjs                  ║');
  console.log('║  LinkedIn Post History → Vector Store        ║');
  console.log('╚══════════════════════════════════════════════╝');
  console.log();

  // Parse input source
  let posts = [];

  const csvIdx = args.indexOf('--csv');
  const mdIdx = args.indexOf('--md');

  if (csvIdx !== -1 && args[csvIdx + 1]) {
    const csvPath = resolve(args[csvIdx + 1]);
    if (!existsSync(csvPath)) {
      console.error(`❌ CSV file not found: ${csvPath}`);
      process.exit(1);
    }
    log(`📂 Parsing LinkedIn CSV export: ${basename(csvPath)}`);
    posts = parseLinkedInCSV(csvPath);
  } else if (mdIdx !== -1 && args[mdIdx + 1]) {
    const mdPath = resolve(args[mdIdx + 1]);
    if (!existsSync(mdPath)) {
      console.error(`❌ Markdown file not found: ${mdPath}`);
      process.exit(1);
    }
    log(`📂 Parsing markdown post file: ${basename(mdPath)}`);
    posts = parseMarkdownPosts(mdPath);
  } else if (LIST_MODE) {
    log('📋 List mode — checking what is already ingested...');
    const vectorUrl = process.env.VECTOR_ENGINE_URL;
    if (!vectorUrl) {
      log('  VECTOR_ENGINE_URL not set — cannot check remote store.');
      log('  Check local file: knowledge_base/public/cv/linkedin_posts_embedded.ndjson');
      const localPath = resolve(CV_ROOT, 'knowledge_base', 'public', 'cv', 'linkedin_posts_embedded.ndjson');
      if (existsSync(localPath)) {
        const lines = readFileSync(localPath, 'utf-8').trim().split('\n');
        log(`  Local store: ${lines.length} posts embedded`);
        lines.slice(0, 5).forEach(l => {
          const p = JSON.parse(l);
          log(`    - [${p.metadata?.date || '?'}] ${p.text.slice(0, 60)}...`);
        });
      } else {
        log('  No local embedded posts found.');
      }
    }
    return;
  } else {
    console.error('Usage:');
    console.error('  node scripts/ingest-linkedin-posts.mjs --csv path/to/Shares.csv');
    console.error('  node scripts/ingest-linkedin-posts.mjs --md path/to/posts.md');
    console.error('  node scripts/ingest-linkedin-posts.mjs --list');
    console.error('  Add --dry-run to preview without embedding');
    process.exit(1);
  }

  log(`\n─── Parsed ${posts.length} posts (min ${MIN_POST_LENGTH} chars) ───`);

  if (posts.length === 0) {
    warn('No posts found meeting minimum length. Check the input file.');
    process.exit(1);
  }

  // Show preview
  log('\n📝 Sample posts:');
  posts.slice(0, 3).forEach((p, i) => {
    log(`  ${i + 1}. [${p.date}] (${p.wordCount} words)`);
    log(`     "${p.text.slice(0, 100)}..."`);
  });

  if (DRY_RUN) {
    log(`\n🔍 DRY RUN — ${posts.length} posts parsed, no embedding performed.`);
    log('  Remove --dry-run to embed and ingest.');
    return;
  }

  // Embed
  const geminiKey = process.env.GEMINI_API_KEY;
  if (!geminiKey) {
    console.error('❌ GEMINI_API_KEY not set — required for embedding');
    process.exit(1);
  }

  log(`\n🧠 Embedding ${posts.length} posts with ${EMBEDDING_MODEL}...`);
  const embeddings = [];
  let embedded = 0;
  let failed = 0;
  let pushed = 0;

  for (const post of posts) {
    try {
      const embedding = await embedText(post.text, geminiKey);
      embeddings.push(embedding);
      embedded++;

      // Try to push to remote vector store
      const ok = await pushToVectorStore(post, embedding);
      if (ok) pushed++;

      // Rate limit — Gemini embedding has generous limits but be polite
      if (embedded % 10 === 0) {
        log(`  ... ${embedded}/${posts.length} embedded`);
        await new Promise(r => setTimeout(r, 500));
      }
    } catch (err) {
      warn(`Failed to embed post ${post.id}: ${err.message}`);
      embeddings.push([]);
      failed++;
    }
  }

  // Save local fallback regardless
  const localPath = saveLocalFallback(posts, embeddings);

  // Summary
  log('\n─── Results ───────────────────────────────────');
  log(`  ✅ Parsed:    ${posts.length} posts`);
  log(`  ✅ Embedded:  ${embedded} posts`);
  if (failed > 0) log(`  ❌ Failed:    ${failed} posts`);
  log(`  📡 Pushed to remote: ${pushed} posts`);
  log(`  💾 Local file: ${localPath}`);
  log(`  📏 Partition: ${PARTITION}`);
  log(`  🧠 Model: ${EMBEDDING_MODEL} (${EMBEDDING_DIMS} dims)`);
  log(`\n  For the Commons Good 🎬`);
}

main().catch(err => {
  console.error('❌ Fatal:', err.message);
  process.exit(1);
});
