# R. Scott Echols — Smarter CV Chatbot Master Plan
<!-- generated: 2026-03-22 | agent: Claude Sonnet 4.6 (Cowork) -->
<!-- repo: WSP001/R.-Scott-Echols-CV | site: robertoscottecholscv.netlify.app -->
<!-- rule: SirTrav = personal. SeaTrace = business. Sir James = creative. Never conflate. -->

---

## CURRENT STATE (as of 2026-03-22)

| What | Status |
|------|--------|
| CV site live on Netlify | ✅ robertoscottecholscv.netlify.app |
| Knowledge base (RSE-KB-Package-v2) | ✅ Normalized CV, manifest JSON, source map |
| Embedding model | Gemini embedding-002 → Supabase pgvector |
| Chatbot can answer about | WSP, ALOHAnet, WARP/ROCC-BART, ADS, PSG, GFW, SIMP, USPTO patent |
| Chatbot MISSING | Sir James Adventures, SirTrav Studio, DCHS Football legacy, WAFC Business |
| SirTrav vs SeaTrace separation | ✅ Fixed on career card (commit ee38052) |
| Sir James on any website card | ❌ MISSING — not deployed anywhere visible |
| GitHub CLI wired to chatbot | ❌ Not yet |

---

## ONE-BY-ONE TASK LIST

### ✅ DONE — Step 1: Audit the knowledge base
Completed 2026-03-22. Found gap: Sir James Adventures completely absent from KB and site.

---

### 🔄 IN PROGRESS — Step 2: Add Sir James Adventures to KB + site card

**2A — KB entry (ready to copy in):**
File: `sir_james_kb_entry.md` (in your Scott CV OneDrive folder)

Copy this into the repo:
```powershell
$src = "C:\Users\Roberto002\OneDrive\Scott CV\sir_james_kb_entry.md"
$dst = "C:\WSP001\R.-Scott-Echols-CV\docs\cv\sir_james_adventures.md"
Copy-Item $src $dst -Force
```

Then append to the normalized CV:
```powershell
$entry = Get-Content "C:\Users\Roberto002\OneDrive\Scott CV\sir_james_kb_entry.md" -Raw
Add-Content "C:\WSP001\R.-Scott-Echols-CV\docs\cv\cv_personal_normalized.md" "`n$entry"
```

**2B — Site card HTML (paste into public/index.html after the SeaTrace card):**

```html
<!-- SIR JAMES ADVENTURES CARD — personal creative, NOT SeaTrace business -->
<div class="career-card personal-creative" id="sir-james-card">
  <div class="card-flash-badge">⭐ NEW</div>
  <div class="card-header">
    <span class="card-icon">📚</span>
    <div>
      <h3>Sir James Adventures</h3>
      <span class="card-tag personal-tag">Personal Creative · SirTrav</span>
    </div>
  </div>
  <p class="card-period">2024 – Present</p>
  <p class="card-description">
    AI-illustrated interactive children's book series — created for grandson Sir James.
    History as it applies today: kids learn while having fun alongside parents.
    Book001 live with 80 scenes across 10 chapters. Book002 in production.
  </p>
  <div class="card-links">
    <a href="https://sirjamesadventure2024.netlify.app" target="_blank" class="card-link">📖 Read Book001</a>
    <a href="https://github.com/WSP001/SirJamesAdventures" target="_blank" class="card-link">⌨️ GitHub</a>
  </div>
  <div class="card-tech-tags">
    <span>AI Illustration</span>
    <span>80 Scenes / 10 Chapters</span>
    <span>Parent Dashboard</span>
    <span>Netlify</span>
  </div>
</div>
```

**2C — Commit and push:**
```powershell
git -C "C:\WSP001\R.-Scott-Echols-CV" add docs/cv/sir_james_adventures.md docs/cv/cv_personal_normalized.md public/index.html
git -C "C:\WSP001\R.-Scott-Echols-CV" commit -m "feat: add Sir James Adventures Books card + KB entry — personal creative project (SirTrav identity)"
git -C "C:\WSP001\R.-Scott-Echols-CV" push origin main
```

---

### ⏳ NEXT — Step 3: Wire GitHub CLI → smarter chatbot answers

**Goal:** The chatbot can answer "What repos does Scott have?" and "What is the status of SeaTrace?" by pulling live GitHub data.

**3A — Install GitHub CLI on the repo server or local:**
```bash
gh auth login
gh repo list WSP001 --limit 50 --json name,description,url,updatedAt
```

**3B — Create a `gh_context.md` file (auto-refreshed nightly) in the repo:**
```bash
gh repo list WSP001 --limit 50 --json name,description,url,updatedAt \
  | jq -r '.[] | "- [\(.name)](\(.url)) — \(.description // "no description") (updated: \(.updatedAt))"' \
  > knowledge_base/public/cv/github_repos_live.md
