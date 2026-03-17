/**
 * Access key verification endpoint
 * POST /api/verify-access
 * Body: { "key": "..." }
 * Returns: { "valid": true/false, "tier": "business"|"public" }
 */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json",
};

export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  let body: { key: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ valid: false }), { status: 400, headers: CORS });
  }

  const providedKey = (body.key || "").trim();
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";

  if (providedKey && businessKey && providedKey === businessKey) {
    return new Response(
      JSON.stringify({ valid: true, tier: "business", message: "Business access granted. Full knowledge base unlocked." }),
      { status: 200, headers: CORS }
    );
  }

  return new Response(
    JSON.stringify({ valid: false, tier: "public", message: "Invalid key. Continuing in public mode." }),
    { status: 200, headers: CORS }
  );
};

export const config = { path: "/api/verify-access" };
