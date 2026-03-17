/**
 * R. Scott Echols CV — Gemini Embedding 2 Edge Function
 *
 * Uses gemini-embedding-2-preview for multimodal embeddings.
 * Supports: text, image (base64), audio (base64), PDF (base64)
 * All modalities map to a single unified vector space.
 *
 * Endpoint: POST /api/embed
 *
 * Request body:
 * {
 *   "inputs": [
 *     { "type": "text", "content": "string" },
 *     { "type": "image", "content": "base64string", "mimeType": "image/png" },
 *     { "type": "audio", "content": "base64string", "mimeType": "audio/mpeg" },
 *     { "type": "pdf",   "content": "base64string", "mimeType": "application/pdf" }
 *   ]
 * }
 *
 * Returns:
 * {
 *   "embeddings": [ { "index": 0, "values": [0.123, ...] } ],
 *   "dimension": 3072,
 *   "model": "gemini-embedding-2-preview"
 * }
 *
 * Environment variables required:
 *   GEMINI_API_KEY — Google AI Studio or Vertex AI API key
 *   BUSINESS_ACCESS_KEY — Required for embed endpoint (business tier only)
 */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Access-Key",
  "Content-Type": "application/json",
};

interface EmbedInput {
  type: "text" | "image" | "audio" | "pdf";
  content: string; // text string OR base64-encoded bytes
  mimeType?: string;
}

export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  // Embed endpoint is business-tier only
  const accessKey = request.headers.get("X-Access-Key") || "";
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";
  if (!businessKey || accessKey !== businessKey) {
    return new Response(
      JSON.stringify({ error: "Business access required for embedding endpoint." }),
      { status: 403, headers: CORS }
    );
  }

  const geminiKey = Netlify.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    return new Response(
      JSON.stringify({ error: "Gemini API not configured." }),
      { status: 503, headers: CORS }
    );
  }

  let body: { inputs: EmbedInput[] };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: CORS,
    });
  }

  const { inputs } = body;
  if (!Array.isArray(inputs) || inputs.length === 0) {
    return new Response(JSON.stringify({ error: "inputs array required" }), {
      status: 400,
      headers: CORS,
    });
  }

  // Build Gemini API parts array
  const parts = inputs.map((inp) => {
    if (inp.type === "text") {
      return { text: inp.content };
    } else {
      // image / audio / pdf — inline bytes
      return {
        inlineData: {
          mimeType: inp.mimeType || "application/octet-stream",
          data: inp.content, // base64
        },
      };
    }
  });

  const geminiEndpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2-preview:embedContent";

  try {
    const geminiResp = await fetch(`${geminiEndpoint}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "models/gemini-embedding-2-preview",
        content: { parts },
        // taskType: RETRIEVAL_DOCUMENT or RETRIEVAL_QUERY — set as needed
        taskType: "RETRIEVAL_DOCUMENT",
      }),
    });

    if (!geminiResp.ok) {
      const errText = await geminiResp.text();
      console.error("Gemini embed error:", errText);
      return new Response(
        JSON.stringify({ error: "Embedding service error. Check GEMINI_API_KEY and model availability." }),
        { status: 502, headers: CORS }
      );
    }

    const data = await geminiResp.json();
    const values: number[] = data?.embedding?.values ?? [];

    return new Response(
      JSON.stringify({
        embeddings: [{ index: 0, values }],
        dimension: values.length,
        model: "gemini-embedding-2-preview",
        input_count: inputs.length,
      }),
      { status: 200, headers: CORS }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("Embed function error:", msg);
    return new Response(
      JSON.stringify({ error: "Embedding request failed." }),
      { status: 502, headers: CORS }
    );
  }
};

export const config = { path: "/api/embed" };
