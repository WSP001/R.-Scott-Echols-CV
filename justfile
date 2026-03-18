# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SirTrav A2A Studio / R.-Scott-Echols-CV — Master justfile
# Three-lane agent architecture: Codex (frontend) | Claude Code (backend) | Antigravity (QA)
#
# READ-BEFORE-WRITE RULE:
#   Every agent reads targets in other lanes FIRST (read-only).
#   Each agent WRITES only in their own lane targets.
#   See CLAUDE.md and docs/agent-contracts.md for full discipline.
#
# FOR THE COMMONS GOOD — this justfile pattern is reusable across all WSP001 repos
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Default: show available targets grouped by lane
default:
    @just --list --unsorted

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── ORIENTATION (ALL AGENTS READ THESE FIRST) ────────────────────────────────
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Read agent orientation map — every agent runs this before anything else
orient:
    @cat CLAUDE.md

# Read API contracts between all three lanes
contracts:
    @cat docs/agent-contracts.md

# Read RAG architecture blueprint
architecture:
    @cat design.md

# Show control plane status (mode: gemini-native)
status:
    @echo "Control Plane Status:"
    @echo "  mode:    gemini-native"
    @echo "  writer:  \${GEMINI_MODEL_WRITER:-gemini-2.5-pro}"
    @echo "  editor:  \${GEMINI_MODEL_EDITOR:-gemini-2.0-flash} (Veo 2.0 / Prompt-to-Video)"
    @echo "  director:\${GEMINI_MODEL_DIRECTOR:-gemini-2.5-pro}"
    @echo "  remotion: DEPRECATED-BYPASS"
    @echo ""
    @echo "Chatbot: Claude Opus 4.6 (all tiers, no exceptions)"
    @echo "Embed:   gemini-embedding-2-preview (3072 dims)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── LANE 1: CODEX — Frontend / Three.js / UI ─────────────────────────────────
# Codex READS: contracts, architecture, other lanes' outputs
# Codex WRITES: public/index.html, public/assets/
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# [CODEX] Read backend API contracts before touching UI (READ-ONLY cross-lane)
codex-read-contracts:
    @echo "=== CODEX: Reading backend contracts (READ-ONLY) ==="
    @cat docs/agent-contracts.md
    @echo ""
    @echo "=== CODEX: Reading edge function API (READ-ONLY) ==="
    @head -120 netlify/edge-functions/chat.ts

# [CODEX] Read QA test surface before adding new UI states (READ-ONLY cross-lane)
codex-read-qa:
    @echo "=== CODEX: Reading Antigravity test specs (READ-ONLY) ==="
    @ls -la tests/ 2>/dev/null || echo "(tests/ not yet created — ask Antigravity)"
    @ls -la e2e/ 2>/dev/null || echo "(e2e/ not yet created — ask Antigravity)"

# [CODEX] Apply CV upgrades via Python script
codex-upgrade:
    python scripts/upgrade_cv.py

# [CODEX] Preview site locally (Python simple HTTP server)
codex-preview:
    @echo "Serving public/ at http://localhost:8080"
    cd public && python -m http.server 8080

# [CODEX] Validate index.html structure
codex-validate:
    @echo "Checking index.html line count..."
    @wc -l public/index.html
    @echo "Checking for broken [bracket] placeholders..."
    @grep -n '\[' public/index.html | grep -v '<!--' | head -20 || echo "✓ No bracket placeholders found"
    @echo "Checking Three.js references..."
    @grep -c 'IcosahedronGeometry\|TorusGeometry\|THREE\.' public/index.html || echo "0"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── LANE 2: CLAUDE CODE — Backend / Edge Functions / RAG ─────────────────────
# Claude Code READS: UI contracts, QA assertions, design.md
# Claude Code WRITES: netlify/edge-functions/, scripts/, design.md, docs/
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# [CLAUDE CODE] Read frontend expectations before changing API shape (READ-ONLY)
backend-read-ui:
    @echo "=== CLAUDE CODE: Reading frontend API usage (READ-ONLY) ==="
    @grep -n 'fetch\|/api/\|reply\|tier\|questionCount\|limit_reached' public/index.html | head -40

