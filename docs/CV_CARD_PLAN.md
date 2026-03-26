# CV_CARD_PLAN.md — Career Timeline Card Audit & Proposal

> Agent: Claude Code | Lane: CV repo only
> Date: 2026-03-25
> Status: DRAFT — awaiting Scott's approval before any index.html edits

---

## CURRENT STATE — 11 Cards in `public/index.html`

| # | Period | Role | Company | Status |
|---|--------|------|---------|--------|
| 1 | 2022–Present | Founder & AI Systems Architect | WSP / SirTrav / WARP | ✅ Good — note: mentions "Claude Opus" (should be Gemini 2.0 Flash) |
| 2 | 2018–2022 | Senior Full-Stack Dev & Data Engineer | WSP / Maritime | ✅ Good |
| 3 | 2015–2018 | Software Dev & DevOps Engineer | WSP / Maritime | ✅ Good |
| 4 | 2010–2015 | SIMP Framework Architect | NOAA/NMFS / WSP | ✅ Good |
| 5 | 2003–2006 | Salmon Category Manager | Pacific Seafood Group | ✅ Good |
| 6 | 1990–2003 | Fleet Commander & Salmon Restoration Rep | WSP / Alaska | ✅ Good — combines fleet ops + R/V Pioneer Micronesia |
| 7 | 1988–Present | Founder & CEO | World Seafood Producers | ✅ Good |
| 8 | 1987–Present | Co-Founder & R&D Lead — Robotics | WARP Industries | ✅ Good |
| 9 | 1985–1990 | Systems Analyst & Network Protocol Designer | ADS / Pearl Harbor | ✅ Good |
| 10 | 1984–1987 | ALOHA-net Research Team Member | UH Manoa / Dr. Abramson | ✅ Good |
| 11 | 1979–1984 | Education Foundation | DCHS → Lees McRae → UGA → UH | ✅ Good |

---

## IDENTIFIED GAPS & ISSUES

### 1. GAP — 2006–2010 (4 years unaccounted for)
The timeline jumps from PSG Salmon Category Manager (ends 2006) directly to SIMP/NOAA (starts 2010). Per the longform CV, this period likely includes continued WSP operations, early technology consulting, and building the foundations for the SIMP advisory work.

**Recommendation:** Add a bridging card or note in card 4 acknowledging the transition period. Source: longform CV section #12 mentions "2000-present Smart-Fisheries Tech" and general consulting continuity.

### 2. MISSING — Sir James Adventures (2024–Present)
Completely absent from the timeline. Documented in CHATBOT_MASTER_PLAN.md as MISSING. This is Scott's personal creative project — AI-illustrated children's book series for grandson Sir James. Book001 live at sirjamesadventure2024.netlify.app with 80 scenes.

**Identity flag:** PERSONAL creative (SirTrav identity), NOT SeaTrace business. Must be labeled correctly.

### 3. MISSING — DCHS Football Legacy (1975–1979)
Dodge County High School football program. Scott's high school football career led directly to the Lees McRae College scholarship. Also connects to the active DCHS-Football GitHub repo (WSP001/DCHS-Football-). The pre-1984 Chignik fishing story originates from this era (flew to Alaska the night he graduated, 1979).

**Recommendation:** Add as a "legacy" card at the bottom of the timeline — makes the career arc complete and adds authentic human depth.

### 4. MISSING — WAFC Business (ongoing)
Western Alaska Fisheries Council business planning work. Active GitHub repo: WSP001/WAFC-Business. Connects to fisheries governance and the SeaTrace commercial platform mission.

**Recommendation:** Could be folded into the 2022–Present card as an active project chip rather than a separate card. Low priority vs. Sir James and DCHS.

### 5. MINOR FIX — Card 1 mentions "Claude Opus"
The 2022–Present card says "Claude Opus + Gemini Embedding 2." This should be updated to "Gemini 2.0 Flash + Gemini Embedding 2" to reflect the actual current stack (migration done 2026-03-23).

---

## PROPOSED CARD ADDITIONS (in order of priority)

### PRIORITY 1 — Sir James Adventures Card (NEW)
**Insert after:** Card 1 (2022–Present) OR as its own "Creative Projects" sidebar note
**Period:** 2024 — Present
**Role:** Creator & AI Producer — Interactive Children's Books
**Company:** SirTrav Creative / Sir James Adventures
**Style:** Distinct from tech cards — use a creative/personal color accent, NOT gold or cyan
**Label:** `PERSONAL CREATIVE · SirTrav` (never conflate with SeaTrace)

