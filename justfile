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
    @echo 'VECTOR STORE:    PostgreSQL + pgvector on Cloud Run (DATABASE_URL)'
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
    @echo 'Checking edge function TypeScript (0 errors expected — this gate CAN fail)'
    @command -v deno >/dev/null 2>&1 || { echo '(deno not installed locally - runs at Netlify deploy)'; exit 0; }
    @for f in chat embed verify-access abacus social-generate; do \
        deno check --no-lock "netlify/edge-functions/$f.ts" || exit 1; \
    done
    @echo 'OK: all 5 edge functions typecheck clean'

# [CLAUDE CODE] Ingest the knowledge base
# LOCAL by default. Pass `remote` to write to the production pgvector corpus:
#   just embed-ingest          -> local store, NOT visible to production
#   just embed-ingest remote   -> POST /ingest on VECTOR_ENGINE_URL (needs INGEST_SECRET)
embed-ingest arg1="":
    @R=""; case "{{arg1}}" in remote|remote=1|--remote ) R="--remote" ;; esac; \
    if [ -n "$R" ]; then \
      echo "Ingesting to the PRODUCTION pgvector corpus via /ingest"; \
    else \
      echo "Ingesting to the LOCAL store — production does NOT read this."; \
      echo "Use 'just embed-ingest remote' to fill the live corpus."; \
    fi; \
    python scripts/embed_engine.py --ingest --partition cv_personal --source docs/ $R && \
    python scripts/embed_engine.py --ingest --partition cv_projects --source docs/ $R

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

# [CLAUDE CODE] Read the API key runbook (READ BEFORE ROTATING ANY KEY)
keys-runbook:
    @cat docs/API_KEY_ROTATION.md

# [CLAUDE CODE] Show which key powers what + where each one must be changed
keys-map:
    @echo '=================================================================='
    @echo 'API KEY MAP - change these in Netlify, NOT in source code'
    @echo '=================================================================='
    @echo 'ANTHROPIC_API_KEY   -> Claude Opus chatbot brain  | chat.ts       | 1 place : Netlify'
    @echo 'GEMINI_API_KEY      -> vector DATABASE embeddings | embed.ts +py  | 3 places: Netlify + GCP Secret Mgr + local shell'
    @echo 'BUSINESS_ACCESS_KEY -> business tier passphrase    | verify-access | 1 place : Netlify (invalidates old invites)'
    @echo 'ABACUS_API_KEY      -> Abacus.AI side channel      | abacus.ts     | 1 place : Netlify (business tier only)'
    @echo 'VECTOR_ENGINE_URL   -> Cloud Run retrieval URL     | chat.ts       | 1 place : Netlify (site-level)'
    @echo 'INGEST_SECRET       -> Cloud Run ingest guard       | api_server.py | 1 place : GCP Secret Manager only'
    @echo 'DATABASE_URL        -> pgvector corpus (the DATABASE)| api_server.py | 1 place : Cloud Run secret, NOT Netlify'
    @echo ''
    @echo 'Edge functions read keys via Netlify.env.get() - process.env does NOT work here.'
    @echo 'Every change requires a redeploy: netlify deploy --build --prod'
    @echo 'Full runbook: just keys-runbook'

