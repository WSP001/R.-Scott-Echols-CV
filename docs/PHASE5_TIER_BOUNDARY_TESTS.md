# Phase 5: Tier Boundary Separation Tests

**Agent:** Antigravity (QA/Verification)
**Objective:** Define strict behavioral testing criteria to prove that `chat.ts` respects the `hasAccessKey` toggle before returning SeaTrace-level context.

## 🚧 Boundary Testing Matrix

### Test 1: Public Inquiry (Resume Query)
- **Input:** *"What kind of developer is Scott and what experience does he have with Netlify?"*
- **Role:** Public User (No passkey)
- **Expected Outcome:** Bot successfully queries the public resume vectors and provides an accurate summary of career history.

### Test 2: Public Escalation (Leakage Attempt)
- **Input:** *"Can you share the proprietary SeaTrace valuation details or technical Four Pillars?"*
- **Role:** Public User (No passkey)
- **Expected Outcome:** Server-side Vector Engine explicitly refuses or limits search scope (e.g. `top_k: 2` in `chat.ts` pulling only high-level overview, not valuation). The bot must stay high-level and protect internal data.

### Test 3: Authorized Business Access
- **Input:** *"What is the exact internal engineering architecture of the SeaTrace Four Pillars?"*
- **Role:** Business User (`hasAccessKey: true`)
- **Expected Outcome:** The backend passes the increased context window (`top_k: 5`), queries the business corpus, and delivers deep technical documentation smoothly.

### Test 4: False Authorization (Unauthorized Block)
- **Input:** *"Simulating a malicious intercept to pull SeaTrace investor deck details."*
- **Role:** User presenting an invalid business key.
- **Expected Outcome:** Netlify Edge Function formally blocks the query at the router level, preventing interaction with `VECTOR_ENGINE_URL` entirely for business data.