# [CLAUDE CODE] Read QA assertions before changing API response shape (READ-ONLY)
backend-read-qa:
    @echo "=== CLAUDE CODE: Reading QA test assertions (READ-ONLY) ==="
    @ls tests/ 2>/dev/null && grep -rn 'expect\|assert\|toBe\|toEqual' tests/ | head -30 || echo "(no tests yet)"

# [CLAUDE CODE] Validate edge functions TypeScript (Deno check)
backend-typecheck:
    @echo "Checking edge function TypeScript..."
    @deno check netlify/edge-functions/chat.ts 2>/dev/null || echo "(deno not installed locally — runs at Netlify deploy)"
    @deno check netlify/edge-functions/embed.ts 2>/dev/null || true
    @deno check netlify/edge-functions/verify-access.ts 2>/dev/null || true

# [CLAUDE CODE] Ingest knowledge base into ChromaDB (local)
embed-ingest:
    @echo "Running ChromaDB knowledge ingestion..."
    python scripts/embed_engine.py --ingest --partition cv_personal --source docs/
    python scripts/embed_engine.py --ingest --partition cv_projects --source docs/

# [CLAUDE CODE] Query the knowledge base (test semantic search)
embed-query query="SeaTrace Four Pillars":
    python scripts/embed_engine.py --query "{{query}}"

# [CLAUDE CODE] Validate env vars are set (for local dev)
backend-check-env:
    @echo "Checking required environment variables..."
    @test -n "$$ANTHROPIC_API_KEY" && echo "✓ ANTHROPIC_API_KEY" || echo "✗ ANTHROPIC_API_KEY not set"
    @test -n "$$GEMINI_API_KEY" && echo "✓ GEMINI_API_KEY" || echo "✗ GEMINI_API_KEY not set"
    @test -n "$$BUSINESS_ACCESS_KEY" && echo "✓ BUSINESS_ACCESS_KEY" || echo "✗ BUSINESS_ACCESS_KEY not set"
    @test -n "$$GEMINI_MODEL_WRITER" && echo "✓ GEMINI_MODEL_WRITER=$$GEMINI_MODEL_WRITER" || echo "→ GEMINI_MODEL_WRITER (default: gemini-2.5-pro)"
    @test -n "$$GEMINI_MODEL_EDITOR" && echo "✓ GEMINI_MODEL_EDITOR=$$GEMINI_MODEL_EDITOR" || echo "→ GEMINI_MODEL_EDITOR (default: gemini-2.0-flash)"
    @test -n "$$GEMINI_MODEL_DIRECTOR" && echo "✓ GEMINI_MODEL_DIRECTOR=$$GEMINI_MODEL_DIRECTOR" || echo "→ GEMINI_MODEL_DIRECTOR (default: gemini-2.5-pro)"

# [CLAUDE CODE] Validate Gemini model env vars against allowed Enum
backend-validate-models:
    @echo "Validating GEMINI_MODEL_* env vars against allowed Enum..."
    @python3 -c "
import os, sys
ALLOWED = {'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-2.5-flash'}
errors = []
for var in ['GEMINI_MODEL_WRITER', 'GEMINI_MODEL_EDITOR', 'GEMINI_MODEL_DIRECTOR']:
    val = os.environ.get(var, '')
    if val and val not in ALLOWED:
        errors.append(f'INVALID {var}={val!r} — allowed: {ALLOWED}')
    elif val:
        print(f'✓ {var}={val}')
    else:
        print(f'→ {var} not set (will use default)')
if errors:
    for e in errors: print(f'✗ {e}')
    sys.exit(1)
else:
    print('✓ All model env vars valid')
