# WSP001 — FINAL ASSIGNMENTS (2026-03-29)
# Signed: Scott Echols / WSP001 — Commons Good
# One job per agent. No overlap. No fake success.

---

## CLAUDE CODE — SLOT 1 — CARD CONFLICT ARBITRATION

Repo: C:\WSP001\R.-Scott-Echols-CV
Read first: public/index.html (current committed version)
Then read: plans/ANTIGRAVITY_CARD_AUDIT_REPORT.md

SITUATION:
Two agents pushed conflicting index.html versions.
Antigravity says SirTrav is in slot 1 (wrong).
Codex says SeaTrace has no flagship glow (wrong).
You are the arbitrator. Runtime wins.

YOUR ONE TASK:
Read the committed index.html RIGHT NOW and report:

1. What slot is SeaTrace in? (should be 1)
2. What slot is SirTrav in? (should be 4)
3. Does SeaTrace card have flagship-seatrace CSS class? (should yes)
4. Does Sir James card say "Creative" not "Marine Tech"? (should yes)
5. Does bio lead with World Seafood Producers / SeaTrace? (should yes, not SirTrav)
6. Does years counter say 40+? (check identity.json — career: HS grad 1979, business degree 1984, digital comm engineering 1984, systems analyst, Pearl Harbor installation 1987)

If any are wrong in committed file:
  Fix only those specific lines.
  Do not rewrite the whole file.
  Commit: "fix(cards): arbitrate slot order + flagship glow per identity.json"

If all correct in committed file:
  Report CONFIRMED — live site lag only, no code change needed.

Also check if this link is relevant to embed: https://patents.justia.com/inventor/robert-scott-echols
If patent records exist, note them for KB expansion.

FORBIDDEN:
  Do not touch edge functions
  Do not touch api_server.py
  Do not rewrite architecture

Attribution:
  Architecture: Scott Echols / WSP001 — Commons Good
  Prompt bridge: Claude (mobile dispatch)
  Engineering: Claude Sonnet 4.6

---

## CODEX — SLOT 2 — TWO FIXES ONLY

Repo: C:\WSP001\R.-Scott-Echols-CV
Lane: public/index.html CSS/JS only

Wait for Claude Code's arbitration report first.

TASK A — SeaTrace flagship glow (if Claude Code confirms missing)
  SeaTrace card must have CSS class: flagship-seatrace
  Distinct glow/border that SirTrav does not have.
  SirTrav gets standard card styling only.
  Do not change card slot order — Claude Code owns that.

TASK B — Sir James URL fix
  Current Sir James links to check:
    - https://sirjames-book002-final.netlify.app/
    - https://sirjames-book002-final.netlify.app/chapter01/scene-001/index.html
    - https://sirjamesadventures-book002.netlify.app (known 404)
    - https://sirjames-book003.netlify.app/
  Replace broken URL with working one or remove href.

TASK C — Fontshare CSP error (low priority)
  Add fonts.fontshare.com to CSP connect-src if easy.
  If complex — leave it.

Commit: "fix(cards): flagship glow + Sir James URL fix [Codex]"

Attribution:
  Architecture: Scott Echols / WSP001 — Commons Good
  Engineering: Codex

---

## ANTIGRAVITY — SLOT 3 — VERIFY ONLY AFTER COMMITS LAND

Lane: Read-only QA. No code changes ever.

WAIT until Claude Code and Codex have both committed.
Run cv-smoke.ps1 first — must show 9/9 PASS before browser.

Then verify live site — report EXACT text seen:

1. SeaTrace card: what slot number? (count from left/top)
2. SeaTrace card: visible glow border different from SirTrav?
3. SirTrav card: what slot number? (should be ONE card only)
4. Sir James card: tag says "Creative" or "Marine Tech"?
5. Sir James URL: click it — WORKING or BROKEN?
6. Years counter: exact number shown
7. Quick action buttons: all three FIRE?

Report format — one line per item:
  PASS/FAIL | exact text or behavior seen | timestamp

Write to: plans/ANTIGRAVITY_FINAL_VERIFY_2026-03-29.md

After Cloud Run deploy:
  Ask chatbot: "What are the Four Pillars of SeaTrace?"
  Report exact answer_source field value.
  Should read: RAG — CV Corpus (not just "Verified Profile Pack")

Attribution:
  Architecture: Scott Echols / WSP001 — Commons Good
  Verification: Antigravity

---

## SCOTT — SLOT 4 — OPERATOR (three actions before Tuesday)

ACTION 1 — Fix Sir James 404 (5 minutes)
  Go to app.netlify.com
  Find: sir-james-adventuers001 and sirjamesadventures-book002
  Check if deployed. If 404 — check publish directory setting.
  Also check: sirjames-book002-final, sirjames-book003

ACTION 2 — Fix SeaTrace SSL (10 minutes)
  seatrace.worldseafoodproducers.com has SSL cert failure.
  Netlify dashboard -> seatrace site -> Domain management
  Click "Renew certificate" or "Provision certificate"
  Hosting: Netfirms (domain) + Netlify (site) — different servers.

ACTION 3 — Cloud Run deploy
  cd C:\WSP001\R.-Scott-Echols-CV
  .\scripts\deploy-cloud-run.ps1
  When URL prints: set VECTOR_ENGINE_URL in Netlify for BOTH sites
  Then run: .\scripts\cv-smoke.ps1
  Step 5 vector must PASS.

Also find a spot on the CV site for these links:
  - https://dchs-football.org (DCHS Football — community work)
  - https://wsp2agent.netlify.app (WSP Control Tower Hub)

---

## WIN CONDITION

cv-smoke.ps1 -> 10/10 PASS including vector step
Antigravity final verify -> SeaTrace slot 1, flagship glow confirmed
Chatbot returns answer_source: "RAG — CV Corpus"

Foundation solid. Voice grounded. Cards correct.
That is the Commons Good demo.
For the Commons Good. 🎬