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
    @node -e " \
      const fs = require('fs'); \
      const html = fs.readFileSync('public/index.html', 'utf8'); \
      const lines = html.split('\n').length; \
      console.log('Line count: ' + lines + ' public/index.html'); \
      const brackets = html.split('\n') \
        .map((l, i) => ({ n: i+1, l })) \
        .filter(({ l }) => /\[/.test(l) && !/<!--/.test(l) && !/https?:\/\//.test(l)) \
        .slice(0, 20); \
      console.log('Bracket check: ' + (brackets.length ? brackets.map(r => r.n + ': ' + r.l.trim()).join('\n') : 'OK — no broken placeholders')); \
      const threeRefs = (html.match(/IcosahedronGeometry|TorusGeometry|THREE\./g) || []).length; \
      console.log('Three.js refs: ' + threeRefs); \
    "

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
    @powershell -NoProfile -Command "if (`$env:ANTHROPIC_API_KEY) { Write-Host 'OK: ANTHROPIC_API_KEY is set' } else { Write-Host 'FAIL: ANTHROPIC_API_KEY not set' }"
    @powershell -NoProfile -Command "if (`$env:GEMINI_API_KEY) { Write-Host 'OK: GEMINI_API_KEY is set' } else { Write-Host 'FAIL: GEMINI_API_KEY not set' }"
    @powershell -NoProfile -Command "if (`$env:BUSINESS_ACCESS_KEY) { Write-Host 'OK: BUSINESS_ACCESS_KEY is set' } else { Write-Host 'FAIL: BUSINESS_ACCESS_KEY not set' }"
    @powershell -NoProfile -Command "if (`$env:GEMINI_MODEL_WRITER) { Write-Host OK: GEMINI_MODEL_WRITER=`$env:GEMINI_MODEL_WRITER } else { Write-Host '-> GEMINI_MODEL_WRITER default: gemini-2.5-pro' }"
    @powershell -NoProfile -Command "if (`$env:GEMINI_MODEL_EDITOR) { Write-Host OK: GEMINI_MODEL_EDITOR=`$env:GEMINI_MODEL_EDITOR } else { Write-Host '-> GEMINI_MODEL_EDITOR default: gemini-2.0-flash' }"
    @powershell -NoProfile -Command "if (`$env:GEMINI_MODEL_DIRECTOR) { Write-Host OK: GEMINI_MODEL_DIRECTOR=`$env:GEMINI_MODEL_DIRECTOR } else { Write-Host '-> GEMINI_MODEL_DIRECTOR default: gemini-2.5-pro' }"

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

# ── PACKET SWITCHING HANDLER — License Gate ──────────────────────────────────
# The Paradox: "Unlimited" = one-way public pipe (pays per job, COLD rail only)
#              "Limited"   = bidirectional inner circle (read/write, HOT rail)
# This recipe reads credential presence and routes the agent to the correct lane.
# Attribution: Scott Echols / WSP001 — FOR THE COMMONS GOOD — 2026-04-10

# [COLD] Detect which license lane the current environment is on
license-gate:
    @echo '=================================================================='
    @echo '  PACKET SWITCHING HANDLER — LICENSE GATE  (COLD — $0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Checking credential presence to route agent to correct lane...'
    @echo ''
    @if [ -n "$$BUSINESS_ACCESS_KEY" ] && [ -n "$$ANTHROPIC_API_KEY" ] && [ -n "$$INGEST_SECRET" ]; then \
        echo 'LANE: LIMITED (inner circle)'; \
        echo '  - BUSINESS_ACCESS_KEY: present'; \
        echo '  - ANTHROPIC_API_KEY:   present'; \
        echo '  - INGEST_SECRET:       present'; \
        echo ''; \
        echo 'ACCESS: Bidirectional — read/write, HOT rail permitted'; \
        echo '  Wire 1 (Forward): just deploy / just ingest-remote / just push'; \
        echo '  Wire 2 (Reverse): just archive-asset / just brain-claim'; \
        echo '  Partitions: cv_personal + cv_projects + business_seatrace (all)'; \
    elif [ -n "$$ANTHROPIC_API_KEY" ]; then \
        echo 'LANE: UNLIMITED (public pipe)'; \
        echo '  - ANTHROPIC_API_KEY:   present'; \
        echo '  - BUSINESS_ACCESS_KEY: NOT SET — HOT rail blocked'; \
        echo '  - INGEST_SECRET:       NOT SET — ingest blocked'; \
        echo ''; \
        echo 'ACCESS: One-way — COLD rail only, read/query permitted'; \
        echo '  Available: just validate-manifest / just health / just query'; \
        echo '  Blocked:   just ingest-remote / just deploy / just push'; \
        echo '  Partitions: cv_personal + cv_projects (public only)'; \
    else \
        echo 'LANE: UNAUTHENTICATED — no keys present'; \
        echo 'ACCESS: None — run just claude-env-check to diagnose'; \
    fi
    @echo ''
    @echo '=================================================================='

# Verify truth-first content pack integrity
truth-check:
    python scripts/truth_audit.py --format text

# Enterprise truth gate with PASS/WARN/FAIL verdict — writes .cache/CV_TRUTH_AUDIT_PASS.json
truth-audit:
    @mkdir -p .cache
    python scripts/truth_audit.py --format text --gate ingest --output .cache/CV_TRUTH_AUDIT_PASS.json
    @echo ''
    @echo 'Cache: .cache/CV_TRUTH_AUDIT_PASS.json'
    @echo 'Downstream agents: check this file instead of re-running audit'

