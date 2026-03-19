# MASTER AGENT HANDOFF: PHASE 5 — The Backend Router (Greenlit)

> **Target Agent:** Claude Code (Backend Specialist)
> **Context:** Phase 5 Tier-Boundary Enforcement and Graceful RAG Routing
> **Operating Rule:** Antigravity has established the QA gates. Read the testing constraints before altering the routing.

This Phase secures the API boundaries. The chatbot must cleanly route Public users to public-only embeddings while permitting Business users to access the proprietary SeaTrace chunks — while ensuring zero cross-contamination.

---

## 🛑 LANE BOUNDARY CHECK (READ FIRST)

*   **Codex (Frontend):** Waiting on you. Codex will not touch `public/index.html` UI trust states until this backend contract is solid.
*   **Antigravity (QA):** Has mapped the testing framework in `docs/PHASE5_*`. You must satisfy those constraints.
*   **Claude Code (You):** You own the backend.

### **Read First:**
- `CLAUDE.md`
- `docs/agent-contracts.md`
- `docs/PHASE5_KNOWLEDGE_INVENTORY.md`
- `docs/PHASE5_TIER_BOUNDARY_TESTS.md`
- `docs/PHASE5_INGEST_VERIFICATION.md`
- `plans/HANDOFF_PHASE5_QA_GATES.md`
- `scripts/test-phase5-rag-prompts.json`

### **Strict Write Lane:**
- `netlify/edge-functions/chat.ts`
- `scripts/api_server.py`
- `scripts/embed_engine.py`
- `docs/agent-contracts.md`

**DO NOT EDIT** `public/index.html` or any frontend phase 4 files.

---

## 🧠 MISSION: TIER-SAFE ROUTING

### 1. Make the Public/Business Corpus Split Real
*   The directories `knowledge_base/public/` and `knowledge_base/business/` have been created. (Scott will drop the files in them).
*   Update `embed_engine.py` to ingest these with strict partition metadata (`public` vs `business`).

### 2. Fix the Retrieval Bridge Mismatch
*   `chat.ts` is currently calling a legacy shape and expecting `context_chunks`.
*   `api_server.py` exposes `/retrieve`.
*   You must align the endpoint and payload/response formats between Edge and Cloud Run.

### 3. Enforce Tier Boundaries Server-Side
*   Public users must NEVER retrieve business partitions.
*   An invalid or missing business key MUST block business retrieval before vector search occurs.

### 4. Pass Explicit Tier Logic
*   Public requests search public partitions only.
*   Business requests may expand search scope only after valid authorization.

### 5. Implement Graceful Fallback
*   If `VECTOR_ENGINE_URL` is unreachable or down, return a safe fallback. Do not crash the chat.
*   If business retrieval fails, admit the system is unavailable; do not fake a grounded answer.

### 6. Reconcile Generation Model Contract
*   The contract (`CLAUDE.md`) dictates Claude Opus 4.6 for generation. If `chat.ts` drifted to Gemini or Sonnet, fix it back to Opus (or update `agent-contracts.md` if the architectural decision changed).

---

## 🧪 VERIFICATION REQUIRED BEFORE REPORTING SUCCESS

You must run these checks before returning to the Master:

1.  **Ingest locally:** Run `docs/PHASE5_INGEST_VERIFICATION.md` using the new partition setup.
2.  **Test Prompts:** Execute `scripts/test-phase5-rag-prompts.json` against:
    *   Public Safe
    *   Public Escalation (attempting to steal SeaTrace IP)
    *   Business Authorized
    *   False Authorization
3.  **Prove the Wall:** Show that the public tier cannot retrieve SeaTrace/Four Pillars proprietary details.
4.  **Test Fallback:** Break the `VECTOR_ENGINE_URL` locally and ensure `/api/chat` doesn't return a 500.

---

**Success Condition:** Antigravity's Phase 5 QA gates pass without Codex needing to touch the frontend first.
