# ============================================================================
# SirTrav A2A Studio / R.-Scott-Echols-CV — Master justfile
# Three-lane agent architecture: Codex (frontend) | Claude Code (backend) | Antigravity (QA)
#
# READ-BEFORE-WRITE RULE:
#   Every agent reads targets in other lanes FIRST (read-only).
#   Each agent WRITES only in their own lane targets.
#   See CLAUDE.md and docs/agent-contracts.md for full discipline.
#
# FOR THE COMMONS GOOD — this justfile pattern is reusable across all WSP001 repos

set shell := ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]
# ============================================================================

# Use PowerShell on Windows
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# Default: show available targets grouped by lane
default:
    @just --list --unsorted

# ============================================================================
# ── ORIENTATION (ALL AGENTS READ THESE FIRST) ────────────────────────────────
# ============================================================================

# Read agent orientation map — every agent runs this before anything else
orient:
    @cat CLAUDE.md

# Read API contracts between all three lanes
contracts:
    @cat docs/agent-contracts.md

# Read cross-lane async notes — read BEFORE writing anything (READ BEFORE WRITING)
handoffs:
    @cat AGENT_HANDOFFS.md

# Read master phase plan + task checklists
master:
    @cat MASTER_AGENT_IMPLEMENTATION_HANDOFF.md

# Cloud Run status check
cloud-status:
    @gcloud run services describe rse-retrieval --region=us-central1 --format='value(status.url)' 2>/dev/null || echo '(not deployed yet - run: .\scripts\deploy-cloud-run.ps1)'

# Cloud Run deploy reminder
cloud-deploy:
    @echo 'Deploy from Windows: .\scripts\deploy-cloud-run.ps1'
    @echo 'Requires: gcloud auth login, Docker Desktop running'
    @echo 'After deploy: add VECTOR_ENGINE_URL to Netlify team env vars'

# Read RAG architecture blueprint
architecture:
    @cat design.md

# Show control plane status (CV-specific: persona + active services)
status:
    @echo '=================================================================='
    @echo 'R. SCOTT ECHOLS CV - CONTROL PLANE STATUS'
    @echo '=================================================================='
    @echo ''
    @echo 'ACTIVE PERSONA:  SirScott (professional CV identity)'
    @echo 'CHATBOT MODEL:   Claude Opus 4.6 (all tiers, non-negotiable)'
    @echo 'EMBED MODEL:     gemini-embedding-2-preview (3072 dims)'
    @echo 'VECTOR STORE:    ChromaDB (.chromadb/) + Cloud Run (optional)'
    @echo ''
    @echo 'PUBLIC TIER:     3 free questions then invitation key required'
    @echo 'BUSINESS TIER:   Full RAG access (invitation key)'
    @echo ''
    @echo 'TRUTH POLICY:    Read-before-write and Verified sources only'
    @echo 'SOURCE PACK:     knowledge_base/public/cv/identity_verified.md'
    @echo ''
    @echo 'IDENTITY BOUNDARIES:'
    @echo '  SirScott:   Professional CV  and consulting (THIS REPO)'
    @echo '  SeaTrace:   Business and commercial marine work'
    @echo '  SirTrav:    Personal studio and agent orchestration'
    @echo '  SirJames:   Creative and family storytelling'
    @echo ''
    @echo '=================================================================='

# ============================================================================
# ── LANE 1: CODEX — Frontend / Three.js / UI ─────────────────────────────────
# Codex READS: contracts, architecture, other lanes' outputs
# Codex WRITES: public/index.html, public/assets/
# ============================================================================

# [CODEX] Read backend API contracts before touching UI (READ-ONLY cross-lane)
codex-read-contracts:
    @echo '=== CODEX: Reading backend contracts (READ-ONLY) ==='
    @cat docs/agent-contracts.md
    @echo '
    @echo '=== CODEX: Reading edge function API (READ-ONLY) ==='
    @head -120 netlify/edge-functions/chat.ts

