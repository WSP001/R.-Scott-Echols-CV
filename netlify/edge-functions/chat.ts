// netlify/edge-functions/chat.ts
import { Context } from "@netlify/edge-functions";

// Securely load API Keys from Netlify Environment
const GEMINI_API_KEY = Netlify.env.get("GEMINI_API_KEY");
const VECTOR_ENGINE_URL = Netlify.env.get("VECTOR_ENGINE_URL") || "https://your-cloud-run-engine.com/query"; 

export default async function handler(req: Request, context: Context) {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  if (!GEMINI_API_KEY) {
    return new Response(JSON.stringify({ error: "Missing GEMINI_API_KEY." }), { status: 500 });
  }

  try {
    const body = await req.json();
    const userMessage = body.message;
    const isBusinessTier = body.hasAccessKey; 
    
    // Read dynamic model if set via env, otherwise default to Flash for speed & cost effectiveness
    // (As requested: Dynamic capability routing, using the latest Genie models)
    const geminiModel = Netlify.env.get("GEMINI_MODEL") || "gemini-2.5-flash";

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
    const systemInstruction = `
      You are the Obsidian Architect, an enterprise-grade AI assistant for R. Scott Echols' CV and the SeaTrace platform.
      CRITICAL RULE: You must ONLY answer using the 'Retrieved Context' provided below. Do not hallucinate or use outside knowledge. If the answer is not in the context, state that you do not have that specific data in your current memory bank.

      --- RETRIEVED CONTEXT ---
      ${retrievedContext}
      -------------------------
    `;

    // ----------------------------------------------------------------------
    // STEP 3: CALL GEMINI API (The Genie Uncorked)
    // ----------------------------------------------------------------------
    const apiEndpoint = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${GEMINI_API_KEY}`;
    
    const geminiResponse = await fetch(apiEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: {
            parts: [{ text: systemInstruction }]
        },
        contents: [
            {
                role: "user",
                parts: [{ text: userMessage }]
            }
        ],
        generationConfig: {
            maxOutputTokens: 1024,
            temperature: 0.2
        }
      })
    });

    const data = await geminiResponse.json();
    
    if (data.error) {
        console.error("[AGENT: Backend] Gemini API Error:", data.error);
        return new Response(JSON.stringify({ error: data.error.message }), { status: 500 });
    }

    const replyText = data.candidates?.[0]?.content?.parts?.[0]?.text || "I was unable to retrieve a valid response.";

    return new Response(JSON.stringify({ reply: replyText }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("[AGENT: Backend] Fatal Collision:", error);
    return new Response(JSON.stringify({ error: "System malfunction." }), { status: 500 });
  }
}