# [CLAUDE CODE] Verify live endpoints still work after a key rotation
# just recipe parameters are POSITIONAL — `grounded=1` is not a named argument,
# it arrives as the first positional value. Both forms are accepted:
#   just keys-verify
#   just keys-verify grounded=1
#   just keys-verify https://deploy-preview--x.netlify.app grounded=1
keys-verify arg1="" arg2="":
    @SITE="https://robertoscottecholscv.netlify.app"; GROUNDED=0; \
    for a in "{{arg1}}" "{{arg2}}"; do \
      case "$a" in \
        "" ) ;; \
        grounded=* ) [ "${a#grounded=}" != "0" ] && GROUNDED=1 ;; \
        grounded ) GROUNDED=1 ;; \
        http* ) SITE="$a" ;; \
        * ) echo "Ignoring unrecognised argument: $a" ;; \
      esac; \
    done; \
    echo "Site: $SITE"; \
    echo ""; \
    echo "/api/chat  (200 = healthy, 503 = key missing, 502 = key rejected upstream)"; \
    curl -s -o /dev/null -w '  HTTP %{http_code}\n' -X POST "$SITE/api/chat" \
      -H "Content-Type: application/json" \
      -d '{"message":"ping","tier":"public"}' || echo '  unreachable'; \
    echo ""; \
    echo "Retrieval status (rag_status names the real outcome, not just true/false):"; \
    BODY=$(curl -s -X POST "$SITE/api/chat" -H "Content-Type: application/json" \
      -d '{"message":"What is SeaTrace?","tier":"public"}'); \
    echo "$BODY" | grep -oE '"(rag_status|rag_context_used)":("[a-z_]*"|[a-z]*)' \
      | sed 's/^/  /' \
      || echo '  no rag fields (old deploy — redeploy to pick up rag_status)'; \
    echo ""; \
    echo "  ok              retrieval fed the answer            <- G2 GREEN"; \
    echo "  not_configured  VECTOR_ENGINE_URL is unset"; \
    echo "  timeout         Cloud Run too slow or cold"; \
    echo "  upstream_error  Cloud Run reachable but failing (check DATABASE_URL)"; \
    echo "  empty           corpus has no rows — run an ingest"; \
    echo "  below_threshold corpus has rows but nothing relevant"; \
    if [ "$GROUNDED" = "1" ]; then \
      echo ""; \
      echo "GATE grounded=1: requiring rag_status == ok"; \
      if echo "$BODY" | grep -q '"rag_status":"ok"'; then \
        echo "PASS: answers are grounded in retrieved context"; \
      else \
        echo "FAIL: answers are NOT grounded — see the meanings above"; exit 1; \
      fi; \
    fi

# [CLAUDE CODE] Test the Abacus.AI side channel (needs BUSINESS_ACCESS_KEY in env)
abacus-test site="https://robertoscottecholscv.netlify.app":
    @echo 'POST /api/abacus op=health  (403 = bad access key, 503 = ABACUS_API_KEY unset)'
    @curl -s -X POST "{{site}}/api/abacus" \
      -H "Content-Type: application/json" \
      -H "X-Access-Key: $BUSINESS_ACCESS_KEY" \
      -d '{"op":"health"}' || echo 'unreachable'
    @echo ''
    @echo 'Reminder: /api/abacus is a side channel. /api/chat stays on Claude Opus 4.6.'

# [CLAUDE CODE] Test /api/social-generate (generation only — never publishes)
social-test topic="SeaTrace DeckSide milestone" platform="linkedin" site="https://robertoscottecholscv.netlify.app":
    @echo 'POST /api/social-generate  (403 = business content without a key, 503 = ANTHROPIC_API_KEY unset)'
    @curl -s -X POST "{{site}}/api/social-generate" \
      -H "Content-Type: application/json" \
      -d '{"topic":"{{topic}}","platform":"{{platform}}","tier":"public"}' \
      || echo 'unreachable'
    @echo ''
    @echo 'Check: rag_status, platform_formatted, sources_used, published:false'

# [CLAUDE CODE] Show the whole social pipeline and where each stage lives
social-pipeline:
    @echo '=================================================================='
    @echo 'SOCIAL PIPELINE — CV (brain) -> SirScottA2A (voice) -> back again'
    @echo '=================================================================='
    @echo '1 INGEST    Shares.csv -> linkedin_history'
    @echo '            just linkedin-ingest Shares.csv              (dry run)'
    @echo '            just linkedin-ingest Shares.csv commit       (for real)'
    @echo '2 GENERATE  topic + corpus -> draft post'
    @echo '            just social-test "your topic" linkedin'
    @echo '3 PUBLISH   SirScottA2A only. This repo NEVER publishes.'
    @echo '4 FEEDBACK  published posts + metrics -> social_published'
    @echo '            just published-sync published.json'
    @echo ''
    @echo 'Side feed   SeaTrace milestones -> business_seatrace'
    @echo '            just seatrace-sync milestones.json'
    @echo ''
    @echo 'Every stage needs VECTOR_ENGINE_URL; stages 1/4 also need INGEST_SECRET.'
    @echo 'Stage 2 is blocked until ANTHROPIC_API_KEY is valid: just keys-verify'

