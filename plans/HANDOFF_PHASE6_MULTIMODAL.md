# MASTER AGENT HANDOFF: PHASE 6 — Multimodal RAG (Gemini Embedding 2)

> **Target Agent:** Claude Code (Backend Specialist)
> **Context:** Phase 6 Vector Engine Upgrade
> **Operating Rule:** Read this document to understand how we are bridging text, image, and PDF embeddings into a unified ChromaDB space.

The Google AI Studio team just dropped the Multimodal `gemini-embedding-2-preview` model. This completely shifts the CV chatbot's capabilities. We are no longer limited to chunking text. We can now natively ingest your SeaTrace PowerPoint slides (as images) and architectural diagrams straight into the vector space.

---

## 🧠 THE ARCHITECTURE: MULTIMODAL INGESTION

### 1. The Current State (`scripts/embed_engine.py`)
Currently, `embed_engine.py` reads Markdown files, chunks the text, and calls `genai.embed_content()` passing only text strings.

### 2. The New State (Phase 6)
We must upgrade the ingestion loop to detect file types and pass `types.Part.from_bytes()` payloads to Gemini alongside text.

**The Implementation Blueprint:**
When `embed_engine.py` loops through `knowledge_base/business/` or `knowledge_base/public/`, it must:
1.  **Check Extension:** Is this a `.txt` / `.md` OR is it an `.png` / `.jpg` / `.pdf`?
2.  **Read Bytes:** If image/PDF, read the raw bytes.
3.  **Multimodal Payload:** Construct the array payload required by Gemini Embedding 2.

```python
# Example logic for Claude Code to inject into embed_engine.py

from google import genai
from google.genai import types
import mimetypes

client = genai.Client()

def embed_multimodal_file(file_path, contextual_text=""):
    """
    Embeds an image, pdf, or text file alongside contextual metadata.
    """
    mime_type, _ = mimetypes.guess_type(file_path)
    
    with open(file_path, "rb") as f:
        file_bytes = f.read()

    # We embed the raw file bytes AND a contextual string (like "SeaTrace Slide 4")
    # This maps the image into the exact same vector space as the text queries.
    result = client.models.embed_content(
        model="gemini-embedding-2-preview",
        contents=[
            contextual_text,
            types.Part.from_bytes(
                data=file_bytes,
                mime_type=mime_type,
            ),
        ],
    )
    return result.embeddings
```

### 3. The Retrieval Logic (Cross-Modal Search)
Because Gemini Embedding 2 uses a single unified space, **the retrieval logic (`api_server.py`) does not need to change.** 

When the user asks *"Show me the SeaTrace architecture diagram"* in the chat, Claude Code's edge function sends that text to Cloud Run. Cloud Run converts that text to an embedding, searches ChromaDB, and will naturally find the closest vector — which will be the Image embedding we just created.

The only difference: `api_server.py` must return the *URL or filepath* of the matched image so the Claude Opus 4.6 generation model can reference it or Codex can render it in the UI.

---

## 🛑 LANE BOUNDARY CHECK

*   **Claude Code:** You own the `scripts/embed_engine.py` upgrade. Your goal is to make the ingestion script capable of parsing `.png` and `.pdf` files.
*   **Antigravity:** You will need to add a test prompt to `test-phase5-rag-prompts.json` specifically asking for visual information (e.g., "What does the WSP logo look like?") to verify cross-modal retrieval.
*   **Codex:** Hold position. Once Claude Code proves the backend can return image paths from ChromaDB, you will upgrade the chat UI to render inline images.
