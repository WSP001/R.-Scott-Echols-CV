# POST REBOOT CHEAT SHEET
# Scott Echols / WSP001 — Commons Good
# Written: 2026-03-27 before shutdown

---

## STATE OF PLAY — EVERYTHING IS SAVED AND PUSHED

| Repo | HEAD Commit | Status |
|------|-------------|--------|
| SirTrav-A2A-Studio | 4d4e23b3 | ✅ Clean, pushed |
| R.-Scott-Echols-CV | 49f5cfb | ✅ Clean, pushed |

Only loose file: test_api_key.py in CV repo — untracked, not critical.

---

## WHAT WORKS RIGHT NOW (before you do anything)

- LinkedIn/Twitter posts generate in Scott's real voice ✅
- ALOHAnet, DeckSide, SeaTrace context — all injected ✅
- Veo 2 returns real jobId LRO in production ✅
- AWS/Remotion fully bypassed ✅
- CV smart cards partially fixed — Sir James and LearnQuest still MISSING

---

## THE ONE THING ONLY YOU CAN DO — CLOUD RUN

This is the only remaining operator action. Do it first after reboot.

```powershell
# Step 1 — from CV repo
cd C:\WSP001\R.-Scott-Echols-CV
gcloud auth list   # make sure you're logged in

# Step 2 — deploy
gcloud run deploy rse-retrieval `
  --source ./scripts `
  --region us-central1 `
  --allow-unauthenticated `
  --memory 512Mi

# Step 3 — verify (replace URL with what deploy printed)
.\scripts\verify-vector.ps1 -Url "https://rse-retrieval-xxx-uc.a.run.app"
# All 4 tests must PASS

# Step 4 — Netlify dashboard (can do on phone)
# sirtrav-a2a-studio → Environment Variables → Functions scope
# Key:   VECTOR_ENGINE_URL
# Value: https://rse-retrieval-xxx-uc.a.run.app

# Step 5 — trigger redeploy
git commit --allow-empty -m "chore: activate vector retrieval" && git push
```

If you can't get to Cloud Run — that's OK. App still works. Just no ChromaDB retrieval.

---

## CV CARD FIXES STILL NEEDED (Antigravity found these)

| Card | Problem |
|------|---------|
| Sir James Adventures | MISSING from Projects section entirely |
| LearnQuest | MISSING from Projects section entirely |
| SeaTrace | Present but missing Role + Status tags |
| SirTrav | Present but tagline wording differs |
| Years Experience counter | Shows 12+ — should be 39+ |

Claude Code has the card fields ready. Just needs to be wired in.

---

## ROTATE THIS — DO NOT FORGET

GitHub PAT was exposed in plaintext in your PowerShell profile.
Revoke it at: https://github.com/settings/tokens
Create a new one and store it safely — NOT in the PS profile file.

---

## AGENT PROMPTS — READY TO PASTE

All three agent prompts are in:
AGENT_ASSIGNMENTS_BEFORE_TUESDAY.md (downloaded this session)

- Slot 1 Claude Code → Sir James cleanup + CV card fixes
- Slot 2 Antigravity → CV card browser proof
- Slot 3 Scott → Cloud Run deploy (above)

---

## COMMIT ATTRIBUTION STANDARD (for all future commits)

```
Architecture credit: Scott Echols / WSP001 — Commons Good
Prompt bridge: ChatGPT
Engineering: Claude Sonnet 4.6
```

---

## SHELL STANDARD

Use pwsh (PowerShell 7.4 LTS) — not powershell.exe
Update: winget upgrade --id Microsoft.PowerShell --source winget

---

## AFTER APRIL 1 — IN ORDER

1. Rotate GitHub PAT
2. Cloud Run deploy + verify-vector.ps1
3. Set VECTOR_ENGINE_URL in Netlify (both sites)
4. Fix CV cards — Sir James + LearnQuest + Years Experience
5. Run just ingest-identity (CV repo) to populate ChromaDB
6. Antigravity browser proof — vector chunks in post output
7. Sir James Adventures repo cleanup (MASTER.md spine)

---

Good work. The foundation is solid. Rest easy.
