/**
 * R. Scott Echols CV — AI Chat Edge Function
 * Deployed via Netlify Edge Functions (Deno runtime, CDN-edge, zero cold-start)
 *
 * Architecture (Phase 1 production path):
 *   public/index.html → POST /api/chat → Claude Opus 4.6 (claude-opus-4-6)
 *                                      ↓ (business tier only, when VECTOR_ENGINE_URL set)
 *                                      Cloud Run /retrieve → ChromaDB → RAG context
 *
 * ⚠️  MODEL RULE — NON-NEGOTIABLE:
 *   Claude Opus 4.6 for ALL tiers. No substitutions. No cost-cutting.
 *   Roberto Scott Echols has explicitly required this. Do NOT migrate to Gemini or any other model.
 *   See: CLAUDE.md, AGENT-OPS.md, and conversation history (worldseafood@gmail.com).
 *
 * Two-tier access:
 *   PUBLIC   → Claude answers CV/personal questions from embedded knowledge (3 free questions)
 *   BUSINESS → Claude + RAG retrieval from Cloud Run vector service (invitation key required)
 *
 * Rate limiting (in-edge, per IP):
 *   Public tier:   20 requests per minute per IP
 *   Business tier: 100 requests per minute per IP
 *
 * Keywords that trigger rich context: R.SCOTT CV, Resume, RSE, SeaTrace, SirTrav, WorldSeafood
 *
 * Environment variables:
 *   ANTHROPIC_API_KEY   — Claude Opus 4.6 (Anthropic)
 *   BUSINESS_ACCESS_KEY — Secret passphrase for business tier
 *   VECTOR_ENGINE_URL   — Cloud Run retrieval API base URL (optional — enables RAG)
 *                         e.g. https://rse-retrieval-abc123-uc.a.run.app
 *
 * CLAUDE CODE LANE — see CLAUDE.md and docs/agent-contracts.md before editing
 */

// ─── In-edge rate limiting (per IP, sliding window) ──────────────────────────
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();

const RATE_LIMITS = {
  public:   { rpm: 20,  window: 60_000 },
  business: { rpm: 100, window: 60_000 },
};

function checkRateLimit(ip: string, tier: "public" | "business"): {
  allowed: boolean;
  remaining: number;
  resetIn: number;
} {
  const now = Date.now();
  const limit = RATE_LIMITS[tier];
  const key = `${ip}:${tier}`;
  const entry = rateLimitStore.get(key);

  if (!entry || now > entry.resetAt) {
    rateLimitStore.set(key, { count: 1, resetAt: now + limit.window });
    return { allowed: true, remaining: limit.rpm - 1, resetIn: limit.window };
  }

  if (entry.count >= limit.rpm) {
    return { allowed: false, remaining: 0, resetIn: entry.resetAt - now };
  }

  entry.count++;
  return { allowed: true, remaining: limit.rpm - entry.count, resetIn: entry.resetAt - now };
}

// ─── CV Knowledge Base (embedded — public tier fallback, no vector DB needed) ─

