# HANDOFF: Claude Code — CV Card Fixes + Years Experience
# Assigned by: Windsurf/Cascade (Acting Master)
# Created: 2026-03-27
# Repo: C:\WSP001\R.-Scott-Echols-CV
# HEAD at time of writing: c6d7ac0
# Live site: https://robertoscottecholscv.netlify.app
# Truth sources: public/data/identity.json, identity_verified.md
# License: Commons Good (public) / Secure Comm Ltd (private)

## Mission
Fix project cards in public/index.html, correct the years-experience counter,
and leave provenance breadcrumbs so every edit is auditable. All claims MUST
pass truth-audit against identity.json before commit.

**Rule: truth-pack first -> edit second -> changelog third -> push last.**

---

## Task 1: Add Sir James Adventures project card
**Status:** MISSING from Projects section entirely.

| Field | Value | Source |
|-------|-------|--------|
| Title | Sir James Adventures | identity.json -> public_projects[] |
| Role | Creator / Lead Developer | identity_verified.md |
| Status | Active — Book002 production, Book003 planning | Repo commit history |
| Description | Interactive educational storybook series for young learners. Emoji-based Book001 complete (86 scenes). Multimedia Book002 with parent dashboard, virtue tracking, and A2A agent pipeline. | identity_verified.md + repo |
| Tech | HTML/CSS/JS, Netlify Functions, ElevenLabs Voice, A2A Protocol | Repo package.json / netlify.toml |
| License | Creative Commons (public) | Repo LICENSE |

**Where to insert:** In the Projects card grid in public/index.html, alongside
existing SeaTrace and SirTrav cards. Match the existing card HTML structure exactly.

## Task 2: Add LearnQuest project card
**Status:** MISSING from Projects section entirely.

| Field | Value | Source |
|-------|-------|--------|
| Title | LearnQuest | identity.json -> planned_projects[] |
| Role | Creator / Architect | identity_verified.md |
| Status | Active — Platform development | Repo + PRD |
| Description | Educational gaming platform combining Three.js 3D environments with curriculum-aligned learning paths. Parent dashboard with mastery tracking. | PRD_LEARNQUEST.md |
| Tech | Three.js, React, Netlify, Agent Orchestration | Architecture blueprint |
| License | Commons Good (public) | Repo LICENSE |

## Task 3: Fix SeaTrace card — add Role + Status tags
**Status:** Card present but missing structured Role and Status metadata.

| Field | Value | Source |
|-------|-------|--------|
| Role | Lead Architect / Systems Designer | identity.json |
| Status | Active — Investor demo prep, Four Pillars architecture | CLAUDE_CODE_PLAN.md |

**Do NOT change:** existing description text or Four Pillars references.
Only ADD the missing Role and Status tag elements to match the card template.

## Task 4: Fix SirTrav card — tagline wording
**Status:** Card present but tagline wording is off.

**Target:** "AI-powered video production pipeline — seven-agent A2A orchestration
for cinematic content creation."

Verify the replacement tagline against identity_verified.md and the SirTrav
repo README before committing. If the exact wording differs in the source docs,
use the source doc version, not this ticket.

## Task 5: Fix Years Experience counter
**Status:** Shows 12+, needs 39+.

**Math:** Career start 1988 (per identity_verified.md) -> 2026 = 38 years.
Scott's directive: use 39+ to reflect inclusive rounding of partial-year
experience dating to late 1987 prep work.

**Action:**
1. Open `public/data/identity.json` — find or add years-experience field, set to 39
2. Open `public/index.html` — find the counter display element (search for `12+` or years counter), update to `39+`
3. Log both changes in `docs/CV-CARD-CHANGELOG.md`

## Task 6: Create docs/CV-CARD-CHANGELOG.md entries
**Purpose:** Provenance log. Every edit to project cards gets a 1-line entry.
Template is already placed at `docs/CV-CARD-CHANGELOG.md` by the Acting Master.

**Rule:** No card edit gets committed without a changelog entry. Period.

---

## Truth-Audit Gate (before push)

```powershell
# 1. Verify no unsupported claims in HTML
Select-String -Path public\index.html -Pattern '\d+\+?\s*(years|clients|projects)' |
  ForEach-Object { Write-Host "CLAIM CHECK: $($_.Line.Trim())" }

# 2. Cross-check identity.json has matching project entries
$identity = Get-Content public\data\identity.json | ConvertFrom-Json
Write-Host "Projects: $($identity.public_projects -join ', ')"
Write-Host "Planned: $($identity.planned_projects -join ', ')"

# 3. Confirm years-experience value
Write-Host "Years field: $($identity.yearsExperience)"
```

**Verdict required:** All claims anchored to identity.json fields -> PASS -> commit.

## Commit message format

```
feat: add Sir James + LearnQuest cards, fix SeaTrace/SirTrav tags, years 39+ [CV-CARDS]

- Added Sir James Adventures project card
- Added LearnQuest project card
- Added Role + Status tags to SeaTrace card
- Fixed SirTrav tagline wording
- Updated years experience counter: 12+ -> 39+
- Created docs/CV-CARD-CHANGELOG.md provenance log
- All claims verified against identity.json (truth-audit PASS)
```

## FORBIDDEN
- Do NOT fabricate project details not in identity.json
- Do NOT touch edge functions or backend code
- Do NOT modify trust_policy or source_status fields
- Do NOT commit without truth-audit PASS

**FOR THE COMMONS GOOD — this is Scott's professional identity.**