Proposed card text:
> AI-illustrated interactive children's book series created for grandson Sir James. History as it applies today — kids learn while having fun alongside parents. Book001 is live with 80 scenes across 10 chapters. Book002 in production. Built on Netlify, AI illustration pipeline, custom parent dashboard.

Achievement chips:
- 📚 Book001 Live — 80 Scenes / 10 Chapters
- 🎨 AI Illustration Pipeline
- 👨‍👧 Parent Dashboard
- 📖 Book002 In Production

Links:
- [Read Book001](https://sirjamesadventure2024.netlify.app)
- [GitHub](https://github.com/WSP001/SirJamesAdventures)

---

### PRIORITY 2 — DCHS Football Legacy Card (NEW)
**Insert after:** Card 11 (Education Foundation — at the very bottom of timeline)
**Period:** 1975 — 1979
**Role:** Student-Athlete · Program Legacy Custodian
**Company:** Dodge County High School · Eastman, Georgia
**Style:** Gold accent (heritage/legacy milestone)
**Note:** The night he graduated, Scott flew to Alaska and earned $22,000 in 2 months fishing Chignik. This card connects to the alumni engagement work in WSP001/DCHS-Football- repo.

Proposed card text:
> Dodge County High School football — national-caliber program that built discipline, leadership, and teamwork as Scott's foundation. Earned a full football scholarship to Lees McRae College, Banner Elk, NC (between Beech Mountain and Sugar Mountain ski resorts). On the night of graduation in 1979, flew to Alaska to fish Chignik — earning $22,000 in two months before reporting to football camp. Now serves as alumni engagement lead and program legacy custodian for DCHS Football via GitHub.

Achievement chips:
- 🏈 Football Scholarship — Lees McRae College
- 🎓 DCHS 1979
- 🐟 Chignik $22K — Summer 1979
- 📋 Alumni Legacy Custodian

---

### PRIORITY 3 — 2006–2010 Bridge Card (NEW or FOLDED)
**Option A:** Add a slim bridge card: "2006–2010 | WSP Technology Consulting & SIMP Pre-Development | World Seafood Producers"
**Option B:** Expand Card 4 description to note: "Building on consulting work 2006–2010..."
**Recommendation:** Option B — keep card count lean, add 1 sentence to Card 4.

---

## CHATBOT KNOWLEDGE GAP SUMMARY

The following topics are NOW embedded in `chat.ts` `RSE_CV_DATA` (added this session):
- ✅ Chignik 1979 — Hank Brindle, Anastasia, $22K, bluebacks, bottleneck strategy
- ✅ Lees McRae — Beech Mountain / Sugar Mountain
- ✅ 1987 Sitka Donut Hole testimony — pollock/cod/mackerel extinction prediction (correct)
- ✅ Roger May — Smoki Seafood → $50M, Peter Pan Seafood acquisition
- ✅ ROCC-BART Arctic gold mining plan (1988–1994)
- ✅ Thesis "Total Information Communications Network" — Dr. Abramson, FM, 128 baud, packet switching
- ✅ PSG full story — Frank Loewen, VP-level, Salmon Book 001 + Ikura Addendum, 2-year commission
- ✅ 2014 coma — IUU insight, strategy pivot from buy/sell to servicing

Still MISSING from chatbot knowledge base:
- ❌ Sir James Adventures (mentioned in CHATBOT_MASTER_PLAN.md as completely absent)
- ❌ DCHS Football legacy
- ❌ WAFC Business details
- ❌ Hawaii State Dept of Agriculture 1984–1985 (Marketing Specialist — Pacific seafood markets)

---

## PROPOSED ACTIONS (STOP POINT — awaiting Scott's approval)

1. **Fix Card 1** — change "Claude Opus" → "Gemini 2.0 Flash" (minor accuracy fix)
2. **Add Sir James Adventures card** — insert as Card 2 (after current Card 1)
3. **Add DCHS Football Legacy card** — insert as Card 12 (after Education Foundation)
4. **Expand Card 4 description** — 1 sentence bridging 2006–2010
5. **Add Sir James Adventures to chatbot KB** — `chat.ts` RSE_CV_DATA + CHATBOT_KNOWLEDGE_BRIEF.md
6. **Add DCHS Football to chatbot KB** — brief entry in RSE_CV_DATA

**WAFC card:** Recommend folding into Card 1 chips rather than a separate card.

---

## WHAT I WILL NOT CHANGE

- No changes to build, deploy, or Netlify config files
- No changes to SirTrav or SeaTrace repos
- No restructuring of sections beyond experience cards
- Will not invent any experience not sourced from longform CV or Scott's direct input

---

*Awaiting Scott's go-ahead. Will apply exactly as planned — no creative additions beyond what is documented here.*