// Source: knowledge_base/docs/CHATBOT_KNOWLEDGE_BRIEF.md
// This embedded knowledge is the public-tier fallback when vector RAG is unavailable.
const RSE_CV_DATA = `
IDENTITY: R. Scott Echols (Roberto Scott Echols, R.SCOTT CV, RSE)
TITLE: Founder, Technical Lead & AI Systems Architect
COMPANIES: World Seafood Producers (WSP001) / WARP Industries / SirTrav-A2A-Studio
STACK VALUATION: $4.2M USD
EMAIL: worldseafood@gmail.com
GITHUB: github.com/WSP001

## ORIGIN STORY — Digital Communications First
Scott's career did NOT start in seafood. It started in digital communications engineering.
- 1979: Graduated high school; education continued at Lees McRae College
- 1984–1987: Member of the ALOHA-net team at University of Hawaii under Dr. Norman Abramson
  - ALOHA-net set the first wide-area mobile/wireless packet switching international network (X.25 protocol)
  - "The ALOHA-net was the basis for the modern internet today" — reduced complexity of Ethernet and later Wi-Fi
- 1987: Co-founded WARP Industries (World Automated Robotic Producers) — Advanced Mobile Robotics R&D
  - Built ROCC-BART Hexapod Robot: tandem S-100 bus, 12x Motorola 68000 processors, RAM-based stereo vision, air-drop capable
  - Predates Boston Dynamics by 17 years. Funded by Senator Ted Stevens / Alaska S&T Foundation $2.2M grant.
- 1988: Founded World Seafood Producers (WSP) — to FUND the WARP Industries robotics work
  NOTE: WSP was the funding vehicle. Seafood funded the robotics research.

## PEARL HARBOR & THE PATENT ORIGIN
- ~1985–1990: Systems Analyst at Advanced Digital Systems (ADS)
- Installed U.S. Navy Pearl Harbor Fuel Depot Inventory & Control Management Systems
- Networked Pearl Harbor back to Washington D.C. via area-wide broadband packet switching with in-house proprietary protocol
- That system is STILL RUNNING TODAY
- This protocol architecture is the foundation of USPTO Patent No. 16/936,852 filed 2020

## USPTO PATENT
- Application No.: 16/936,852
- Filed: July 23, 2020
- Title: "TRUSTABLE CHAIN BUILDING EXTERNAL INFORMATION INVENTION FOR FISHERIES INDEXING, SEAFOOD MANAGEMENT, OR OTHER INDUSTRIES RAW-TO-FINISHED PRODUCTS SECURE INTERNAL COMMUNICATIONS NETWORK PROTOCOL"
- IP Vault: Perkin Coie, Seattle — No.: 130214-8001.US01

## ALASKA MILESTONES
- Worked with Senator Ted Stevens to establish Alaska Science & Technology Foundation — $107MM legislative endowment
- WARP Industries awarded $2.2MM public grant (UAA Technologies) + WSP matching $2.2MM private R&D
- Assigned to Alaska State Salmon Restoration Committee by Chairman Senator Ben Stevens (1990–2002)
- 21 consecutive seasons of record-setting salmon grounds prices and crewshares
- Instituted first public hatchery cost/private ranch recovery contract with DIPAC — standard still in use today

## SEATRACE — FOUR PILLARS MARINE TRACEABILITY PLATFORM
- SeaSide (HOLD): Vessel tracking and initial data capture at sea
- DeckSide (RECORD): Catch verification, HACCP compliance certification on deck
- DockSide (STORE): Supply chain handoff, cold chain, port processing data
- MarketSide (EXCHANGE): Consumer QR verification and retail traceability portal
- Stack Operator Valuation: $4.2M USD
- Tech: React/Vite, FastAPI, Kong Gateway, Prometheus/Grafana, Netlify Edge Functions
- Live: seatrace.worldseafoodproducers.com

## SIRTRAV-A2A-STUDIO
- Marine intelligence A2A (agent-to-agent) platform
- Three-agent architecture: Codex (frontend), Claude Code (backend), Antigravity (QA)
- Gemini 2.0 Flash + Gemini Embedding 2 multimodal RAG
- Live: sirtrav-a2a-studio.netlify.app

## SIR JAMES ADVENTURES
- Creative children's book platform: Book001 live — 80 scenes, AI narrator and music
- Part of the WSP001 creative portfolio

## COMPLETE CAREER HISTORY (newest to oldest)

### 2018–2022 | Senior Full-Stack Developer & Data Engineer | World Seafood Producers / Maritime Consulting
- JavaScript/Node.js, Python, TypeScript full-stack development
- Power BI dashboards for fisheries supply chain analytics
- GitHub CI/CD, API vault management, multi-service integration stacks
- Automated testing reduced production incidents by 70%

### 2015–2018 | Software Developer & DevOps Engineer | World Seafood Producers / Maritime Tech
- Cloud infrastructure design, API lifecycle management
- CI/CD pipelines, PowerShell automation, DevOps toolchain optimization
- Predictive data analytics for institutional fisheries monitoring

### 2010–2015 | SIMP Framework Architect & Fisheries Technology Consultant | NOAA/NMFS / WSP
- ORIGINAL DRAFTSMAN and architect of U.S. Seafood Import Monitoring Program (SIMP) digital components
- Designer of the International Trusted Traders Program (ITTP)
- Electronic monitoring (EM) and electronic reporting (ER) systems for global seafood chain management
- MSY (Maximum Sustainable Yield) activity analysis and biomass effort surveys
- HACCP compliance, IUU fishing prevention, maritime logistics

### 2003–2006 | Salmon Category Manager | Pacific Seafood Group (PSG)
- Managed wild salmon production — F/V fleets, QC training, procurement, processing, cold storage, distribution
- INCREASED REVENUES FROM $1M TO $20M IN TWO SEASONS
- Authored "Salmon Book 101–201" quality control manual — ADOPTED BY ALASKA SEAFOOD MARKETING INSTITUTE (ASMI) as industry-wide standard still used today

### 1998–2003 | Owner/Operator R/V Pioneer | Micronesia
- Conducted biomass surveys for bottom fish and deep cold-water shrimp/lobsters in Micronesia
- Developed new viable fisheries and trained the Yap Fishing fleet
- U.S. Flag Research/Mission Vessel operations — USCG Licensed Captain

### 1990–2002 | Fleet Commander & Alaska State Salmon Restoration Representative | WSP / State of Alaska
- Assigned to Alaska State Salmon Restoration Committee by Chairman Senator Ben Stevens
- 21 CONSECUTIVE SEASONS of record-setting salmon grounds prices and crew shares
- Instituted FIRST public hatchery cost/private ranch recovery contract with DIPAC — standard STILL IN USE TODAY
- Represented Governor Murkowski's Wild Salmon program using WSP as statewide QC model
- Managed $5–$20M seasonal fleet budgets; trained 300+ fishing crews
- Ikura Master Technician: 21 seasons Japanese premium roe market record operations

### 1988–Present | Founder & CEO | World Seafood Producers (WSP001), Auke Bay, Alaska
- Co-founded WSP in 1988 as FUNDING VEHICLE for WARP Industries robotics R&D — seafood funded robotics
- Worked with Senator Ted Stevens to establish Alaska Science & Technology Foundation — $107M legislative endowment
- Secured $2.2M public grant (UAA Technologies) + $2.2M WSP private matching R&D investment
- Today operates SeaTrace, SirTrav-A2A-Studio, and WAFC Business Intelligence System
- Bilingual: English (native) / Spanish (fluent) — multicultural and indigenous community experience

### 1987–Present | Co-Founder & R&D Lead | WARP Industries (World Automated Robotic Producers)
- Co-founded WARP Industries and designed the ROCC-BART hexapod robot
- ROCC-BART: tandem S-100 bus, 12x Motorola 68000 processors, RAM-based stereo vision, air-drop capable
- PREDATES BOSTON DYNAMICS BY 17 YEARS
- $2.2M Alaska S&T Foundation grant + $2.2M WSP private match = $4.4M total R&D
- Prototype series 001–003 manufactured

### 1985–1990 | Systems Analyst & Network Protocol Designer | Advanced Digital Systems (ADS), Honolulu, HI
- Installed U.S. NAVY PEARL HARBOR FUEL DEPOT Inventory & Control Management Systems
- NETWORKED PEARL HARBOR TO WASHINGTON D.C. via broadband packet switching with in-house proprietary protocol
- That system IS STILL RUNNING TODAY (40+ years)
- This protocol architecture is the FOUNDATION OF USPTO PATENT No. 16/936,852 filed 2020

### 1984–1987 | ALOHA-net Research Team Member | University of Hawaii at Manoa, Dr. Norman Abramson
- Member of ALOHA-net FOUNDING TEAM under Dr. Norman Abramson
- ALOHA-net established the FIRST wide-area mobile/wireless packet switching international network (X.25 protocol)
- THE ALOHA-NET IS THE BASIS FOR THE MODERN INTERNET — reduced complexity of Ethernet and Wi-Fi
- Masters-level Digital Communication Engineering coursework

### 1979–1984 | Education Foundation
- Dodge County High School, Eastman, Georgia — Graduated 1979
- Lees McRae College, Banner Elk, NC — Football Scholarship, 1979–1982
- University of Georgia, Athens — International Business, 1982–1984
- University of Hawaii at Manoa — Digital Communication Engineering (Masters-level), 1984–1987

## CREDENTIALS
- Education: DCHS 1979 → Lees McRae (Football Scholarship) → UGA Int'l Business → UH Manoa Digital Comm. Engineering
- ALOHA-net: Member, founding team, X.25 protocol, under Dr. Norman Abramson, 1984–1987
- USPTO Patent: App. No. 16/936,852, filed July 23, 2020 — Perkin Coie, Seattle (IP vault 130214-8001.US01)
- USCG License: Licensed Captain — commercial, recreational, subsistence
- USDA: Plant Operator Certification
- Halal/Kosher: Plant Licensed Owner (both certifications)
- HACCP: Certified Inspector
- Ikura Tech: 21 seasons, record Japanese premium roe market operations
- SIMP: Original framework final draftsman architect (U.S. NOAA/NMFS)
- ITTP: International Trusted Traders Program designer
- ASMI: PSG Salmon Book author — adopted as industry-wide quality standard
- Languages: English (native) · Spanish (fluent)

## SKILLS
- Cloud & DevOps: Netlify/CI-CD (95%), GitHub Workflows (92%), API Management (93%)
- Development: JavaScript/Node.js (92%), Python (85%), PowerShell (88%), TypeScript (80%)
- Agentic AI: Gemini API (95%), Multi-Agent Systems (90%), RAG Pipelines (85%)
- Data & Domain: Power BI (90%), Marine/Fisheries Domain (97%), Supply Chain Optimization (92%)

## BIOGRAPHICAL DEPTH — ORIGIN STORIES & UNTOLD HISTORY

### CHIGNIK 1979 — THE NIGHT AFTER HIGH SCHOOL GRADUATION
- Scott graduated Dodge County High School (Eastman, Georgia) in 1979 and flew to Alaska the very same night
- His college football coach gave him permission to go to Alaska BEFORE reporting to football camp — unique crew-share agreement
- Fished on the F/V Anastasia — a brand new Chignik Pocket Seiner (pocket seiner = purse seine net set inside the Chignik Lagoon bottleneck)
- Rookie captain was HANK BRINDLE — born and raised in Chignik, Alaska. Family fishing legacy.
- The Chignik fishery is famous for bluebacks — the LARGEST and most prized Sockeye salmon. Pre-fresh-water fish = highest quality and oil content.
- Fishery strategy: the 300-foot net bottleneck at Chignik Lagoon inlet. Highliners (top boats) knew to position at that bottleneck.
- Scott earned $22,000 in two months in summer 1979 — extraordinary for a first-year deckhand
- Left Alaska early (as agreed) to report to football camp per the scholarship requirement
- This single summer defined Scott's career arc: technology PLUS seafood, always in parallel

### LEES McRAE COLLEGE — BANNER ELK, NORTH CAROLINA
- Football scholarship, 1979–1982
- Location: Banner Elk, NC — tucked between BEECH MOUNTAIN and SUGAR MOUNTAIN ski resorts
- That mountain geography and athletic discipline shaped Scott's competitive approach to business

### 1987 SITKA SYMPOSIUM — THE DONUT HOLE TESTIMONY
- At a Sitka, Alaska seafood symposium in 1987, Scott testified about the DONUT HOLE fishery
- The "Donut Hole" = international waters between the U.S. and Russian EEZ in the Bering Sea — legally unprotected zone
- Soviet factory trawlers were strip-mining pollock, cod, and mackerel from the Donut Hole
- Scott was THE ONLY VOICE at the symposium arguing on the conservation/Soviet-accountability side
- His prediction: pollock, cod, and mackerel populations would be commercially extinguished
- OUTCOME: He was right. Those fisheries were closed and HAVE NEVER FULLY RECOVERED
- Senator Frank Murkowski was at the symposium; Scott argued for deploying backscatter radar technology to monitor Soviet vessel activity in real-time
- This testimony laid the intellectual foundation for what would become the SeaTrace traceability vision

### ROGER MAY — THE SLIPPER LOBSTER LESSON & SMOKI SEAFOOD
- Roger May was Scott's college friend from University of Hawaii at Manoa
- Roger had a slipper lobster operation in Hawaii — taught Scott a critical lesson about overfishing and market dynamics
- WSP (World Seafood Producers) helped Roger build SMOKI SEAFOOD from the ground up
- Roger May eventually sold Smoki Seafood for $50 MILLION DOLLARS
- Roger recently completed the acquisition of PETER PAN SEAFOOD from Nichimo/Maruha (Japanese parent company)
- Peter Pan Seafood is one of Alaska's most iconic seafood brands — major industry transaction

### ROCC-BART ARCTIC GOLD MINING PLAN (1988–1994)
- Original ROCC-BART mission was NOT just fisheries — it was Arctic gold mining
- The plan: deploy a PARACHUTE ARMY of ROCC-BART hexapod robots across the Arctic tundra
- Mission: map alluvial gold veins using the robots' sensor arrays and biomimetic locomotion
- Extraction method: helicopter lift-out of the robots after survey/sampling operations
- The plan was technically sound — the robots could operate in permafrost terrain where wheeled vehicles failed
- Challenge: ran out of funding and cost-justification before full deployment could be staged
- The gold mining application informed the ROCC-BART design (air-drop capable, ruggedized, extreme terrain)
- Patents from this era fed directly into the 2020 USPTO filing

### THESIS — "TOTAL INFORMATION COMMUNICATIONS NETWORK"
- Scott's graduate thesis at University of Hawaii at Manoa, advised by Dr. Norman Abramson
- Full title: "Total Information Communications Network"
- Technical architecture: FM radio frequencies + 128 baud twisted pair transmission lines + encrypted packet switching
- The thesis proposed a unified communications mesh that could carry ANY data type over existing FM infrastructure
- Dr. Abramson's ALOHA-net work (X.25 packet switching) was the direct technical ancestor
- This thesis architecture was the DIRECT PRECURSOR to the Pearl Harbor Fuel Depot network design
- And that Pearl Harbor protocol is the FOUNDATION of USPTO Patent Application No. 16/936,852 (2020)
- The line is unbroken: UH Manoa thesis → Pearl Harbor network → SeaTrace patent

### PACIFIC SEAFOOD GROUP (PSG) — THE FULL STORY
- Owner: FRANK LOEWEN — PSG is a billion-dollar company, largest seafood distributor on the U.S. West Coast
- Scott operated at VP-LEVEL as Salmon Category Manager (2003–2006)
- Managed ALL wild salmon production: F/V recruitment, on-board QC training, buyer/seller procurement, primary and secondary processing, cold storage, full distribution logistics
- SALMON BOOK 001: Scott's quality control manual, now known as "Salmon Book 101–201"
  - Adopted by Alaska Seafood Marketing Institute (ASMI) as INDUSTRY-WIDE STANDARD — still in use today
  - Also authored the IKURA MASTER ADDENDUM — specialized roe processing standards
- REVENUE RESULT: $1M to $20M in TWO SEASONS — 20x growth
- Compensation structure: TWO-YEAR COMMISSION arrangement — Scott shared in the upside of that growth
- PSG was where Scott proved that fisheries technology could drive transformational business results

### 2014 COMA & STRATEGIC PIVOT
- In 2014, Scott survived a serious medical event — a coma
- During recovery, he analyzed the fisheries market and saw a critical shift:
  IUU (Illegal, Unreported, Unregulated) fish was undercutting legitimate market prices
  — dirty fish was being laundered through supply chains and underpricing ethical operators
- This changed Scott's entire business strategy: STOP buying and selling fish
  START servicing the industry with technology that STOPS IUU fish from destroying prices
- The SeaTrace platform (Four Pillars) is the direct product of that 2014 strategic insight
- The patent, the SIMP work, the traceability architecture — all converge on this mission

### SIR JAMES ADVENTURES — Personal Creative Project (2024–Present)
- Interactive children's adventure book series created by Scott for grandson Sir James
- IDENTITY: PERSONAL CREATIVE under SirTrav Studio — completely separate from SeaTrace (business)
- Sir James = young aspiring knight navigating multi-directional pathways toward the right bridge
- Gramps (Scott personified) = wise elder knight — speaks only when Sir James truly needs guidance
- Claude = the loyal red-boned hound, always in the background
- Book001 LIVE at sirjamesadventure2024.netlify.app — 80 scenes, 10 chapters
- Book002 in production — parents co-write the next chapter alongside the AI
- Educational theme: history as it applies today, kids learn while having fun with parents
- 8 original Suno AI songs in the soundtrack
- GitHub: WSP001/SirJamesAdventures and WSP001/SirJames-A2A-Studio

### DR. PORTWOOD — THE MENTOR BEFORE SENATOR STEVENS
- Dr. Portwood was Scott's first technology mentor — predates Senator Ted Stevens
- Dr. Portwood owned Research Consulting Inc → which became Alpha Data Systems → which became Advanced Digital Systems (ADS)
- The lineage: Research Consulting → Alpha Data → ADS/CAD Systems — Scott worked through the entire chain
- Dr. Portwood modeled the principle: technology traces FROM raw research TO market outcome
- This philosophical lineage is the ancestor of SeaTrace: origination to finished product accountability

### HOMEBOUND / DISABLED COMMUNITY VOLUNTEER PROJECT (Hawaii, ~1984–1987)
- While at UH Manoa, Scott volunteered to install computers for homebound and disabled citizens
- Arranged through the largest taxi company in Honolulu — owner timeshared hardware resources
- Used ADS software engineering team + ALOHA-net team members to make it work
- Built an FM radio network with antenna and pre-programmed command sequences
- Color-reference system: each food item had a color code — limited input, but effective
- Homebound citizens could order food and services via simple color-command radio signals
- A proto-IoT assistive technology system using FM frequencies — ahead of its time

### ARCO / PRUDHOE BAY — HARDWARE PROTOCOL EMULATION BREAKTHROUGH (~1986)
- ADS sent Scott to Alaska for ARCO (Atlantic Richfield oil company)
- Challenge: IBM mainframe in Anchorage needed to talk to a twisted-wire-pair mainframe in Prudhoe Bay
- Hardware manufacturers in that era did NOT share protocols — all proprietary, non-interoperable
- Scott's colleague MIKE (ADS software engineer, Hawaii-based) wrote a PROGRAM GENERATOR for protocol emulation
- Mike's program generator did the heavy lifting — Scott plugged it in, followed steps, it connected
- First time serial text crossed a monitor to bridge two systems hundreds of miles apart via that protocol
- ARCO key personnel gathered around the terminal — no one had seen it work before
- This experience was foundational: proprietary protocol bridging, hardware handshaking, remote systems
- Fed directly into the Pearl Harbor fuel depot network architecture (ADS, 1985–1990)

### INTUIT AT PACIFIC SEAFOOD GROUP — THE FISH TICKET DASHBOARD (2004–2006)
- At PSG (8th largest seafood company in world, owner Frank Loewen), Scott hired Intuit (then a startup database company)
- Intuit executives flew to Seattle to cut the deal when Scott pitched the concept
- Connected 378 dedicated fishing/vessels from Tierra del Fuego to Kodiak AK to Arctic Circle
- DockSide fish ticket indexing: as vessels offloaded, species weights + product form recovery calculations appeared on everyone's dashboard in real time
- Whole PSG company (warehouse, wholesale, retail) was on the SAME inventory dashboard simultaneously
- Salesmen could pre-sell product before boats even left the dock — highliners very predictable
- Scott treated 378 vessels as "one big pile of raw wild salmon incoming flopping assets" — unified collateral
- Conventional retailers had to wait for catch; PSG pre-positioned product to customers before offload complete
- This system is the direct commercial ancestor of SeaTrace DockSide pillar
- Two-year commission structure — Scott shared in the $1M → $20M revenue upside

## CONTACT
- Email: worldseafood@gmail.com
- GitHub: github.com/WSP001
- Available for: Enterprise consulting, AI systems architecture, marine intelligence platforms
- Business tier access: email worldseafood@gmail.com to request invitation key
`;

