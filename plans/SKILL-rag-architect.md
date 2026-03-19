# SKILL: RAG Architect (The Netlify Bridge)

> **Context:** This skill defines the exact architecture required to bridge a globally distributed CDN edge function (Netlify) with a heavy, Python-based Vector Search engine (Cloud Run/Local). 
> **Why it matters:** Edge functions cannot run heavy Python vector-math directly. This script turns the Edge Function into the Communicator, firing a quick request to the Vector Engine to get exact paragraphs from slide decks/docs, then feeding them to Claude.

***

### 🚀 AGENT MISSION: PHASE C - UI Hookup (The Netlify Bridge)

**Target File:** `netlify/edge-functions/chat.ts` 
**Agent Role:** Backend Interface Specialist
**Objective:** Replace hardcoded `RSE_CV_DATA` with a dynamic Retrieval-Augmented Generation (RAG) context injection.

#### 🛑 1. LANE BOUNDARY CHECK (READ FIRST)
* **CROSS-LANE READ ALLOWED:** You MUST read `scripts/embed_engine.py` to understand how the vectors are generated. You MUST read `CLAUDE.md` to understand the SeaTrace/CV persona. 
* **STRICT WRITE LANE:** You are ONLY authorized to edit `netlify/edge-functions/chat.ts`. Do not touch the frontend HTML or the Python ingestion scripts.

#### 🧠 2. THE ARCHITECTURAL LOGIC
When the user asks a question, this Edge Function will:
1. Intercept the user's question.
2. Send it to our Vector Engine (to get the embeddings and search ChromaDB).
3. Take the returned "Chunks" of truth, inject them into the Claude System Prompt, and generate the final answer.

#### 💻 3. THE CODE TO INJECT (WRITE OPERATION)
*Agent Instructions: Overwrite the logic in `netlify/edge-functions/chat.ts` with the following modern architecture.*

```typescript
// netlify/edge-functions/chat.ts
import { Context } from "@netlify/edge-functions";

// Securely load API Keys from Netlify Environment
const ANTHROPIC_API_KEY = Netlify.env.get("ANTHROPIC_API_KEY");
const VECTOR_ENGINE_URL = Netlify.env.get("VECTOR_ENGINE_URL") || "https://your-cloud-run-engine.com/query"; 

export default async function handler(req: Request, context: Context) {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const body = await req.json();
    const userMessage = body.message;
    const isBusinessTier = body.hasAccessKey; 

    // ----------------------------------------------------------------------
    // STEP 1: CROSS-LANE RETRIEVAL (The Vector Search)
    // ----------------------------------------------------------------------
    console.log(`[AGENT: Backend] Fetching vector context for: "${userMessage}"`);
    
    let retrievedContext = "";
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
      retrievedContext = "R. Scott Echols is the founder of World Seafood Producers and creator of the SeaTrace Four Pillars architecture.";
    }

    // ----------------------------------------------------------------------
    // STEP 2: THE SYSTEM PROMPT (Strict Boundaries)
    // ----------------------------------------------------------------------
    const systemPrompt = `
      You are the Obsidian Architect, an enterprise-grade AI assistant for R. Scott Echols' CV and the SeaTrace platform.
      
      CRITICAL RULE: You must ONLY answer using the 'Retrieved Context' provided below. Do not hallucinate or use outside knowledge. If the answer is not in the context, state that you do not have that specific data in your current memory bank.

      --- RETRIEVED CONTEXT ---
      ${retrievedContext}
      -------------------------
    `;

    // ----------------------------------------------------------------------
    // STEP 3: CALL CLAUDE OPUS
    // ----------------------------------------------------------------------
    const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-3-opus-20240229", // Or your preferred model
        max_tokens: 1024,
        system: systemPrompt,
        messages: [{ role: "user", content: userMessage }],
      }),
    });

    const data = await anthropicResponse.json();
    
    return new Response(JSON.stringify({ reply: data.content[0].text }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("[AGENT: Backend] Fatal Collision:", error);
    return new Response(JSON.stringify({ error: "System malfunction." }), { status: 500 });
  }
}
```

#### 🧪 4. VERIFICATION (The "Did it work?" Test)
After writing this code, you MUST run the following checks before reporting success:
1. Did you verify the `VECTOR_ENGINE_URL` environment variable is documented for the DevOps agent to set up in Netlify?
2. Run a test curl to the local Netlify dev server to ensure it handles the POST request without throwing a 500 error.