```

**3C — Add `github_repos_live.md` to the embed manifest (`rse_cv_manifest.json`):**
Add a new source entry:
```json
{
  "id": "src-gh-live",
  "filename": "github_repos_live.md",
  "repo_path": "knowledge_base/public/cv/github_repos_live.md",
  "type": "md",
  "access_tier": "public",
  "partition": "cv_projects",
  "chunk_separator": "- [",
  "priority": "tier2",
  "notable_content": ["SirJamesAdventures", "SeaTrace", "SirTrav", "WSP2agent", "ROBORTO-DBA-WSP"]
}
```

**3D — Wire a GitHub Action to auto-refresh nightly:**
File: `.github/workflows/refresh-gh-context.yml`
```yaml
name: Refresh GitHub Context
on:
  schedule:
    - cron: '0 6 * * *'   # 6am UTC daily
  workflow_dispatch:
jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate repo list
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh repo list WSP001 --limit 50 --json name,description,url,updatedAt \
            | jq -r '.[] | "- [\(.name)](\(.url)) — \(.description // "no description") (updated: \(.updatedAt))"' \
            > knowledge_base/public/cv/github_repos_live.md
      - name: Commit if changed
        run: |
          git config user.email "bot@worldseafoodproducers.com"
          git config user.name "WSP Bot"
          git add knowledge_base/public/cv/github_repos_live.md
          git diff --staged --quiet || git commit -m "auto: refresh GitHub repo context [skip ci]"
          git push
```

---

### ⏳ AFTER STEP 3 — Step 4: Plug-and-Play Logo Harness

**Goal:** Swap logo → swap identity context. One codebase, three faces.

**Architecture:**
```
config/
  identity.sirtrav.json     → personal emblem, SirTrav KB partition
  identity.seatrace.json    → WSP logo, SeaTrace KB partition
  identity.sirjames.json    → book emblem, Sir James KB partition
```

Each JSON contains:
- `logo_url` — the emblem/logo asset path
- `primary_color` — theme color
- `chatbot_persona` — system prompt for the chatbot
- `kb_partition` — which KB sections to pull from
- `card_set` — which project cards to show
- `site_title` — browser tab title

**Switch command:**
```bash
node scripts/switch-identity.js sirtrav    # personal mode
node scripts/switch-identity.js seatrace   # business mode
node scripts/switch-identity.js sirjames   # kids books mode
```

---

### ⏳ STEP 5: DCHS Football Legacy Card + WAFC Business Card

Two more missing cards on the site:

**DCHS Football (1975–1979):**
Scott's Dodge County High School football legacy — national-caliber program, direct path to Lees-McRae College scholarship and University of Georgia walk-on. Heritage project lives at `WSP001/DCHS-Football-`.

**WAFC Business:**
Western Alaska Fisheries Council and related business plan work. Repo: `WSP001/WAFC-Business`.

---

## VALUATION IMPACT TRACKER (updated)

| Step | What it proves | Uplift |
|------|---------------|--------|
| Step 1 (done) | KB audit complete, gaps identified | baseline |
| Step 2 (next) | Sir James card live — creative tech credibility | +0.05x |
| Step 3 | Live GitHub data in chatbot — "it knows its own repos" | +0.1x |
| Step 4 | Logo harness — demo-ready identity switching | +0.1x |
| Step 5 | DCHS + WAFC cards — full timeline visible | +0.05x |
| **Total new** | | **+0.3x on top of existing +0.4x = +0.7x** |

---

## IDENTITY SEPARATION — ENFORCED

```
SIRTRAV (personal)
  └── SirTrav-A2A-Studio
  └── Sir-TRAV-scott
  └── SirJames-A2A-Studio ──→ feeds Sir James Adventures (personal creative)

SEATRACE (business)
  └── SeaTrace002 ──→ seatrace.worldseafoodproducers.com
  └── SeaTrace003
  └── SeaTrace-ODOO

SIR JAMES ADVENTURES (personal creative)
  └── SirJamesAdventures ──→ sirjamesadventure2024.netlify.app (LIVE)
  └── SirJamesAdventures001
  └── SirJamesAdventures003

CV SITE (the hub — knows about ALL of the above)
  └── R.-Scott-Echols-CV ──→ robertoscottecholscv.netlify.app
       └── chatbot knows: WSP, SeaTrace, SirTrav, Sir James, WARP, ALOHAnet, PSG, ADS...
```

---

*For the Commons Good — WSP est. 1988*