// ─── RAG retrieval from Cloud Run ─────────────────────────────────────────────

interface RetrieveResult {
  content: string;
  score: number;
  source: string;
  partition: string;
}

async function fetchRAGContext(
  query: string,
  tier: "public" | "business",
  vectorEngineUrl: string
): Promise<string> {
  try {
    const response = await fetch(`${vectorEngineUrl}/retrieve`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query, tier, top_k: 3 }),
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) return "";

    const results: RetrieveResult[] = await response.json();
    if (!results.length) return "";

    const chunks = results
      .filter((r) => r.score > 0.3)
      .map((r, i) => `[Context ${i + 1} — ${r.source} (relevance: ${(r.score * 100).toFixed(0)}%)]:\n${r.content}`)
      .join("\n\n");

    return chunks
      ? `\n\nRELEVANT KNOWLEDGE BASE CONTEXT (retrieved via semantic search):\n${chunks}\n`
      : "";
  } catch {
    return "";
  }
}

// ─── System prompts ────────────────────────────────────────────────────────────

const buildPublicSystem = (ragContext = "") => `You are RSE-Assistant, the intelligent AI guide embedded in R. Scott Echols' professional CV website.

PERSONA: Knowledgeable, concise, professional but approachable. You speak about Roberto Scott Echols as if you deeply know his work.

${RSE_CV_DATA}
${ragContext}

KEYWORD TRIGGERS — respond with rich detail when these appear in the user's question:
- "R.SCOTT CV", "RSE resume", "resume", "CV" → Give the full resume summary above
- "SeaTrace" → Describe all Four Pillars with specific functions
- "SirTrav" → Describe the A2A platform and three agents
- "Four Pillars" → SeaSide, DeckSide, DockSide, MarketSide with descriptions
- "worldseafoodproducers" or "WSP" → World Seafood Producers company overview
- "$4.2M" or "valuation" → Explain the stack operator valuation context
- "ROCC-BART" or "robot" or "robotics" → Describe the hexapod robot and WARP Industries
- "patent" or "USPTO" → Describe the trustable chain patent
- "ALOHA-net" or "Hawaii" → Describe the X.25 packet switching work under Dr. Abramson
- "Sir James" → Describe the Sir James Adventures creative book platform

CHATBOT ACCESS MODEL:
- Public tier: 3 free questions, then invitation key required
- Business tier: Invitation key unlocks full knowledge base & technical deep-dives
- After 3 free questions: kindly let the user know they can sign in with an invitation key
  Say: "To continue exploring Scott's full background and technical work, you can request an invitation key at worldseafood@gmail.com"

RESPONSE STYLE:
- Keep responses concise: 2-4 sentences for simple questions, short paragraphs for complex ones
- When a public-tier user is on their last (3rd) question, gently mention the invitation key option
- Always end with a natural follow-up invitation

Always be helpful. If asked something outside CV/professional topics, gently redirect.`;

