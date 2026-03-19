# Phase 5: Acceptance QA Gates

**Agent:** Antigravity (QA Lane)
**Target Phase:** Phase 5 (Resume RAG & Tier Boundaries)
**Objective:** Define the exact strict requirements that Claude Code & Codex #2 must meet before Phase 5 is considered 100% complete and ready for merge.

---

## 🚦 Final Approval Gate Requirements

### 1. The Resume Router Gate
- [ ] The public chatbot correctly accesses, reads, and formats answers based exclusively on the ingest of Scott's uploaded local Resume/CV and public project knowledge.
- [ ] The chatbot does NOT hallucinate skills or work experience not explicitly stated in the ingested metadata.

### 2. The Great Wall (Tier Separation) Gate
- [ ] The SeaTrace presentation deck and business-layer architecture details are strictly segregated behind the `hasAccessKey: true` boundary.
- [ ] The Edge Function router unequivocally blocks deep SeaTrace specific RAG requests if the public tier initiates them.

### 3. Graceful Fallback Gate
- [ ] **Vector API Down:** If `VECTOR_ENGINE_URL` is unreachable or times out, the public bot answers gracefully from a safe, neutral fallback string.
- [ ] **Business API Down:** If a business user attempts a deep query and the retrieval fails, the bot gracefully admits the system is offline instead of faking an "I searched the docs" claim.

### 4. Cross-Lane Discipline Gate
- [ ] **Claude Code (Backend):** Fully connected the RAG ingestion structure and the edge environment.
- [ ] **Codex (Frontend):** Remained in their lane (UI). Only outputting trust badges ("Public Profile Answer") and visual unlock states without corrupting the backend edge configurations.
- [ ] No agent stepped across their designated physical file boundaries during this Phase.

### Conclusion Phase
When all checks pass, Antigravity will stamp approval, the Master PRD will log the successful run, and Phase 5 will conclude.
