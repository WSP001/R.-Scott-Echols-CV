# MASTER AGENT HANDOFF: PHASE 4 — The Genie & The Glass

> **Target Agents:** Codex (Frontend) + Claude Code (Backend)
> **Context:** RobertoScottCV-Chatbot
> **Operating Rule:** Look before you leap, and read before you write. Adhere strictly to your defined lane.

This Phase elevates the CV Chatbot into a Fortune 100 enterprise experience, introducing high-velocity 3D scroll physics and persistent, edge-cached conversation state.

---

## 🛑 LANE BOUNDARY CHECK (READ FIRST)

*   **Codex (Frontend Specialist):** You own `public/index.html`. You are authorized to read the backend contracts but you CANNOT modify `netlify/edge-functions/chat.ts`.
*   **Claude Code (Backend Specialist):** You own `netlify/edge-functions/chat.ts`. You must read `scripts/embed_engine.py` to understand vector generation. You CANNOT touch the frontend HTML/Three.js logic.
*   **Antigravity (QA):** You are strictly reading both lanes to build smoke tests in `scripts/`. Do not alter functional code.

---

## 💻 AGENT MISSION 1: CODEX (The High-Velocity Glass Trace)

**Objective:** Create a visceral, cinematic scroll experience where project emblems leave a "trace" across a 3D glass overlay as the user scrolls past.

**Execution Blueprint (`public/index.html`):**

1.  **The Glass Layer:** Implement a fixed, full-viewport `div` overlay over the `hero-three` canvas. Give it `backdrop-filter: blur(12px)` and a slight noise texture, acting as the "lens" the user looks through.
2.  **GSAP ScrollTrigger + Three.js Integration:**
    *   Instead of static 2D DOM images, mount the project logos (WSP, SeaTrace, SirTrav) as 3D planes inside the existing `hero-three` canvas scene.
    *   As the user scrolls, use GSAP `ScrollTrigger` to fire high-velocity `z-axis` translations. The emblem must fly up from the depths (z: -500), pass through the "glass" layer (momentarily sharp), and fly past the camera (z: +100).
3.  **The "Trace" Effect:** Apply a Three.js `TrailRenderer` or a post-processing `AfterimagePass` (Ghosting) to the WebGL renderer. When the logo flies past at high speed, it must leave a fading motion blur on the glass.

---

## 🧠 AGENT MISSION 2: CLAUDE CODE (The Genie Un-corked & Netlify Bridge)

**Objective:** Enforce the 3-question limit while persisting the session at the Edge, ensuring zero context loss when the user later returns with a Business Access Key.

**Execution Blueprint (`netlify/edge-functions/chat.ts`):**

1.  **Device Fingerprinting & State Persistence:**
    *   Hash the user's IP + User-Agent to create a pseudo-anonymous `Device_ID`.
    *   Store the conversation history array in a global cache (Netlify Blob Store or KV map), keyed by `Device_ID`.
2.  **The Gate Logic (The Cork):**
    *   *Un-corked (Questions 1-3):* RAG is active. Context is built. Cache is updated.
    *   *The Cork (Limit Hit):* On question 3, return HTTP 429. Set `corked: true` and return the `cache_id`.
    *   *The Re-open:* When `/api/verify-access` receives the `BUSINESS_ACCESS_KEY` and a `resume_cache_id`, retrieve the session from the edge cache and restore the context array.
3.  **Cross-Lane Retrieval Injection (The Bridge):**
    Ensure the vector retrieval logic is dynamically fetching from the Cloud Run instance.

*Inject the following structural logic into `chat.ts`:*

```typescript
// netlify/edge-functions/chat.ts
import { Context } from "@netlify/edge-functions";

const ANTHROPIC_API_KEY = Netlify.env.get("ANTHROPIC_API_KEY");
const VECTOR_ENGINE_URL = Netlify.env.get("VECTOR_ENGINE_URL") || "https://your-cloud-run-engine.com/query"; 

export default async function handler(req: Request, context: Context) {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const body = await req.json();
    const userMessage = body.message;
    const isBusinessTier = body.hasAccessKey; 
    
    // [Device Fingerprinting logic goes here]

    // ----------------------------------------------------------------------
    // STEP 1: CROSS-LANE RETRIEVAL (The Vector Search)
    // ----------------------------------------------------------------------
    console.log(`[AGENT: Backend] Fetching vector context for: "${userMessage}"`);
    
    let retrievedContext = "";
    if (VECTOR_ENGINE_URL) {
      try {
        const vectorResponse = await fetch(VECTOR_ENGINE_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ query: userMessage, top_k: isBusinessTier ? 5 : 2 })
        });
        const vectorData = await vectorResponse.json();
        retrievedContext = vectorData.context_chunks.join("\n\n");
      } catch (e) {
        console.warn("Vector DB unreachable. Falling back to safe defaults.");
      }
    }

    // ----------------------------------------------------------------------
    // STEP 2: THE SYSTEM PROMPT (Strict Boundaries)
    // ----------------------------------------------------------------------
    const systemPrompt = `
      You are the Obsidian Architect, an enterprise-grade AI assistant for R. Scott Echols' CV and the SeaTrace platform.
      CRITICAL RULE: You must ONLY answer using the 'Retrieved Context' provided below. Do not hallucinate or use outside knowledge.

      --- RETRIEVED CONTEXT ---
      ${retrievedContext}
      -------------------------
    `;

    // ----------------------------------------------------------------------
    // STEP 3: CALL CLAUDE 
    // ----------------------------------------------------------------------
    // [Anthropic API call logic using systemPrompt goes here]
    // [Handle 3-question limit and caching state return payload]

  } catch (error) {
    console.error("[AGENT: Backend] Fatal Collision:", error);
    return new Response(JSON.stringify({ error: "System malfunction." }), { status: 500 });
  }
}
```

---

## 🧪 PHASE 4 VERIFICATION (The "Did it work?" Test)

Before merging, agents MUST confirm:
1.  **Codex:** Do the emblems render as true 3D planes inside the WebGL canvas (not DOM images) and leave a visual trace on scroll?
2.  **Claude Code:** Does hitting the 3-question limit return `corked: true` alongside a `cache_id`? Does the Netlify edge function correctly route vector queries to `VECTOR_ENGINE_URL`?
3.  **Antigravity:** Can you simulate a 4-question unauthenticated flow and verify the 429 response without crashing the UI?