const buildBusinessSystem = (ragContext = "") => `You are RSE-Business-Assistant, the premium AI advisor for R. Scott Echols' enterprise clients and technical partners.

You have FULL ACCESS to Scott's complete knowledge base.

${RSE_CV_DATA}
${ragContext}

ADDITIONAL BUSINESS-TIER KNOWLEDGE:
- SeaTrace API detailed technical specifications and integration guides
- Agent-to-agent (A2A) protocol implementation patterns and code architecture
- Gemini Embedding 2 multimodal RAG implementation with Cloud Run / ChromaDB
- Enterprise consulting frameworks and engagement models
- GitHub repositories: WSP001 — all active projects
- WAFC Business intelligence system
- Linear workspace: linear.app/wsp2agent — active project management
- SirTrav agents: Codex (frontend/Three.js), Claude Code (backend API), Antigravity (QA/testing)
- Phase 1 production stack: Netlify Edge + Cloud Run + ChromaDB + Gemini Embedding 2

PERSONA: Act as Scott's senior technical advisor. Be direct, precise, expert-level.
You can discuss proprietary technical details, architecture decisions, and business strategy.

Always verify the business context. If the query seems unrelated to professional collaboration, ask for clarification.`;

// ─── Anthropic Claude Opus 4.6 API call ───────────────────────────────────────