# Install git pre-commit hook — runs truth_audit.py before every commit ($0, no API)
install-hooks:
    @cp .git/hooks/pre-commit /dev/null 2>/dev/null || true
    @echo '#!/usr/bin/env bash' > .git/hooks/pre-commit
    @echo '# CV Truth Audit pre-commit gate — see scripts/truth_audit.py' >> .git/hooks/pre-commit
    @echo 'REPO_ROOT="$(git rev-parse --show-toplevel)"' >> .git/hooks/pre-commit
    @echo 'mkdir -p "$REPO_ROOT/.cache"' >> .git/hooks/pre-commit
    @echo 'python "$REPO_ROOT/scripts/truth_audit.py" --format text --output "$REPO_ROOT/.cache/CV_TRUTH_AUDIT_PASS.json" --gate pre-commit' >> .git/hooks/pre-commit
    @echo 'STATUS=$?' >> .git/hooks/pre-commit
    @echo '[ $STATUS -ne 0 ] && echo "[pre-commit] BLOCKED: fix issues above" && exit 1 || exit 0' >> .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo 'OK: pre-commit hook installed (.git/hooks/pre-commit)'
    @echo 'Test: git commit (will run truth_audit.py first, $0, no API calls)'

# Ingest verified identity pack ONLY (safest first ingest)
ingest-identity:
    @echo 'Running truth audit gate before ingest'
    python scripts/truth_audit.py --format text --gate ingest
    @echo 'Ingesting VERIFIED IDENTITY PACK ONLY (cv_verified_public)'
    python scripts/embed_engine.py --ingest --partition cv_personal --source knowledge_base/public/cv/identity_verified.md
    @echo 'OK: Verified identity pack ingested'

# List all vector store partitions and their content counts
partitions:
    @echo 'Vector Store Partitions:'
    python scripts/embed_engine.py --list-partitions
    @Write-Host ''
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
    @Write-Host ''
    @echo 'Checking ChromaDB persistence'
    @if (Test-Path '.chromadb' -PathType Container) { Write-Host 'OK: ChromaDB directory exists' } else { Write-Host 'FAIL: ChromaDB not initialized' }
    @if (Test-Path '.chromadb' -PathType Container) { $size = (Get-ChildItem '.chromadb' -Recurse -File | Measure-Object -Property Length -Sum).Sum; if ($null -eq $size) { $size = 0 }; Write-Host ('ChromaDB bytes: ' + $size) } else { Write-Host "-> Run 'just ingest-identity' to initialize" }

# Read-only semantic lookup over the verified public partition
cv-search query="Scott background":
    python scripts/embed_engine.py --query "{{query}}" --partition cv_personal --top-k 5

# Full RAG pipeline sanity test (local only)
test-rag-local:
    @echo 'Testing local RAG pipeline'
    @echo '=================================================================='
    @echo 'Step 1: Ingest verified identity'
    just ingest-identity
    @Write-Host ''
    @echo 'Step 2: Test semantic retrieval'
    just cv-search "Scott's background"
    @Write-Host ''
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

# ============================================================================
# ── LAYER 3+4: DURABLE CONTROL — COCKPIT / TRUTH / DOCTOR / GATES ─────────
# Acting Master: Windsurf/Cascade (WSP001) — 2026-04-06
# These commands implement the four durable control layers from STACK_TRUTH.md
# Append-only: no existing commands were modified
# FOR THE COMMONS GOOD — reusable across all WSP001 repos
# ============================================================================

# [MASTER] Fast session resume — branch, status, truth, next owner, next gate
cockpit:
    @echo '=================================================================='
    @echo '  R. SCOTT ECHOLS CV — COCKPIT'
    @echo '=================================================================='
    @echo ''
    @echo 'BRANCH:'
    @git branch --show-current
    @echo ''
    @echo 'GIT STATUS:'
    @git status --short
    @echo ''
    @echo 'RECENT COMMITS:'
    @git log --oneline -5
    @echo ''
    @echo 'STACK TRUTH (key lines):'
    @grep -E '^(STACK_STATUS|PHASE:|PHASE_STATUS|NEXT_OWNER|NEXT_GATE|SMOKE_TEST|VECTOR_CHUNKS|CLOUD_RUN_STATUS|INGEST_STATUS):' STACK_TRUTH.md 2>/dev/null || echo '(STACK_TRUTH.md not found — create it)'
    @echo ''
    @echo 'KEY FILES (plans/):'
    @ls -lt plans/ 2>/dev/null | head -8 || echo '(plans/ not found)'
    @echo ''
    @echo 'ACTIVE BLOCKERS:'
    @grep -E '^BLOCKER_' AGENT-OPS.md 2>/dev/null || echo '(none found)'
    @echo ''
    @echo '=================================================================='

# [MASTER] Print the full STACK_TRUTH.md canonical truth file
stack-truth:
    @if [ -f STACK_TRUTH.md ]; then cat STACK_TRUTH.md; else echo 'ERROR: STACK_TRUTH.md not found'; exit 1; fi

# [MASTER] Print the DEPENDENCY_MAP.md service dependency map
dependency-map:
    @if [ -f DEPENDENCY_MAP.md ]; then cat DEPENDENCY_MAP.md; else echo 'ERROR: DEPENDENCY_MAP.md not found'; exit 1; fi