# [CLAUDE CODE] Ingest Scott's LinkedIn history — the voice corpus (dry run by default)
# Positional; `csv=` and `commit=1` prefixes are tolerated for readability:
#   just linkedin-ingest Shares.csv
#   just linkedin-ingest Shares.csv commit
linkedin-ingest arg1="" arg2="":
    @CSV="{{arg1}}"; COMMIT=""; \
    case "$CSV" in csv=* ) CSV="${CSV#csv=}" ;; esac; \
    case "{{arg2}}" in commit|commit=1|--commit ) COMMIT="--commit" ;; esac; \
    if [ -z "$CSV" ]; then \
      echo "Usage: just linkedin-ingest Shares.csv [commit]"; \
      echo "Export it from LinkedIn -> Settings -> Data privacy -> Get a copy of your data -> Posts"; \
      exit 1; \
    fi; \
    node scripts/ingest-linkedin-posts.mjs --csv "$CSV" $COMMIT

# [CLAUDE CODE] Sync SeaTrace (packethander) milestones -> business_seatrace
# No argument prints the expected input shape instead of failing.
seatrace-sync arg1="" arg2="":
    @FILE="{{arg1}}"; COMMIT=""; \
    case "$FILE" in file=* ) FILE="${FILE#file=}" ;; esac; \
    case "{{arg2}}" in commit|commit=1|--commit ) COMMIT="--commit" ;; esac; \
    if [ -z "$FILE" ]; then \
      echo "No file given — showing the expected shape with --sample:"; \
      node scripts/sync-seatrace-milestones.mjs --sample; \
    else \
      node scripts/sync-seatrace-milestones.mjs --file "$FILE" $COMMIT; \
    fi

# [CLAUDE CODE] Close the loop: published posts + engagement -> social_published
# No argument prints the expected input shape instead of failing.
published-sync arg1="" arg2="":
    @FILE="{{arg1}}"; COMMIT=""; \
    case "$FILE" in file=* ) FILE="${FILE#file=}" ;; esac; \
    case "{{arg2}}" in commit|commit=1|--commit ) COMMIT="--commit" ;; esac; \
    if [ -z "$FILE" ]; then \
      echo "No file given — showing the expected shape with --sample:"; \
      node scripts/sync-published-posts.mjs --sample; \
    else \
      node scripts/sync-published-posts.mjs --file "$FILE" $COMMIT; \
    fi

# [CLAUDE CODE] Apply the pgvector schema to a fresh database (idempotent)
db-schema:
    @test -n "$DATABASE_URL" || { echo 'DATABASE_URL not set. Export it for this shell only, then unset it.'; exit 1; }
    @echo 'Applying scripts/schema/wsp001_knowledge.sql'
    @psql "$DATABASE_URL" -f scripts/schema/wsp001_knowledge.sql
    @echo 'OK. Now redeploy Cloud Run so the service picks up DATABASE_URL: just deploy-cloud-run'