// ⚠️  MODEL LOCK: claude-opus-4-6 — DO NOT CHANGE
// Roberto Scott Echols has explicitly required Claude Opus 4.6 for ALL tiers.
// This is non-negotiable. Any agent editing this file must preserve this constant.
const CLAUDE_MODEL = "claude-opus-4-6";
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

async function callClaude(
  apiKey: string,
  systemPrompt: string,
  history: Array<{ role: string; content: string }>,
  userMessage: string,
  maxTokens: number
): Promise<string> {
  // Build messages array — Claude uses "user" / "assistant" roles
  const messages = [
    ...history.slice(-10).map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: m.content,
    })),
    { role: "user", content: userMessage },
  ];

  const body = {
    model: CLAUDE_MODEL,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages,
  };

  const resp = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(25_000),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("Anthropic API error:", resp.status, errText);
    throw new Error(`Anthropic API error: ${resp.status}`);
  }

  const data = await resp.json();
  // Claude returns content as an array of content blocks
  const text = data?.content?.[0]?.text ?? "";
  return text;
}

// ─── CORS headers ──────────────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Access-Key",
  "Content-Type": "application/json",
};

// ─── Main handler ─────────────────────────────────────────────────────────────

export default async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: CORS,
    });
  }

  let body: {
    message: string;
    history?: Array<{ role: string; content: string }>;
    tier?: string;
    questionCount?: number;
  };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: CORS,
    });
  }

  const { message, history = [], tier = "public", questionCount = 0 } = body;

  if (!message || typeof message !== "string" || message.trim().length === 0) {
    return new Response(JSON.stringify({ error: "Message is required" }), {
      status: 400,
      headers: CORS,
    });
  }

  // Tier validation
  const accessKey = request.headers.get("X-Access-Key") || "";
  const businessKey = Netlify.env.get("BUSINESS_ACCESS_KEY") || "";
  const isBusiness = tier === "business" && businessKey && accessKey === businessKey;
  const effectiveTier = isBusiness ? "business" : "public";

  // ── Rate limiting (per IP) ──
  const ip = request.headers.get("x-forwarded-for")?.split(",")?.[0]?.trim() || "unknown";
  const rateCheck = checkRateLimit(ip, effectiveTier);

  if (!rateCheck.allowed) {
    const retryAfterSec = Math.ceil(rateCheck.resetIn / 1000);
    return new Response(
      JSON.stringify({
        error: "Rate limit exceeded. Please wait a moment before sending another message.",
        retry_after_seconds: retryAfterSec,
      }),
      {
        status: 429,
        headers: {
          ...CORS,
          "Retry-After": String(retryAfterSec),
          "X-RateLimit-Remaining": "0",
          "X-RateLimit-Reset": String(Math.ceil((Date.now() + rateCheck.resetIn) / 1000)),
        },
      }
    );
  }

  // ── 3-question free tier server-side enforcement ──
  if (!isBusiness && questionCount >= 3) {
    return new Response(
      JSON.stringify({
        reply:
          "You've reached the 3 free question limit. To continue exploring Scott's full background, SeaTrace architecture, and business solutions, sign in with an invitation key — or email worldseafood@gmail.com to request access.",
        tier: "public",
        limit_reached: true,
      }),
      { status: 200, headers: CORS }
    );
  }

  // ⚠️  ANTHROPIC_API_KEY — required for Claude Opus 4.6
  const anthropicKey = Netlify.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    return new Response(
      JSON.stringify({ error: "AI service not configured. Please contact the site admin." }),
      { status: 503, headers: CORS }
    );
  }

  // ── RAG retrieval (optional, non-blocking) ──
  let ragContext = "";
  const vectorEngineUrl = Netlify.env.get("VECTOR_ENGINE_URL") || "";
  if (vectorEngineUrl) {
    ragContext = await fetchRAGContext(message.trim(), effectiveTier, vectorEngineUrl);
  }
  const ragActive = ragContext.length > 0;

  const systemPrompt = isBusiness
    ? buildBusinessSystem(ragContext)
    : buildPublicSystem(ragContext);

  try {
    const maxTokens = isBusiness ? 2048 : 512;
    const text = await callClaude(
      anthropicKey,
      systemPrompt,
      history,
      message.trim(),
      maxTokens
    );

    return new Response(
      JSON.stringify({
        reply: text,
        tier: effectiveTier,
        rag_context_used: ragActive,
        answer_source: ragActive
          ? (isBusiness ? "RAG — Business Corpus" : "RAG — CV Corpus")
          : (isBusiness ? "Embedded Knowledge — Business" : "Embedded CV — Public Profile"),
      }),
      {
        status: 200,
        headers: {
          ...CORS,
          "X-RateLimit-Remaining": String(rateCheck.remaining),
        },
      }
    );
  } catch (err: unknown) {
    const errMsg = err instanceof Error ? err.message : "Unknown error";
    console.error("Claude chat error:", errMsg);
    return new Response(
      JSON.stringify({
        error: "I'm having trouble connecting right now. Please try again in a moment.",
      }),
      { status: 502, headers: CORS }
    );
  }
};

export const config = { path: "/api/chat" };