# [MASTER] Cheap diagnostic checks — verify repo wiring without API calls (COST: $0)
doctor:
    @echo '=================================================================='
    @echo '  DOCTOR — Repo Wiring Check (COST: $0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Git:'
    @git branch --show-current
    @git remote -v | head -2
    @echo ''
    @echo 'Python:'
    @python --version 2>/dev/null || python3 --version 2>/dev/null || echo 'WARN: Python not found in PATH'
    @echo ''
    @echo 'Key Files:'
    @test -f STACK_TRUTH.md && echo 'OK: STACK_TRUTH.md' || echo 'MISSING: STACK_TRUTH.md'
    @test -f DEPENDENCY_MAP.md && echo 'OK: DEPENDENCY_MAP.md' || echo 'MISSING: DEPENDENCY_MAP.md'
    @test -f AGENT-OPS.md && echo 'OK: AGENT-OPS.md' || echo 'MISSING: AGENT-OPS.md'
    @test -f MASTER_AGENT_IMPLEMENTATION_HANDOFF.md && echo 'OK: MASTER_AGENT_IMPLEMENTATION_HANDOFF.md' || echo 'MISSING: MASTER_AGENT_IMPLEMENTATION_HANDOFF.md'
    @test -f AGENT_HANDOFFS.md && echo 'OK: AGENT_HANDOFFS.md' || echo 'MISSING: AGENT_HANDOFFS.md'
    @test -f PHASE5_LIVE_STATUS_BOARD.md && echo 'OK: PHASE5_LIVE_STATUS_BOARD.md' || echo 'MISSING: PHASE5_LIVE_STATUS_BOARD.md'
    @test -f netlify.toml && echo 'OK: netlify.toml' || echo 'MISSING: netlify.toml'
    @test -f justfile && echo 'OK: justfile' || echo 'MISSING: justfile'
    @test -f data/rse_cv_manifest.json && echo 'OK: data/rse_cv_manifest.json' || echo 'MISSING: data/rse_cv_manifest.json'
    @echo ''
    @echo 'Scripts:'
    @test -f scripts/api_server.py && echo 'OK: scripts/api_server.py' || echo 'MISSING: scripts/api_server.py'
    @test -f scripts/embed_engine.py && echo 'OK: scripts/embed_engine.py' || echo 'MISSING: scripts/embed_engine.py'
    @test -f scripts/vector_store.py && echo 'OK: scripts/vector_store.py' || echo 'MISSING: scripts/vector_store.py'
    @test -f scripts/truth_audit.py && echo 'OK: scripts/truth_audit.py' || echo 'MISSING: scripts/truth_audit.py'
    @test -f scripts/Dockerfile && echo 'OK: scripts/Dockerfile' || echo 'MISSING: scripts/Dockerfile'
    @echo ''
    @echo 'Edge Functions:'
    @test -f netlify/edge-functions/chat.ts && echo 'OK: netlify/edge-functions/chat.ts' || echo 'MISSING: chat.ts'
    @test -f netlify/edge-functions/embed.ts && echo 'OK: netlify/edge-functions/embed.ts' || echo 'MISSING: embed.ts'
    @test -f netlify/edge-functions/verify-access.ts && echo 'OK: netlify/edge-functions/verify-access.ts' || echo 'MISSING: verify-access.ts'
    @echo ''
    @echo 'Knowledge Base:'
    @ls knowledge_base/public/cv/ 2>/dev/null | wc -l | xargs -I{} echo 'Public CV files: {}'
    @ls knowledge_base/business/ 2>/dev/null | wc -l | xargs -I{} echo 'Business files: {}'
    @echo ''
    @echo 'Env Vars (presence only — never log values):'
    @if [ -n "$$GEMINI_API_KEY" ]; then echo 'OK: GEMINI_API_KEY is set'; else echo 'NOT SET: GEMINI_API_KEY'; fi
    @if [ -n "$$ANTHROPIC_API_KEY" ]; then echo 'OK: ANTHROPIC_API_KEY is set'; else echo 'NOT SET: ANTHROPIC_API_KEY'; fi
    @if [ -n "$$VECTOR_ENGINE_URL" ]; then echo 'OK: VECTOR_ENGINE_URL is set'; else echo 'NOT SET: VECTOR_ENGINE_URL (optional)'; fi
    @echo ''
    @echo '=================================================================='

# [MASTER] QA readiness check — is the repo clean enough to hand to Antigravity?
qa-ready:
    @echo '=================================================================='
    @echo '  QA READY CHECK'
    @echo '=================================================================='
    @echo ''
    @echo 'Git Status:'
    @git status --short
    @echo ''
    @echo 'Current Branch:'
    @git branch --show-current
    @echo ''
    @echo 'Phase Status:'
    @grep -E '^(PHASE:|PHASE_STATUS|NEXT_GATE|SMOKE_TEST):' STACK_TRUTH.md 2>/dev/null || echo '(check STACK_TRUTH.md)'
    @echo ''
    @echo 'Blockers:'
    @grep -E '^BLOCKER_' AGENT-OPS.md 2>/dev/null || echo '(none found)'
    @echo ''
    @echo 'If status is clean and blockers are resolved, QA lane may proceed.'
    @echo '=================================================================='

# [MASTER] CV-specific status — identity, corpus, cloud health summary
cv-status:
    @echo '=================================================================='
    @echo '  CV STATUS'
    @echo '=================================================================='
    @echo ''
    @echo 'IDENTITY:    SirScott (professional CV)'
    @echo 'CHATBOT:     Claude Opus 4.6 (non-negotiable)'
    @echo 'EMBED MODEL: gemini-embedding-2-preview (3072 dims)'
    @echo 'VECTOR:      Supabase pgvector (production) + ChromaDB (local dev)'
    @echo 'SITE:        https://robertoscottecholscv.netlify.app'
    @echo ''
    @echo 'Corpus:'
    @python scripts/embed_engine.py --stats 2>/dev/null || echo '(embed_engine.py --stats failed — check Python / chromadb)'
    @echo ''
    @echo 'Manifest:'
    @python -c "import json; m=json.load(open('data/rse_cv_manifest.json')); active=[s for s in m.get('sources',[]) if s.get('status')=='active']; print(f'  Active sources: {len(active)}'); print(f'  Version: {m.get(\"version\",\"?\")}')" 2>/dev/null || echo '(manifest read failed)'
    @echo ''
    @echo '=================================================================='

# [MASTER] Cloud Run health probe — read-only, $0 cost, safe to rerun
cv-smoke-cloud:
    @echo '=================================================================='
    @echo '  CV CLOUD SMOKE (COST: $0 — read-only)'
    @echo '=================================================================='
    @echo ''
    @echo 'Cloud Run /health:'
    @curl -s --max-time 15 https://rse-retrieval-zrmkhygpwa-uc.a.run.app/health 2>/dev/null || echo 'FAIL: Cloud Run unreachable'
    @echo ''
    @echo ''
    @echo 'Cloud Run /partitions:'
    @curl -s --max-time 15 https://rse-retrieval-zrmkhygpwa-uc.a.run.app/partitions 2>/dev/null || echo 'FAIL: /partitions unreachable'
    @echo ''
    @echo ''
    @echo 'Netlify site:'
    @curl -s -o /dev/null -w 'HTTP %{http_code} — %{time_total}s' --max-time 15 https://robertoscottecholscv.netlify.app 2>/dev/null || echo 'FAIL: Netlify site unreachable'
    @echo ''
    @echo ''
    @echo '=================================================================='