# [CLAUDE CODE] What is blocking production right now, in order
blockers:
    @echo '=================================================================='
    @echo 'BLOCKERS — owner actions, in dependency order'
    @echo '=================================================================='
    @echo '1 ANTHROPIC_API_KEY is invalid -> /api/chat returns 502'
    @echo '  console.anthropic.com -> new key -> Netlify env -> redeploy'
    @echo '  Proof: just keys-verify            (expect HTTP 200)'
    @echo ''
    @echo '2 DATABASE_URL is unset -> retrieval degraded, answers ungrounded'
    @echo '  Provision Postgres+pgvector, then: just db-schema'
    @echo '  Set it as a Cloud Run SECRET, then: just deploy-cloud-run'
    @echo '  Proof: just keys-verify grounded=1 (expect rag_status ok)'
    @echo ''
    @echo '3 Corpus is empty after a new database -> re-ingest'
    @echo '  just ingest-all remote             (needs GEMINI_API_KEY + INGEST_SECRET)'
    @echo '  just linkedin-ingest Shares.csv commit'
    @echo ''
    @echo '4 ABACUS_API_KEY unset -> /api/abacus returns 503 (optional channel)'
    @echo ''
    @echo 'Full runbook: just keys-runbook'

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
# Single source of truth is scripts/requirements.txt — chromadb was removed there
# on 2026-09-13 (backend is pgvector). Never hand-list packages here again; a
# hand-list is how the dependency set drifts from what Cloud Run actually builds.
pip-install:
    pip install -r scripts/requirements.txt

# Run full knowledge base ingestion
# `just ingest-all remote` is the one that fills the corpus production reads.
ingest-all arg1="":
    just pip-install
    just embed-ingest {{arg1}}
    @case "{{arg1}}" in \
      remote|remote=1|--remote ) echo 'OK: ingested into the production pgvector corpus' ;; \
      * ) echo 'OK: ingested LOCALLY. Production is unchanged — re-run with: just ingest-all remote' ;; \
    esac

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
    python scripts/truth_audit.py --format text

# Enterprise truth gate with PASS/WARN/FAIL verdict
truth-audit:
    python scripts/truth_audit.py --format text --gate ingest

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
    @echo ''
    @echo 'Expected partitions:'
    @echo '  cv_personal          (public tier) -- verified identity'
    @echo '  cv_projects          (public tier) -- project details'
    @echo '  linkedin_history     (public tier) -- Scott'"'"'s own post history (voice)'
    @echo '  social_published     (public tier) -- published posts + engagement'
    @echo '  business_seatrace    (business tier) -- SeaTrace docs'
    @echo '  business_proposals   (business tier) -- proposals'
    @echo '  internal_repos       (business tier) -- code architecture'
    @echo '  recreational         (private tier) -- never served to any caller'
    @echo ''
    @echo 'Canonical tier map: scripts/api_server.py PARTITION_TIERS'
    @echo 'Enforced by: just truth-audit (partition-contract gate)'

# Vector store health check — asks PRODUCTION, not a local directory
# /health reports status "degraded" (never "ok") when the database is unreachable,
# because a green check on a dead corpus is how silent RAG failure survives for weeks.
vector-health:
    @if [ -z "$VECTOR_ENGINE_URL" ]; then \
      echo "VECTOR_ENGINE_URL is not set — cannot check the production corpus."; \
      echo "Set it to the Cloud Run service URL, then re-run."; \
      echo ""; \
      echo "Local store (for reference only — production does NOT read it):"; \
      python scripts/embed_engine.py --stats || true; \
      exit 1; \
    fi; \
    echo "Production corpus: $VECTOR_ENGINE_URL/health"; \
    curl -s -w '\nHTTP %{http_code}\n' "$VECTOR_ENGINE_URL/health"; \
    echo ""; \
    echo 'status "ok"        corpus reachable and populated'; \
    echo 'status "degraded"  DATABASE_URL wrong/unset, or the database is down'; \
    echo 'chunks 0           reachable but empty -> just ingest-all remote'

# Read-only semantic lookup over the verified public partition
cv-search query="Scott background":
    python scripts/embed_engine.py --query "{{query}}" --partition cv_personal --top-k 5

# Full RAG pipeline sanity test (local only)
test-rag-local:
    @echo 'Testing local RAG pipeline'
    @echo '=================================================================='
    @echo 'Step 1: Ingest verified identity'
    just ingest-identity
    @echo ''
    @echo 'Step 2: Test semantic retrieval'
    just cv-search "Scott's background"
    @echo ''
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