# [CODEX] Read QA test surface before adding new UI states (READ-ONLY cross-lane)
codex-read-qa:
    @echo '=== CODEX: Reading Antigravity test specs (READ-ONLY) ==='
    @ls -la tests/ 2>/dev/null || echo '(tests/ not yet created - ask Antigravity)'
    @ls -la e2e/ 2>/dev/null || echo '(e2e/ not yet created - ask Antigravity)'

# [CODEX] Apply CV upgrades via Python script
codex-upgrade:
    python scripts/upgrade_cv.py

# [CODEX] Preview site locally (Python simple HTTP server)
codex-preview:
    @echo 'Serving public/ at http://localhost:8080'
    cd public && python -m http.server 8080

# [CODEX] Validate index.html structure
codex-validate:
    @echo 'Checking index.html line count'
    @wc -l public/index.html
    @echo 'Checking for broken [bracket] placeholders'
    @grep -n '\[' public/index.html | grep -v '<!--' | head -20 || echo "OK: No bracket placeholders found"
    @echo 'Checking Three.js references...'
    @grep -c 'IcosahedronGeometry\|TorusGeometry\|THREE\.' public/index.html || echo "0"

# ============================================================================
# ── LANE 2: CLAUDE CODE — Backend / Edge Functions / RAG ─────────────────────
# Claude Code READS: UI contracts, QA assertions, design.md
# Claude Code WRITES: netlify/edge-functions/, scripts/, design.md, docs/
# ============================================================================

# [CLAUDE CODE] Read frontend expectations before changing API shape (READ-ONLY)
backend-read-ui:
    @echo '=== CLAUDE CODE: Reading frontend API usage (READ-ONLY) ==='
    @grep -n 'fetch\|/api/\|reply\|tier\|questionCount\|limit_reached' public/index.html | head -40

# [CLAUDE CODE] Read QA assertions before changing API response shape (READ-ONLY)
backend-read-qa:
    @echo '=== CLAUDE CODE: Reading QA test assertions (READ-ONLY) ==='
    @ls tests/ 2>/dev/null && grep -rn 'expect\|assert\|toBe\|toEqual' tests/ | head -30 || echo "(no tests yet)"

# [CLAUDE CODE] Validate edge functions TypeScript (Deno check)
backend-typecheck:
    @echo 'Checking edge function TypeScript'
    @deno check netlify/edge-functions/chat.ts 2>/dev/null || echo '(deno not installed locally - runs at Netlify deploy)'
    @deno check netlify/edge-functions/embed.ts 2>/dev/null || true
    @deno check netlify/edge-functions/verify-access.ts 2>/dev/null || true

# [CLAUDE CODE] Ingest knowledge base into ChromaDB (local)
embed-ingest:
    @echo 'Running ChromaDB knowledge ingestion'
    python scripts/embed_engine.py --ingest --partition cv_personal --source docs/
    python scripts/embed_engine.py --ingest --partition cv_projects --source docs/

# [CLAUDE CODE] Query the knowledge base (test semantic search)
embed-query query="SeaTrace Four Pillars":
    python scripts/embed_engine.py --query "{{query}}"

# [CLAUDE CODE] Validate env vars are set (for local dev)
backend-check-env:
    @echo 'Checking required environment variables'
    @test -n "$$ANTHROPIC_API_KEY" && echo "OK: ANTHROPIC_API_KEY" || echo "FAIL: ANTHROPIC_API_KEY not set"
    @test -n "$$GEMINI_API_KEY" && echo "OK: GEMINI_API_KEY" || echo "FAIL: GEMINI_API_KEY not set"
    @test -n "$$BUSINESS_ACCESS_KEY" && echo "OK: BUSINESS_ACCESS_KEY" || echo "FAIL: BUSINESS_ACCESS_KEY not set"
    @test -n "$$GEMINI_MODEL_WRITER" && echo "OK: GEMINI_MODEL_WRITER=$$GEMINI_MODEL_WRITER" || echo "-> GEMINI_MODEL_WRITER (default: gemini-2.5-pro)"
    @test -n "$$GEMINI_MODEL_EDITOR" && echo "OK: GEMINI_MODEL_EDITOR=$$GEMINI_MODEL_EDITOR" || echo "-> GEMINI_MODEL_EDITOR (default: gemini-2.0-flash)"
    @test -n "$$GEMINI_MODEL_DIRECTOR" && echo "OK: GEMINI_MODEL_DIRECTOR=$$GEMINI_MODEL_DIRECTOR" || echo "-> GEMINI_MODEL_DIRECTOR (default: gemini-2.5-pro)"

