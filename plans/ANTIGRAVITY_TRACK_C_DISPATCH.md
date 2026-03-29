# ANTIGRAVITY TRACK C — FINAL VERIFICATION (paste after VECTOR_ENGINE_URL is set)
# Repo: C:\WSP001\R.-Scott-Echols-CV
# Lane: Read-only QA. No code changes.
# Prerequisite: VECTOR_ENGINE_URL must be live in Netlify env vars for both sites.

# ── STEP 1: Pull latest and confirm clean ──
cd C:\WSP001\R.-Scott-Echols-CV
git pull origin main
git log --oneline -3

# ── STEP 2: Run full smoke test (must be 15/15 PASS, 0 SKIP) ──
pwsh -File scripts\cv-smoke.ps1

# ── STEP 3: Manual chatbot test ──
# Open in browser: https://robertoscottecholscv.netlify.app
# Click chatbot bubble
# Click quick question #1: "What are the Four Pillars of SeaTrace?"
# VERIFY:
#   - Response mentions SeaSide, DeckSide, DockSide, MarketSide
#   - Source pill shows "RAG — CV Corpus" (not "Fallback" or "Metadata Pending")
#   - Tier badge shows "Public Access"

# ── STEP 4: API-level verification ──
$r = Invoke-RestMethod -Uri "https://robertoscottecholscv.netlify.app/api/chat" -Method POST -ContentType "application/json" -Body '{"message":"What are the Four Pillars of SeaTrace?","tier":"public","questionCount":0}' -TimeoutSec 20
Write-Host "reply length: $($r.reply.Length)"
Write-Host "tier: $($r.tier)"
Write-Host "answer_source: $($r.answer_source)"
Write-Host "rag_context_used: $($r.rag_context_used)"

# ── STEP 5: Visual card audit (live site) ──
# Open: https://robertoscottecholscv.netlify.app
# CHECK each item — report PASS/FAIL with exact text seen:
#   1. SeaTrace card: slot 1? flagship glow visible?
#   2. SirTrav card: slot 4? standard styling (no glow)?
#   3. Sir James card: tag says "Creative"? Book002 link works?
#   4. WSP2Agent card: present? link works?
#   5. Years counter: shows 40+?
#   6. Bio leads with WSP/SeaTrace (not SirTrav)?
#   7. Quick actions: all 3 fire?

# ── STEP 6: Write report ──
# Create: plans/ANTIGRAVITY_FINAL_VERIFY_2026-03-29.md
# Format per item: PASS/FAIL | exact text or behavior | timestamp
# Final line: WIN CONDITION MET / NOT MET

# Attribution:
#   Architecture: Scott Echols / WSP001 — Commons Good
#   Verification: Antigravity