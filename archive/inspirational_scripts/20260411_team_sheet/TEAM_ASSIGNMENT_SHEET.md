# TEAM ASSIGNMENT SHEET
## robertoscottecholscv CV Chatbot — Production Deployment
### March 21, 2026 — Issued by Claude (Cowork)

---

## WHAT CLAUDE (COWORK) DELIVERED TODAY ✅

| Deliverable | File | Status |
|---|---|---|
| Master Career Timeline 1979–Present | `Scott_Echols_Master_Career_Timeline.docx` | ✅ DONE |
| Chatbot Knowledge Brief + System Prompt | `CHATBOT_KNOWLEDGE_BRIEF.md` | ✅ DONE |
| Netlify Config Template | `netlify.toml` | ✅ DONE |
| Antigravity QA Checklist (18 tests) | `ANTIGRAVITY_QA_CHECKLIST.md` | ✅ DONE |
| Agent Assignment Sheet | This file | ✅ DONE |

All files ready in outputs folder. Copy to repo as directed below.

---

## CLAUDE CODE CLI — YOUR ASSIGNMENTS

**Priority 1 (blocking everything else):**
```
1. Copy CHATBOT_KNOWLEDGE_BRIEF.md into knowledge_base/docs/
2. Copy netlify.toml into repo root (C:\WSP001\R.-Scott-Echols-CV\)
   - Replace FASTAPI_BACKEND_URL placeholder with actual endpoint
3. Confirm knowledge_base/public/cv/ has all 4 files:
   - 061722CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2)-1.docx
   - CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx
   - SeaTrace - Robert Scott Echols - CV.PDF
   - Scott_Echols_Master_Career_Timeline.docx
4. Update embed manifest to include Scott_Echols_Master_Career_Timeline.docx
   with partition = cv_personal, tier = 1
5. Report back: FastAPI endpoint URL confirmed, netlify.toml written,
   manifest updated. Do not run ingest — Scott runs ingest manually.
```

**Priority 2 (after Scott confirms ingest success):**
```
6. Feed CHATBOT_KNOWLEDGE_BRIEF.md content into system prompt
   (src/config/systemPrompt.ts or equivalent)
7. Verify /healthz returns current git-sha
8. Confirm CORS allows https://robertoscottecholscv.netlify.app
9. Report: system prompt updated, healthz confirmed, CORS verified
```

---

## SCOTT — YOUR ASSIGNMENTS (only you can do these)

**Step 1 — Run the ingest (do this first, today):**
```powershell
cd C:\WSP001\R.-Scott-Echols-CV
$env:PYTHONIOENCODING = "utf-8"
$env:GEMINI_API_KEY = "YOUR_REAL_KEY_HERE"
& "C:\Python313\python.exe" scripts\embed_engine.py --from-manifest
& "C:\Python313\python.exe" scripts\embed_engine.py --stats
& "C:\Python313\python.exe" scripts\embed_engine.py --query "Tell me about ALOHA-net and WARP Industries" --partition cv_personal
```
Report chunk count and proof query result to Claude Code.

**Step 2 — Set env vars in Netlify Dashboard:**
```
https://app.netlify.com → robertoscottecholscv → Site Settings → Environment Variables

Add these three:
  GEMINI_API_KEY       = [your Gemini key]
  ANTHROPIC_API_KEY    = [your Anthropic key]
  VITE_API_BASE_URL    = [your FastAPI endpoint URL]
```

**Step 3 — Netfirms SSL cert (separate from everything else):**
```
Log into netfirms.com → SSL/TLS → Add cert for seatrace.worldseafoodproducers.com
Request wildcard cert: *.worldseafoodproducers.com
OR add SAN (Subject Alternative Name) for the subdomain
This is independent of the chatbot — can be done any time
```

---

## ANTIGRAVITY — YOUR ASSIGNMENTS

**HOLD until Claude Code confirms:**
- [ ] Ingest ran clean (Scott confirms chunk count > 0)
- [ ] System prompt updated with CHATBOT_KNOWLEDGE_BRIEF content
- [ ] Netlify deploy successful

**Then execute:**
```
Run ANTIGRAVITY_QA_CHECKLIST.md in full (18 tests)
Test URL: https://robertoscottecholscv.netlify.app (NOT localhost)
Score sheet → report back to team
GREEN LIGHT threshold: 16/18 pass
Any Tier 1 failure = HOLD regardless of score
```

---

## CODEX #2 — YOUR ASSIGNMENTS

```
HOLD POSITION
No frontend work until Antigravity QA returns GREEN LIGHT
Do not touch chat.ts
Do not touch embed_engine.py
Do not own Gemini migration
Await Antigravity signoff
```

---

## WHAT MAKES THE CHATBOT SMARTER — PRIORITY RANKED

| # | Action | Owner | Impact |
|---|--------|-------|--------|
| 1 | Run ingest with GEMINI_API_KEY | Scott | 🔴 CRITICAL — nothing works without this |
| 2 | Feed CHATBOT_KNOWLEDGE_BRIEF as system prompt | Claude Code | 🔴 HIGH — 40yr history now queryable |
| 3 | Partition-aware retrieval (cv_personal vs cv_seatrace) | Claude Code | 🟡 MEDIUM — better answer targeting |
| 4 | Two-turn memory test on deployed URL | Antigravity | 🟡 MEDIUM — proves conversational quality |
| 5 | SSL cert on seatrace subdomain | Scott/Netfirms | 🟡 MEDIUM — investor credibility |
| 6 | Source attribution labels on answers | Claude Code | 🟢 NICE — transparency for users |
| 7 | Fallback honesty instruction in system prompt | Claude Code | 🟢 NICE — prevents hallucination |
| 8 | Rate limiting on /auth/token | Claude Code | 🟢 NICE — security hardening |
| 9 | SLO panel in Grafana (99.9% / 200ms) | Claude Code | 🟢 NICE — investor metrics dashboard |

---

## VALUATION IMPACT TRACKER

| Milestone | Uplift | Owner | Status |
|---|---|---|---|
| Phase 0-2 Deployment | +0.20x | Scott | ✅ Done |
| API Integration | +0.10x | Claude Code | ✅ Done |
| Rate Limiting | +0.05x | Claude Code | 🔲 Pending |
| CI/CD Pipeline | +0.05x | Claude Code | ✅ Done |
| Kong Gateway | +0.15x | Claude Code | 🔲 Pending |
| Prometheus Metrics | +0.10x | Claude Code | 🔲 Pending |
| **40yr Career in Chatbot** | **+0.10x** | **All** | **🔲 Ingest pending** |
| **CURRENT TOTAL** | **+0.45x** | | |
| **TARGET** | **+0.65x** | | |

---

*All deliverable files in outputs folder. Team, execute your lanes.*
*Next sync point: after Scott confirms ingest chunk count.*