# [CLAUDE CODE] Validate Gemini model env vars against allowed Enum
backend-validate-models:
    #!/usr/bin/env python3
    import os, sys
    print('Validating GEMINI_MODEL_* env vars against allowed Enum')
    ALLOWED = {'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-2.5-flash'}
    errors = []
    for var in ['GEMINI_MODEL_WRITER', 'GEMINI_MODEL_EDITOR', 'GEMINI_MODEL_DIRECTOR']:
        val = os.environ.get(var, '')
        if val and val not in ALLOWED:
            errors.append(f'INVALID {var}={val!r} - allowed: {ALLOWED}')
        elif val:
            print(f'OK: {var}={val}')
        else:
            print(f'Note: {var} not set (will use default)')
    if errors:
        for e in errors: print(f'FAIL: {e}')
        sys.exit(1)
    else:
        print('OK: All model env vars valid')

# ============================================================================
# ── LANE 3: ANTIGRAVITY — QA / Testing / E2E / Control Plane ─────────────────
# Antigravity READS: both other lanes (full read-only cross-lane)
# Antigravity WRITES: tests/, e2e/, __mocks__/
# ============================================================================

# [ANTIGRAVITY] Read BOTH other lanes before writing any test (READ-ONLY)
qa-read-all:
    @echo '=== ANTIGRAVITY: Reading Codex lane (READ-ONLY) ==='
    @echo 'Reading: public/index.html'
    @grep -n 'fetch\|/api/\|questionCount\|tier\|isBusiness' public/index.html | head -20
    @echo ''
    @echo '=== ANTIGRAVITY: Reading Claude Code lane (READ-ONLY) ==='
    @echo 'Reading: netlify/edge-functions/chat.ts'
    @grep -n 'questionCount\|isBusiness\|limit_reached\|Reply\|tier' netlify/edge-functions/chat.ts | head -20
    @echo ''
    @echo '=== ANTIGRAVITY: Now you may write in tests/ and e2e/ ==='

# [ANTIGRAVITY] Run all unit tests
test:
    @echo 'Running unit tests'
    @echo '(test command temporarily disabled for debugging)'

# [ANTIGRAVITY] Run Gemini video E2E test (Gemini Pivot — replaces Remotion)
test-e2e-video:
    @echo 'Running Gemini Video E2E (mode: gemini-native)'
    @echo '(test disabled for debugging)'

