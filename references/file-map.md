# File Map

These are the current trusted file anchors for the CV site and the new truth-first flow.

## Public Site Claims

- Title rotation includes `Solutions Architect` in `public/index.html`
- Hero copy includes `Senior Software Developer & Technical Lead` in `public/index.html`
- SeaTrace Four Pillars and `$4.2M` stack valuation live in `public/index.html`
- SirTrav is described as a D2A multi-agent platform in `public/index.html`
- Claude Opus 4.6 and Gemini Embedding 2 both appear in the public project card copy in `public/index.html`

## Truth Pack

- `docs/CONTENT_SOURCE_OF_TRUTH.md`
- `knowledge_base/public/cv/identity_verified.md`
- `public/data/identity.json`
- `public/data/voice.json`
- `public/data/hashtags.json`
- `public/api/identity.json`

## Runtime Contract

- Chat runtime: `netlify/edge-functions/chat.ts`
- Embedding runtime: `netlify/edge-functions/embed.ts`
- Netlify env contract: `netlify.toml`

## Audit Gate

- CLI: `scripts/truth_audit.py`
- Just targets: `truth-audit`, `truth-check`
- Ingest gate: `ingest-identity`