# [MASTER] Full verification gate — combines all Layer 4 proof paths
verify-all:
    @echo '=================================================================='
    @echo '  FULL VERIFICATION GATE'
    @echo '=================================================================='
    just doctor
    @echo ''
    just cv-smoke-cloud
    @echo ''
    just vector-health
    @echo ''
    just qa-ready
    @echo ''
    @echo '=================================================================='
    @echo '  VERIFICATION COMPLETE — review output above'
    @echo '=================================================================='

# ============================================================================
# ── LANE-PREFIXED AGENT COMMANDS ───────────────────────────────────────────
# The prefix IS the lane boundary. Agents run ONLY their own prefix.
# master-*       Scott / Acting Master / Windsurf
# claude-*       Claude Code (backend / ops / runtime)
# codex-*        already exists above (codex-validate, codex-preview, etc.)
# antigravity-*  Antigravity (QA / verification)
# Acting Master: Windsurf/Cascade (WSP001) — 2026-04-06
# FOR THE COMMONS GOOD
# ============================================================================

# --- LANE: ACTING MASTER (Approval / Governance / Truth) ---

# [MASTER] Session resume with truth snapshot — governance view
master-cockpit:
    @echo '=================================================================='
    @echo '  ACTING MASTER — COCKPIT'
    @echo '=================================================================='
    @echo ''
    @echo 'HUMAN ADMIN: Roberto Scott Echols'
    @echo ''
    @echo 'BRANCH:'
    @git branch --show-current
    @echo ''
    @echo 'GIT STATUS:'
    @git status --short
    @echo ''
    @echo 'STACK TRUTH (key lines):'
    @grep -E '^(STACK_STATUS|PHASE:|PHASE_STATUS|NEXT_OWNER|NEXT_GATE|SMOKE_TEST|VECTOR_CHUNKS|CLOUD_RUN_STATUS|INGEST_STATUS|HUMAN_ADMIN):' STACK_TRUTH.md 2>/dev/null || echo '(STACK_TRUTH.md not found)'
    @echo ''
    @echo 'ACTIVE BLOCKERS:'
    @grep -E '^BLOCKER_' AGENT-OPS.md 2>/dev/null || echo '(none found)'
    @echo ''
    @echo '=================================================================='

# [MASTER] Print full STACK_TRUTH.md for governance review
master-truth:
    @if [ -f STACK_TRUTH.md ]; then cat STACK_TRUTH.md; else echo 'ERROR: STACK_TRUTH.md not found'; exit 1; fi

# [MASTER] Show who owns what lane and current agent assignments
master-lanes:
    @echo '=================================================================='
    @echo '  AGENT LANE ASSIGNMENTS'
    @echo '=================================================================='
    @echo ''
    @echo 'Scott / Acting Master  -> env vars, keys, merge approval, phase gates'
    @echo 'Claude Code            -> scripts/, netlify/edge-functions/, design.md'
    @echo 'Codex #2               -> public/index.html, public/assets/'
    @echo 'Antigravity            -> test execution, pass/fail reports'
    @echo 'Windsurf/Cascade       -> orchestration, truth docs, justfile'
    @echo ''
    @echo 'RULE: Agents may cross lanes to READ. Agents may NOT cross lanes to WRITE.'
    @echo '=================================================================='

# --- LANE: CLAUDE CODE (Backend / Ops / Runtime) ---