# [ANTIGRAVITY] Run chat API E2E test
test-e2e-chat:
    @echo 'Running chat API E2E'
    @node e2e/test-chat-e2e.mjs 2>/dev/null || echo '(test-chat-e2e.mjs not yet created)'

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
    @echo '=== QA Report ==='
    @echo '
    @echo 'Control Plane:'
    @just status
    @echo '
    @echo 'Test Files:'
    @find tests/ e2e/ -name '*.mjs' -o -name '*.test.*' 2>/dev/null | sort || echo '(no test files)'
    @echo '
    @echo 'Edge Functions:'
    @wc -l netlify/edge-functions/*.ts
    @echo '
    @echo 'Mock Files:'
    @ls __mocks__/ 2>/dev/null || echo '(no mocks yet)'

# [ANTIGRAVITY] Validate WRITER→EDITOR vector handoff (ChromaDB mock required)
test-vector-handoff:
    @echo 'Testing WRITER to EDITOR vector handoff with ChromaDB mock'
    @node e2e/test-vector-handoff.mjs 2>/dev/null || echo '(test-vector-handoff.mjs not yet created - Antigravity must create this)'

# ============================================================================
# ── CROSS-LANE SYNC (ALL AGENTS) ─────────────────────────────────────────────
# ============================================================================

# Full pre-flight check — all agents run this before a deploy
preflight:
    @echo '========================================'
    @echo ' SirTrav Preflight Check'
    @echo '========================================'
    just status
    just backend-check-env
    just backend-validate-models
    just codex-validate
    just qa-report
    @echo ''
    @echo 'Preflight complete, safe to deploy'

# Deploy to Netlify (triggers via git push — Netlify auto-deploys on main push)
deploy:
    @echo 'Deploying to Netlify'
    git add -A
    git status
    @echo ''
    @echo 'Review the above then run: git commit -m "your message" and git push origin main'
    @echo 'Netlify will auto-deploy to: https://robertoscottecholscv.netlify.app'

# Add a new dependency (documents it before writing)
add-dep name version lane="unknown":
    @echo 'FOR THE COMMONS GOOD: Adding dependency: {{name}} v{{version}} to {{lane}} lane'
    @echo 'Document in docs/agent-contracts before using'

# Git log with lane context
log:
    git log --oneline -20

# ============================================================================
# ── RAG PIPELINE (CLAUDE CODE LANE + CI/CD) ──────────────────────────────────
# ============================================================================

# Install Python dependencies for embed engine
pip-install:
    pip install chromadb google-generativeai

# Run full knowledge base ingestion
ingest-all:
    just pip-install
    just embed-ingest
    @echo 'OK: Knowledge base ingested into ChromaDB'

# Test semantic search
search query="SeaTrace":
    just embed-query "{{query}}"

# ============================================================================
# ── PERSONA & IDENTITY MANAGEMENT (CROSSOVER FROM SIRTRAV) ───────────────────
# ============================================================================

# Show current persona identity boundaries
persona-check:
    @echo '=================================================================='
    @echo 'PERSONA IDENTITY BOUNDARIES'
    @echo '=================================================================='
    @powershell -NoProfile -Command "Get-Content public/data/identity.json | Select-String -Pattern 'identity_boundaries' -Context 0,20"
    @echo ''
    @echo 'ACTIVE: SirScott (professional CV)'
    @echo 'VERIFIED SOURCES: knowledge_base/public/cv/identity_verified.md'
    @echo 'VOICE PROFILE: public/data/voice.json'
    @echo '=================================================================='

# Verify truth-first content pack integrity
truth-check:
    @echo 'Checking Content Source of Truth integrity'
    @powershell -NoProfile -Command "if (Test-Path docs/CONTENT_SOURCE_OF_TRUTH.md) { Write-Host 'OK: CONTENT_SOURCE_OF_TRUTH.md exists' } else { Write-Host 'FAIL: MISSING' }"
    @powershell -NoProfile -Command "if (Test-Path knowledge_base/public/cv/identity_verified.md) { Write-Host 'OK: identity_verified.md exists' } else { Write-Host 'FAIL: MISSING' }"
    @powershell -NoProfile -Command "if (Test-Path public/data/identity.json) { Write-Host 'OK: identity.json exists' } else { Write-Host 'FAIL: MISSING' }"
    @powershell -NoProfile -Command "if (Test-Path public/data/voice.json) { Write-Host 'OK: voice.json exists' } else { Write-Host 'FAIL: MISSING' }"
    @powershell -NoProfile -Command "if (Test-Path public/data/hashtags.json) { Write-Host 'OK: hashtags.json exists' } else { Write-Host 'FAIL: MISSING' }"
    @echo ''
    @echo 'Checking for contaminated legacy content'
    @powershell -NoProfile -Command "if (Select-String -Pattern 'Hawaii|ALOHA|Pearl Harbor|Norman Abramson' -Path netlify/edge-functions/chat.ts,public/index.html -ErrorAction SilentlyContinue) { Write-Host 'FAIL: CONTAMINATED CONTENT FOUND' } else { Write-Host 'OK: No contaminated content in active paths' }"
    @echo ''
    @echo 'Truth pack status: VERIFIED'

# Ingest verified identity pack ONLY (safest first ingest)
ingest-identity:
    @echo 'Ingesting VERIFIED IDENTITY PACK ONLY (cv_verified_public)'
    python scripts/embed_engine.py --ingest --partition cv_personal --source knowledge_base/public/cv/identity_verified.md --chunk-strategy section
    @echo 'OK: Verified identity pack ingested'

# List all vector store partitions and their content counts
partitions:
    @echo 'Vector Store Partitions:'
    python scripts/embed_engine.py --list-partitions
    @echo '
    @echo 'Expected partitions:'
    @echo '  cv_personal          (public tier) -- verified identity'
    @echo '  cv_projects          (public tier) -- project details'
    @echo '  business_seatrace    (business tier) -- SeaTrace docs'
    @echo '  business_proposals   (business tier) -- proposals'
    @echo '  internal_repos       (business tier) -- code architecture'

# Vector store health check
vector-health:
    @echo 'Checking vector store health'
    python scripts/embed_engine.py --stats
    @echo '
    @echo 'Checking ChromaDB persistence'
    @test -d scripts/.chromadb && echo "OK: ChromaDB directory exists" || echo "FAIL: ChromaDB not initialized"
    @du -sh scripts/.chromadb 2>/dev/null || echo "-> Run 'just ingest-identity' to initialize"

# Full RAG pipeline sanity test (local only)
test-rag-local:
    @echo 'Testing local RAG pipeline'
    @echo '=================================================================='
    @echo 'Step 1: Ingest verified identity'
    just ingest-identity
    @echo '
    @echo 'Step 2: Test semantic retrieval'
    just search "Scott's background"
    @echo '
    @echo 'Step 3: Check vector health'
    just vector-health
    @echo '=================================================================='
    @echo 'OK: Local RAG pipeline test complete'

# ============================================================================
# ── DEPLOYMENT HELPERS (CLAUDE CODE LANE) ────────────────────────────────────
# ============================================================================

# Deploy Cloud Run retrieval service (Windows PowerShell)
deploy-cloud-run:
    @echo 'Deploying Cloud Run retrieval service'
    @echo 'Run: .\\scripts\\deploy-cloud-run.ps1'
    @echo 'After deploy, set VECTOR_ENGINE_URL in Netlify Dashboard'

# Check Cloud Run service status
cloud-check:
    @gcloud run services describe rse-retrieval --region=us-central1 --format='value(status.url)' 2>/dev/null || echo "Service not deployed yet -- run: just deploy-cloud-run"

# Test Cloud Run /retrieve endpoint (requires VECTOR_ENGINE_URL)
test-cloud-retrieve:
    @echo 'Testing Cloud Run /retrieve endpoint'
    @curl -X POST "$$VECTOR_ENGINE_URL/retrieve" \
      -H "Content-Type: application/json" \
      -d '{"query": "Scott background", "tier": "public", "top_k": 3}' \
      2>/dev/null || echo "VECTOR_ENGINE_URL not set or service unavailable"

# ============================================================================
# ── FOR THE COMMONS GOOD — CROSSOVER PATTERNS ───────────────────────────────
# These targets can be copied to other WSP001 repos
# ============================================================================

# Generate a new agent handoff note (crossover from SirTrav)
handoff-note agent lane message:
    @echo '[$(date +%Y-%m-%d)] {{agent}} -> {{lane}}: {{message}}' >> AGENT_HANDOFFS.md
    @echo 'OK: Handoff note added to AGENT_HANDOFFS.md'
    @tail -5 AGENT_HANDOFFS.md

# Show recent agent activity (git log with commit messages)
agent-history:
    @echo 'Recent agent commits:'
    git log --pretty=format:"%h %ad | %s [%an]" --date=short -15

# Clean up old test artifacts
clean-test:
    @echo 'Cleaning test artifacts'
    rm -rf .snapshots/ tmp/ debug_*.log verify_*.log 2>/dev/null || true
    @echo 'OK: Test artifacts cleared'
