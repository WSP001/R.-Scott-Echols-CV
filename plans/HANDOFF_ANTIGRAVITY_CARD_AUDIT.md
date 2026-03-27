# HANDOFF: Antigravity — CV Smart Cards Browser Proof
# Assigned by: Windsurf/Cascade (Acting Master)
# Date: 2026-03-27
# Deadline: Before Tuesday shutdown (2026-04-01)
# Target repo: C:\WSP001\R.-Scott-Echols-CV
# Live site: https://robertoscottecholscv.netlify.app

## MODE: Read-only recon first. No code until recon is complete.

## RECON (run these, report findings)
```powershell
curl -s https://robertoscottecholscv.netlify.app | Select-String "project|card|sir james|sirtrav|seatrace|learnquest"
Get-Content C:\WSP001\R.-Scott-Echols-CV\public\data\identity.json | python -m json.tool | Select-String "project|card|sir"
```

## MISSION
Verify that the CV site project cards are accurate and smart.
The four projects are: **SeaTrace, SirTrav A2A Studio, Sir James Adventures, LearnQuest.**

## WHAT "SMART CARD" MEANS
Not a chatbot. Not a vector search. A project card that shows:
- Correct project name and description
- Scott's actual role (Founder, Architect, Creator — not generic)
- Current status (Live / In Progress / Planned)
- Real link (GitHub or live URL)
- Tags that match identity_verified.md

## WHAT TO CHECK PER CARD

**SeaTrace:**
- Should say: "Maritime supply chain traceability — Four Pillars (SeaSide, DeckSide, DockSide, MarketSide)"
- Status: Live demo at seatrace.worldseafoodproducers.com
- Role: Founder and AI Systems Architect

**SirTrav A2A Studio:**
- Should say: "D2A multi-agent video production — photos to cinematic social posts"
- Status: Live at sirtrav-a2a-studio.netlify.app
- Veo 2 producing real jobId in production (confirmed 2026-03-27)

**Sir James Adventures:**
- Should appear (may be missing — this is the gap to flag)
- If missing: note it as MISSING and report the card fields Claude Code prepared
- Role: Creator / Gramps (personal project for grandson)

**LearnQuest:**
- Should appear with basic description
- Status: In progress / planned

## OUTPUT FORMAT — one short truth report
```
CARD AUDIT RESULT
-----------------
SeaTrace card:     PRESENT / MISSING | ACCURATE / STALE
SirTrav card:      PRESENT / MISSING | ACCURATE / STALE
Sir James card:    PRESENT / MISSING | (if missing: report fields needed)
LearnQuest card:   PRESENT / MISSING | ACCURATE / STALE

Missing 20 years of history?
Check: does the CV timeline show pre-2005 career entries?
identity.json career start date: (what does it say?)
Live site "Years Experience" counter: (what number does it show?)

RECOMMENDED FIXES: (list only real gaps, no fabrication)
```

## FORBIDDEN
- Do NOT modify any CV files
- Do NOT touch SirTrav or SeaTrace repos
- Do NOT claim cards are accurate without loading the live page

**FOR THE COMMONS GOOD — this is Scott's professional identity, treat it carefully.**