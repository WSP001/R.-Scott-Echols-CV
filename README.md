# R. Scott Echols — CV Website with AI Chatbot

**Obsidian Architect** — Portfolio + Intelligent AI Assistant

## Architecture

```
R.-Scott-Echols-CV/
├── index.html                          # Full CV site (single-file, production-ready)
├── netlify.toml                        # Edge Functions routing, security headers, CORS
└── netlify/
    └── edge-functions/
        ├── chat.ts                     # /api/chat — Claude-powered AI assistant (public + business tiers)
        ├── embed.ts                    # /api/embed — Gemini Embedding 2 multimodal RAG endpoint
        └── verify-access.ts           # /api/verify-access — Business tier key validation
```

## AI Chatbot: Two-Tier Access

| Tier | Access | Capabilities |
|------|--------|-------------|
| **Public** | Anyone | CV questions, background, projects, contact info |
| **Business** | Access key required | Full knowledge base, technical blueprints, enterprise details |

### How the tiers work
1. The chatbot defaults to **Public** mode — Claude answers using embedded CV knowledge
2. Entering a **Business Access Key** in the chat gate upgrades to Business mode
3. Business mode routes to Claude with the full knowledge base system prompt + max tokens

## Required Environment Variables (Netlify UI)

Set these in: **Netlify → Site Settings → Environment Variables**

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Your Anthropic Claude API key |
| `GEMINI_API_KEY` | Google AI Studio key (for Gemini Embedding 2) |
| `BUSINESS_ACCESS_KEY` | Secret passphrase for business tier access |

## Gemini Embedding 2 — Multimodal RAG

The `/api/embed` endpoint uses `gemini-embedding-2-preview` to map:
- **Text** → embedding vector
- **Images** (PNG, JPG, WebP) → same embedding space
- **Audio** (MP3, WAV) → same embedding space
- **PDFs** → same embedding space
- **Video** → same embedding space

All modalities share a unified 3072-dimension vector space, enabling cross-modal search.

### Example: embed a document for your knowledge base
```bash
curl -X POST https://your-site.netlify.app/api/embed \
  -H "Content-Type: application/json" \
  -H "X-Access-Key: YOUR_BUSINESS_KEY" \
  -d '{
    "inputs": [
      { "type": "text", "content": "Scott Echols is a marine intelligence expert..." },
      { "type": "image", "content": "BASE64_IMAGE_DATA", "mimeType": "image/png" }
    ]
  }'
```

### Recommended Vector Databases
- **Weaviate** — managed, multimodal-native
- **Qdrant** — fast, self-hostable
- **ChromaDB** — simple local development
- **Vertex AI Vector Search** — Google Cloud native (pairs well with Gemini)

## Deploy to Netlify

### Option 1: Connect GitHub repo (recommended)
1. Push this repo to GitHub
2. Go to [app.netlify.com](https://app.netlify.com) → "Add new site" → "Import an existing project"
3. Connect GitHub → select `WSP001/R.-Scott-Echols-CV`
4. Build settings:
   - **Build command:** `echo 'Static site — no build step'`
   - **Publish directory:** `.`
5. Click **Deploy**
6. Add environment variables (see above)

### Option 2: Netlify CLI
```bash
npm install -g netlify-cli
netlify login
netlify deploy --dir . --prod
```

## Customization

Every `[bracket placeholder]` in `index.html` is **contenteditable** — click directly on any text to edit. The site will remember your edits within the browser session.

For permanent edits, update `index.html` directly and push to GitHub.

---

*Built with [Perplexity Computer](https://www.perplexity.ai/computer)*