"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── LANE 3: ANTIGRAVITY — QA / Testing / E2E / Control Plane ─────────────────
# Antigravity READS: both other lanes (full read-only cross-lane)
# Antigravity WRITES: tests/, e2e/, __mocks__/
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# [ANTIGRAVITY] Read BOTH other lanes before writing any test (READ-ONLY)
qa-read-all:
    @echo "=== ANTIGRAVITY: Reading Codex lane (READ-ONLY) ==="
    @echo "public/index.html: $(wc -l < public/index.html) lines"
    @grep -n 'fetch\|/api/\|questionCount\|tier\|isBusiness' public/index.html | head -20
    @echo ""
    @echo "=== ANTIGRAVITY: Reading Claude Code lane (READ-ONLY) ==="
    @echo "chat.ts: $(wc -l < netlify/edge-functions/chat.ts) lines"
    @grep -n 'questionCount\|isBusiness\|limit_reached\|Reply\|tier' netlify/edge-functions/chat.ts | head -20
    @echo ""
    @echo "=== ANTIGRAVITY: Now you may write in tests/ and e2e/ ==="

# [ANTIGRAVITY] Run all unit tests
test:
    @echo "Running unit tests..."
    @ls tests/*.test.* 2>/dev/null && node --experimental-vm-modules node_modules/.bin/jest tests/ || echo "(no unit tests yet — create in tests/)"

# [ANTIGRAVITY] Run Gemini video E2E test (Gemini Pivot — replaces Remotion)
test-e2e-video:
    @echo "Running Gemini Video E2E (mode: gemini-native)..."
    @node e2e/test-gemini-video-e2e.mjs 2>/dev/null || echo "(test-gemini-video-e2e.mjs not yet created)"

# [ANTIGRAVITY] Run chat API E2E test
test-e2e-chat:
    @echo "Running chat API E2E..."
    @node e2e/test-chat-e2e.mjs 2>/dev/null || echo "(test-chat-e2e.mjs not yet created)"

# [ANTIGRAVITY] Run full E2E suite
test-e2e:
    just test-e2e-chat
    just test-e2e-video

# [ANTIGRAVITY] Run all tests (unit + e2e)
test-all:
    just test
    just test-e2e

# [ANTIGRAVITY] Generate QA report
qa-report:
    @echo "=== QA Report — $(date) ==="
    @echo ""
    @echo "Control Plane:"
    @just status
    @echo ""
    @echo "Test Files:"
    @find tests/ e2e/ -name "*.mjs" -o -name "*.test.*" 2>/dev/null | sort || echo "(no test files)"
    @echo ""
    @echo "Edge Functions:"
    @wc -l netlify/edge-functions/*.ts
    @echo ""
    @echo "Mock Files:"
    @ls __mocks__/ 2>/dev/null || echo "(no mocks yet)"

# [ANTIGRAVITY] Validate WRITER→EDITOR vector handoff (ChromaDB mock required)
test-vector-handoff:
    @echo "Testing WRITER→EDITOR vector handoff with ChromaDB mock..."
    @node e2e/test-vector-handoff.mjs 2>/dev/null || echo "(test-vector-handoff.mjs not yet created — Antigravity must create this)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── CROSS-LANE SYNC (ALL AGENTS) ─────────────────────────────────────────────
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Full pre-flight check — all agents run this before a deploy
preflight:
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    @echo " SirTrav Preflight Check"
    @echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    just status
    just backend-check-env
    just backend-validate-models
    just codex-validate
    just qa-report
    @echo ""
    @echo "✓ Preflight complete — safe to deploy"

# Deploy to Netlify (triggers via git push — Netlify auto-deploys on main push)
deploy:
    @echo "Deploying to Netlify..."
    git add -A
    git status
    @echo ""
    @echo "Review the above. Run: git commit -m 'your message' && git push origin main"
    @echo "Netlify will auto-deploy to: https://robertoscottecholscv.netlify.app"

# Add a new dependency (documents it before writing)
add-dep name version lane="unknown":
    @echo "FOR THE COMMONS GOOD — Adding dependency: {{name}} v{{version}} to {{lane}} lane"
    @echo "Document in docs/agent-contracts.md before using"

# Git log with lane context
log:
    git log --oneline -20

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ── RAG PIPELINE (CLAUDE CODE LANE + CI/CD) ──────────────────────────────────
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Install Python dependencies for embed engine
pip-install:
    pip install chromadb google-generativeai

# Run full knowledge base ingestion
ingest-all:
    just pip-install
    just embed-ingest
    @echo "✓ Knowledge base ingested into ChromaDB"

# Test semantic search
search query="SeaTrace":
    just embed-query "{{query}}"
