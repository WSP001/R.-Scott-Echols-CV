# Phase 5: Knowledge Base Inventory Audit

**Agent:** Antigravity (QA Lane)
**Objective:** Confirm exactly what content is available for ingest, to prevent business material from leaking into the public chatbot tier.

### 1. Current State Assessment
- Directory `knowledge_base/` (**MISSING** - Must be generated via `setup-wsp-rag.ps1`)
- Current files in `docs/`: `WSP_SeaTrace_Overview.md`, `agent-contracts.md`
- Current file missing: `docs/asset-index.json` (Needs to be copied from `.claude/outputs` manually or populated by Scott).

### 2. Designated Corpus Splits

#### 🟢 PUBLIC TIER (Resume / Profile corpus)
**Path Designation:** `knowledge_base/public/` (or strictly tagged "PUBLIC")
**Expected Content:**
- CV/Resume PDFs
- Public personal brand story
- Public project summaries (e.g., "Built a multi-agent orchestrated pipeline")
- Contact info / consulting intro

#### 🔴 BUSINESS TIER (Deep technical corpus)
**Path Designation:** `knowledge_base/business/` (or strictly tagged "SEATRACE")
**Expected Content:**
- `WSP_SeaTrace_Overview.md` (Already securely in `docs/`)
- Four Pillars technical specifications
- Internal agent architectures (`agent-contracts.md`)
- Business consulting depth strategies

### 3. Immediate Action Required
**Scott / Claude Code:** Before running `--ingest`, you must formally branch or separate the directory structures. Do NOT drop the SeaTrace deck into the exact same unified vector space as the CV unless the vector metadata specifically tags tier clearance.