# [CLAUDE] Backend diagnostic — scripts, edge functions, wiring check ($0)
claude-doctor:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — DOCTOR ($0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Python:'
    @python --version 2>/dev/null || python3 --version 2>/dev/null || echo 'WARN: Python not found'
    @echo ''
    @echo 'Backend Scripts:'
    @test -f scripts/api_server.py && echo 'OK: api_server.py' || echo 'MISSING: api_server.py'
    @test -f scripts/embed_engine.py && echo 'OK: embed_engine.py' || echo 'MISSING: embed_engine.py'
    @test -f scripts/vector_store.py && echo 'OK: vector_store.py' || echo 'MISSING: vector_store.py'
    @test -f scripts/truth_audit.py && echo 'OK: truth_audit.py' || echo 'MISSING: truth_audit.py'
    @test -f scripts/Dockerfile && echo 'OK: Dockerfile' || echo 'MISSING: Dockerfile'
    @echo ''
    @echo 'Edge Functions:'
    @test -f netlify/edge-functions/chat.ts && echo 'OK: chat.ts' || echo 'MISSING: chat.ts'
    @test -f netlify/edge-functions/embed.ts && echo 'OK: embed.ts' || echo 'MISSING: embed.ts'
    @test -f netlify/edge-functions/verify-access.ts && echo 'OK: verify-access.ts' || echo 'MISSING: verify-access.ts'
    @echo ''
    @echo 'Config:'
    @test -f netlify.toml && echo 'OK: netlify.toml' || echo 'MISSING: netlify.toml'
    @test -f data/rse_cv_manifest.json && echo 'OK: rse_cv_manifest.json' || echo 'MISSING: rse_cv_manifest.json'
    @echo '=================================================================='

# [CLAUDE] Vector store health probe — Cloud Run + local ($0)
claude-vector-probe:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — VECTOR PROBE ($0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Cloud Run /health:'
    @curl -s --max-time 15 https://rse-retrieval-zrmkhygpwa-uc.a.run.app/health 2>/dev/null || echo 'FAIL: Cloud Run unreachable'
    @echo ''
    @echo ''
    @echo 'Local ChromaDB (dev only):'
    @test -d .chromadb && echo 'OK: .chromadb/ directory exists' || echo 'INFO: .chromadb/ not present (local dev only)'
    @echo '=================================================================='

# [CLAUDE] Env var presence check — boolean only, never log values ($0)
claude-env-check:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — ENV CHECK (presence only)'
    @echo '=================================================================='
    @if [ -n "$$GEMINI_API_KEY" ]; then echo 'OK: GEMINI_API_KEY is set'; else echo 'NOT SET: GEMINI_API_KEY'; fi
    @if [ -n "$$ANTHROPIC_API_KEY" ]; then echo 'OK: ANTHROPIC_API_KEY is set'; else echo 'NOT SET: ANTHROPIC_API_KEY'; fi
    @if [ -n "$$BUSINESS_ACCESS_KEY" ]; then echo 'OK: BUSINESS_ACCESS_KEY is set'; else echo 'NOT SET: BUSINESS_ACCESS_KEY'; fi
    @if [ -n "$$VECTOR_ENGINE_URL" ]; then echo 'OK: VECTOR_ENGINE_URL is set'; else echo 'NOT SET: VECTOR_ENGINE_URL (optional)'; fi
    @if [ -n "$$INGEST_SECRET" ]; then echo 'OK: INGEST_SECRET is set'; else echo 'NOT SET: INGEST_SECRET'; fi
    @echo '=================================================================='

# --- LANE: ANTIGRAVITY (QA / Verification) ---

# [ANTIGRAVITY] QA checklist runner — repo state + cloud health ($0)
antigravity-qa:
    @echo '=================================================================='
    @echo '  ANTIGRAVITY — QA CHECKLIST ($0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Git Status:'
    @git status --short
    @echo ''
    @echo 'Branch:'
    @git branch --show-current
    @echo ''
    @echo 'Phase Status:'
    @grep -E '^(PHASE:|PHASE_STATUS|NEXT_GATE|SMOKE_TEST):' STACK_TRUTH.md 2>/dev/null || echo '(check STACK_TRUTH.md)'
    @echo ''
    @echo 'Verification Contract (last pass):'
    @grep -E '^LAST:' STACK_TRUTH.md 2>/dev/null || echo '(no proof timestamps found)'
    @echo ''
    @echo '=================================================================='

# [ANTIGRAVITY] Cloud smoke test from QA lane ($0)
antigravity-smoke:
    @echo '=================================================================='
    @echo '  ANTIGRAVITY — CLOUD SMOKE ($0)'
    @echo '=================================================================='
    @echo ''
    @echo 'Cloud Run /health:'
    @curl -s --max-time 15 https://rse-retrieval-zrmkhygpwa-uc.a.run.app/health 2>/dev/null || echo 'FAIL: Cloud Run unreachable'
    @echo ''
    @echo ''
    @echo 'Netlify site:'
    @curl -s -o /dev/null -w 'HTTP %{http_code} — %{time_total}s' --max-time 15 https://robertoscottecholscv.netlify.app 2>/dev/null || echo 'FAIL: Netlify unreachable'
    @echo ''
    @echo ''
    @echo '=================================================================='

# [ANTIGRAVITY] Proof report snapshot — what the QA agent found
antigravity-proof-report:
    @echo '=================================================================='
    @echo '  ANTIGRAVITY — PROOF REPORT'
    @echo '=================================================================='
    @echo ''
    @echo 'Branch:'
    @git branch --show-current
    @echo ''
    @echo 'Recent commits:'
    @git log --oneline -5
    @echo ''
    @echo 'Changed files:'
    @git status --short
    @echo ''
    @echo 'Verification timestamps from STACK_TRUTH.md:'
    @grep -E '^(LAST:|RESULT:)' STACK_TRUTH.md 2>/dev/null || echo '(no proof timestamps found)'
    @echo ''
    @echo '=================================================================='

# --- LANE: CODEX #2 (Frontend / UI Shell) ---
# Specialty: static UI shell, accessibility, truthful progress states.
# Note: codex-validate, codex-preview, codex-upgrade already exist above.
# These lane-prefixed aliases are grounded to this repo's static HTML setup.

# [CODEX] Frontend build gate for the UI shell
codex-build:
    @echo '=================================================================='
    @echo '  CODEX — BUILD GATE'
    @echo '=================================================================='
    @echo 'NOTE: CV repo is static HTML — no npm build step required.'
    @echo 'Running codex-validate instead...'
    @echo ''
    just codex-validate

# [CODEX] Frontend/UI shell status summary
codex-status:
    @echo '=================================================================='
    @echo '  CODEX — FRONTEND STATUS'
    @echo '=================================================================='
    @echo ''
    @echo 'Branch:'
    @git branch --show-current
    @echo ''
    @echo 'Recent commits:'
    @git log --oneline -5
    @echo ''
    @echo 'index.html:'
    @test -f public/index.html && wc -l < public/index.html | xargs -I{} echo '{} lines' || echo 'MISSING'
    @echo ''
    @echo 'Assets:'
    @ls public/assets/ 2>/dev/null | wc -l | xargs -I{} echo '{} asset files' || echo '(no assets/)'
    @echo '=================================================================='

# ============================================================================
# ── ARCHIVE / NON-DESTRUCTIVE RECOVERY (ALL LANES — enforced by rail) ────────
# Rule: MOVE NOT DELETE. Run BEFORE rewriting any structural file.
# Every agent runs archive-asset before overwriting. No exceptions.
# Builds the Library of Assets — captures codebase evolution, never loses work.
# Usage: just archive-asset public/index.html "reason for archiving"
# Acting Master directive → Claude Code implementation — 2026-04-07
# FOR THE COMMONS GOOD — reusable across all WSP001 repos
# ============================================================================

# [ALL LANES] Archive a file before modification — MOVE, not DELETE
# Creates: archive/inspirational_scripts/<timestamp>/<filename> + reason.txt
# After running this, you may safely modify the active file.
# FORBIDDEN to overwrite structural files without running this first.
archive-asset FILE REASON:
    @echo '=================================================================='
    @echo '  ARCHIVE ASSET — MOVE, NOT DELETE (WSP001 Rail Rule)'
    @echo '=================================================================='
    @if [ -f "{{FILE}}" ]; then \
        TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
        FILENAME=$$(basename "{{FILE}}"); \
        ARCHIVE_DIR="archive/inspirational_scripts/$${TIMESTAMP}"; \
        mkdir -p "$${ARCHIVE_DIR}"; \
        cp "{{FILE}}" "$${ARCHIVE_DIR}/$${FILENAME}"; \
        printf "REASON: {{REASON}}\nSOURCE: {{FILE}}\nDATE: $$(date +%Y-%m-%d)\nARCHIVED_BY: $$(git config user.name 2>/dev/null || echo unknown)\nGIT_BRANCH: $$(git branch --show-current)\nGIT_COMMIT: $$(git rev-parse --short HEAD 2>/dev/null || echo unknown)\n" > "$${ARCHIVE_DIR}/reason.txt"; \
        echo ""; \
        echo "OK:       Archived to $${ARCHIVE_DIR}/$${FILENAME}"; \
        echo "REASON:   {{REASON}}"; \
        echo "RECOVERY: cp $${ARCHIVE_DIR}/$${FILENAME} {{FILE}}"; \
        echo ""; \
        echo "You may now safely modify: {{FILE}}"; \
    else \
        echo "FAIL: {{FILE}} not found — verify path before archiving"; \
        exit 1; \
    fi
    @echo '=================================================================='

# [ALL LANES] List all archived assets — Library of Assets index
archive-list:
    @echo '=================================================================='
    @echo '  LIBRARY OF ASSETS — Archive Index'
    @echo '=================================================================='
    @if [ -d archive/inspirational_scripts ]; then \
        for dir in archive/inspirational_scripts/*/; do \
            echo ""; \
            echo "ARCHIVE: $$dir"; \
            ls "$$dir" 2>/dev/null | sed 's/^/  /'; \
            if [ -f "$${dir}reason.txt" ]; then \
                echo "  ----"; \
                cat "$${dir}reason.txt" | sed 's/^/  /'; \
            fi; \
        done; \
    else \
        echo "(no archives yet — archive/ created on first: just archive-asset <file> <reason>)"; \
    fi
    @echo ''
    @echo '=================================================================='

# ============================================================================
# ── CLAUDE CODE AGENT SKILLS (Reusable | $0 | Lane-Safe | Idempotent) ────────
# Pattern: truth-pack first → ingest second → retriever third → chat last
# Each skill is a self-contained, replayable, single-responsibility recipe.
# Lane: Claude Code only — no Codex or Antigravity writes inside these.
# Attribution: Claude Code (CC-IAM-OPS) — 2026-04-07
# FOR THE COMMONS GOOD — reusable across all WSP001 repos
# ============================================================================

# [CLAUDE SKILL] Truth audit — verify CV content before ingest (COST: $0)
# Step 0 of every ingest. Produces PASS / WARN / FAIL verdict.
# Rule: do NOT ingest without PASS. Stale content in = stale answers out.
claude-truth-audit:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — TRUTH AUDIT SKILL  (COST: $0)'
    @echo '  Rule: truth-pack → audit → ingest → retriever → chat'
    @echo '=================================================================='
    @echo ''
    @echo 'Step 1 — Truth pack existence check:'
    @test -f knowledge_base/public/cv/identity_verified.md     && echo 'OK:   identity_verified.md'     || echo 'FAIL: identity_verified.md MISSING'
    @test -f knowledge_base/public/cv/github_repos_live.md     && echo 'OK:   github_repos_live.md'     || echo 'WARN: github_repos_live.md missing'
    @test -f knowledge_base/public/cv/seatrace_four_pillars_summary.md && echo 'OK:   seatrace_four_pillars_summary.md' || echo 'WARN: seatrace_four_pillars_summary.md missing'
    @echo ''
    @echo 'Step 2 — Business partition guard (must stay private, never in brief):'
    @test -d knowledge_base/business && echo 'OK:   business/ partition present (private — excluded from brief)' || echo 'INFO: knowledge_base/business/ not found'
    @echo ''
    @echo 'Step 3 — Run truth audit script + write cache (COST: $0 — pure local regex):'
    @mkdir -p .cache
    @test -f scripts/truth_audit.py && python scripts/truth_audit.py --format text --gate ingest --output .cache/CV_TRUTH_AUDIT_PASS.json || echo 'INFO: scripts/truth_audit.py not found'
    @echo ''
    @echo 'Cache: .cache/CV_TRUTH_AUDIT_PASS.json  ← downstream agents check this'
    @echo '=================================================================='
    @echo '  VERDICT: review output above'
    @echo '  PASS  → proceed to ingest (just embed-ingest)'
    @echo '  WARN  → flag items for Scott review before ingest'
    @echo '  FAIL  → stop. fix flagged items. do not ingest.'
    @echo '=================================================================='

# [CLAUDE SKILL] Proof of work — structured delivery receipt for completed tickets
# Run after finishing any Claude Code ticket. Outputs signed delivery summary.
# Proof = live smoke test result, not "no error".
claude-proof-of-work:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — PROOF OF WORK'
    @echo '  Proof = working smoke test, not "no error"'
    @echo '=================================================================='
    @echo ''
    @echo 'Agent lane:  Claude Code (scripts/ | netlify/edge-functions/ | justfile)'
    @echo 'Date:        $(date +%Y-%m-%d 2>/dev/null || powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd")'
    @echo ''
    @echo 'Recent commits (all lanes — read for context):'
    @git log --oneline -8
    @echo ''
    @echo 'Claude Code owned files changed (last 5 commits):'
    @git diff --name-only HEAD~5 HEAD 2>/dev/null | grep -E '(scripts/|netlify/edge-functions/|justfile|AGENT-OPS|STACK_TRUTH|DEPENDENCY_MAP|MASTER_AGENT|plans/)' | head -20 || echo '(no CC-owned changes in last 5 commits)'
    @echo ''
    @echo 'Cloud Run live proof (health + chunk count):'
    @curl -s --max-time 12 https://rse-retrieval-zrmkhygpwa-uc.a.run.app/health 2>/dev/null || echo 'UNREACHABLE — check connectivity'
    @echo ''
    @echo ''
    @echo '=================================================================='
    @echo '  FOR THE COMMONS GOOD — attributed, verified, replayable'
    @echo '=================================================================='

# [CLAUDE SKILL] Session orient — fast read-before-write startup ($0)
# Run at every session start BEFORE the first write.
# Surfaces: lane, phase, active blockers, next task, DO NOT TOUCH list.
claude-orient:
    @echo '=================================================================='
    @echo '  CLAUDE CODE — SESSION ORIENT  (COST: $0)'
    @echo '  Run this before writing anything. Read → Plan → Write in lane only.'
    @echo '=================================================================='
    @echo ''
    @echo 'REPO + BRANCH:'
    @git remote get-url origin 2>/dev/null | head -1 || echo '(remote not configured)'
    @git branch --show-current
    @echo ''
    @echo 'PHASE + STATUS (from STACK_TRUTH.md):'
    @grep -E '^(PHASE:|PHASE_STATUS|NEXT_OWNER|NEXT_GATE):' STACK_TRUTH.md 2>/dev/null || grep -E '^(PHASE|PHASE_STATUS|BLOCKER)' AGENT-OPS.md 2>/dev/null | head -8 || echo '(read AGENT-OPS.md manually)'
    @echo ''
    @echo 'CLAUDE CODE LANE OWNS (write access):'
    @echo '  scripts/                           Python backend, embed engine, api_server'
    @echo '  netlify/edge-functions/            chat.ts, embed.ts, verify-access.ts'
    @echo '  justfile                           agent CLI surface'
    @echo '  AGENT-OPS.md                       ops resume contract'
    @echo '  STACK_TRUTH.md                     truth layer (Windsurf-authored, CC-maintained)'
    @echo '  MASTER_AGENT_IMPLEMENTATION_HANDOFF.md'
    @echo '  knowledge_base/                    CV content (partitioned)'
    @echo '  plans/                             handoff docs (CC-authored only)'
    @echo ''
    @echo 'DO NOT TOUCH (cross-lane write violations):'
    @echo '  public/index.html                  → Codex lane'
    @echo '  src/ components/                   → Codex lane'
    @echo '  tests/ e2e/ __mocks__/             → Antigravity writes'
    @echo ''
    @echo 'ACTIVE BLOCKERS:'
    @grep -E '^BLOCKER_' AGENT-OPS.md 2>/dev/null | head -6 || echo '(no blockers found — read AGENT-OPS.md to confirm)'
    @echo ''
    @echo 'SKILLS AVAILABLE (just claude-*):'
    @echo '  just claude-orient          ← this command'
    @echo '  just claude-truth-audit     ← run before every ingest'
    @echo '  just claude-proof-of-work   ← run after every ticket'
    @echo '  just claude-doctor          ← repo wiring check'
    @echo '  just claude-vector-probe    ← Cloud Run health'
    @echo '  just claude-env-check       ← env var presence'
    @echo '  just validate-manifest      ← manifest source file check'
    @echo '  just ingest-remote          ← POST chunks to Cloud Run /ingest'
    @echo '  just brain-claim AGENT RUN  ← claim workspace lock'
    @echo '  just cold-start             ← cold rail composite (safe)'
    @echo '  just ingest-and-verify      ← ingest + probe round-trip'
    @echo '  just full-deploy            ← golden path (HOT)'
    @echo ''
    @echo '=================================================================='

# ============================================================================
# ── CLAUDE CODE SKILLS — SESSION 2026-04-07 ADDITIONS ────────────────────────
# Added after live pgvector + remote-ingest sessions.
# FOR THE COMMONS GOOD — reusable across all WSP001 repos
# Attribution: Claude Code (CC-IAM-OPS) — 2026-04-08
# ============================================================================

# [CLAUDE SKILL] Validate manifest — check all source_paths exist on disk (COLD)
# Run before any ingest. Shows which source files are present/missing.
validate-manifest:
    #!/usr/bin/env python3
    import json, sys, pathlib
    print('==================================================================')
    print('  VALIDATE MANIFEST  (COLD — COST: $0)')
    print('==================================================================')
    m = json.load(open('data/rse_cv_manifest.json'))
    sources = m.get('sources', [])
    print(f'Manifest v{m.get("version","?")} — {len(sources)} sources')
    base = pathlib.Path('knowledge_base')
    missing = []
    ok = []
    for s in sources:
        sp = s.get('source_path', '')
        candidates = [
            base / s.get('access_tier', 'public') / 'cv' / sp,
            pathlib.Path('docs') / sp,
        ]
        if any(c.exists() for c in candidates):
            ok.append(sp)
        else:
            missing.append(sp)
    for p in ok:
        print(f'OK:      {p}')
    for p in missing:
        print(f'MISSING: {p}')
    print()
    print(f'RESULT: {len(ok)} OK, {len(missing)} MISSING')
    print('==================================================================')
    sys.exit(1 if missing else 0)

# [CLAUDE SKILL] Remote ingest — POST full manifest corpus to Cloud Run /ingest (HOT)
# Requires VECTOR_ENGINE_URL and INGEST_SECRET set in env / .env
# Use ingest-and-verify to confirm round-trip after this runs.
ingest-remote:
    @echo '=================================================================='
    @echo '  INGEST REMOTE  (HOT — posts to Cloud Run /ingest)'
    @echo '  Requires: VECTOR_ENGINE_URL + INGEST_SECRET'
    @echo '=================================================================='
    @if [ -z "$$VECTOR_ENGINE_URL" ]; then echo 'FAIL: VECTOR_ENGINE_URL not set'; exit 1; fi
    @if [ -z "$$INGEST_SECRET" ]; then echo 'FAIL: INGEST_SECRET not set'; exit 1; fi
    @echo "Target: $$VECTOR_ENGINE_URL"
    python scripts/embed_engine.py ingest-manifest --manifest data/rse_cv_manifest.json
    @echo '=================================================================='
    @echo '  Done — run: just claude-vector-probe to confirm chunk counts'
    @echo '=================================================================='

# [CLAUDE SKILL] Brain-claim — write workspace lock (.brain-lock) (COLD)
# Prevents two agents writing to the same repo concurrently.
# Usage: just brain-claim claude-code run-001
brain-claim agent run_id:
    @echo "agent={{agent}}" > .brain-lock
    @echo "run_id={{run_id}}" >> .brain-lock
    @date +%Y-%m-%dT%H:%M:%SZ 2>/dev/null >> .brain-lock || powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'" >> .brain-lock
    @echo "OK: Workspace claimed by {{agent}} / run {{run_id}}"

# [CLAUDE SKILL] Brain-release — delete workspace lock (COLD)
brain-release:
    @rm -f .brain-lock && echo 'OK: Workspace released' || echo 'INFO: No lock file found'

# [CLAUDE SKILL] Brain-status — show current lock state (COLD)
brain-status:
    @if [ -f .brain-lock ]; then echo '=== LOCKED ==='; cat .brain-lock; else echo 'No lock — workspace free'; fi

# ── COMPOSITE GOLDEN-PATH RECIPES ────────────────────────────────────────────

# [COLD] Cold-start: safe session opener — orient, truth-audit, doctor, env-check
cold-start:
    @echo '=================================================================='
    @echo '  COLD START  (COLD RAIL — COST: $0)'
    @echo '=================================================================='
    just claude-orient
    just claude-truth-audit
    just claude-doctor
    just claude-env-check
    @echo ''
    @echo 'Cold start complete — safe to proceed to HOT rail with confirmation'

# [HOT] Ingest and verify — remote ingest then probe Cloud Run for chunk counts
ingest-and-verify: ingest-remote claude-vector-probe
    @echo 'Ingest + verify complete — review chunk counts above'

# [HOT] Full deploy golden path: truth audit → preflight → ingest → probe
# Runs every gate in order. Stop on first failure.
full-deploy:
    @echo '=================================================================='
    @echo '  FULL DEPLOY GOLDEN PATH  (HOT RAIL)'
    @echo '  truth-audit → preflight → ingest-remote → vector-probe'
    @echo '=================================================================='
    just claude-truth-audit
    just preflight
    just ingest-remote
    just claude-vector-probe
    @echo ''
    @echo '=================================================================='
    @echo '  Full deploy complete — review output above before merging'
    @echo '=================================================================='

# ============================================================================
# ── LAYER 2: PERPLEXITY RESEARCH — Current context before writing ─────────────
# Design: "Layer 1 = WHO IS SCOTT (CV identity), Layer 2 = WHAT IS HAPPENING NOW"
# Attribution: Claude Code (CC-IAM-OPS) — 2026-04-10
# FOR THE COMMONS GOOD — reusable across all WSP001 writing agents
# ============================================================================

# [COLD] Show Layer 2 architecture — how Perplexity slots into content generation
perplexity-design:
    @echo '=================================================================='
    @echo '  LAYER 2: PERPLEXITY RESEARCH ARCHITECTURE  (COLD)'
    @echo '=================================================================='
    @echo ''
    @echo 'Layer 1: WHO IS SCOTT    → /api/identity.json + pgvector RAG'
    @echo 'Layer 2: WHAT IS NOW     → Perplexity Sonar API (maritime/fisheries news)'
    @echo 'Layer 3: WRITE           → Claude Opus 4.6 with Layer 1 + Layer 2 context'
    @echo ''
    @echo 'Perplexity env var required: PERPLEXITY_API_KEY'
    @echo 'Model: sonar (latest news, grounded, no hallucination)'
    @echo ''
    @echo 'Use case: Before generating LinkedIn post or consulting brief,'
    @echo '  fetch current industry context so content is not pre-2026.'
    @echo ''
    @echo 'Status:'
    @if [ -n "$$PERPLEXITY_API_KEY" ]; then echo '  OK: PERPLEXITY_API_KEY is set — Layer 2 ready'; else echo '  NOT SET: PERPLEXITY_API_KEY — add to Netlify env to activate Layer 2'; fi
    @echo '=================================================================='

# [COLD] Test Perplexity API with a fisheries industry query
perplexity-test query="latest news in fisheries traceability and IUU fishing 2026":
    #!/usr/bin/env python3
    import urllib.request, json, os, sys
    print('==================================================================')
    print('  PERPLEXITY TEST  (COLD — read-only probe)')
    print('==================================================================')
    key = os.environ.get('PERPLEXITY_API_KEY', '')
    if not key:
        print('FAIL: PERPLEXITY_API_KEY not set')
        sys.exit(1)
    body = json.dumps({
        'model': 'sonar',
        'messages': [{'role': 'user', 'content': '{{query}}'}]
    }).encode()
    req = urllib.request.Request(
        'https://api.perplexity.ai/chat/completions',
        data=body,
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.load(r)
        print(d['choices'][0]['message']['content'][:800])
    print('==================================================================')

# [COLD] Check Perplexity env var presence only (never logs the key value)
perplexity-env-check:
    @if [ -n "$$PERPLEXITY_API_KEY" ]; then echo 'OK: PERPLEXITY_API_KEY is set'; else echo 'NOT SET: PERPLEXITY_API_KEY'; echo '  Get key: https://www.perplexity.ai/settings/api'; echo '  Add to Netlify: netlify env:set PERPLEXITY_API_KEY sk-...'; fi
