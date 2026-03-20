# R. Scott Echols — CV Source Map & Knowledge Inventory

> **Purpose:** To define the exact source files, their tier assignments, and ingestion priorities for the CV RAG Chatbot. 
> **Rule:** Do not mix Business/SeaTrace logic into Public CV history.

## 🟢 Tier 1: Active Public Sources (The "Who is Scott?" Layer)
These files populate the baseline biography, timeline, skills, and interview Q&A.

- **`SeaTrace - Robert Scott Echols - CV.PDF`**
  - **Type:** PDF
  - **Tier:** Public
  - **Topics:** Professional summary, competencies, WSP founder role, technical stack, core certifications.
  - **Role:** The primary "Trust Layer" anchor.

- **`061722CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2)-1.docx`**
  - **Type:** DOCX
  - **Tier:** Public
  - **Topics:** Deep career history, Aloha-Net / packet-switching, major tech achievements.
  - **Role:** Historical depth and long-form narrative.

- **`CURRICULUM VITAE OF ROBERT SCOTT ECHOLS (2) (1).docx`**
  - **Type:** DOCX
  - **Tier:** Public
  - **Topics:** Fisheries operations, compliance, sustainability, field training.
  - **Role:** Marine domain authority.

## 🔵 Tier 2: Candidate Business Sources (The "How does it work?" Layer)
These files are kept behind the Business Gate. They answer deep architectural and pricing questions.

- **`WSP_SeaTrace_Overview.md`**
  - **Type:** Markdown
  - **Tier:** Business
  - **Topics:** The Four Pillars, API integrations, GFW/SIMP, enterprise data flow.

- **`SeaTrace_Pitch_Deck.pptx` (Planned Phase 6 Multimodal)**
  - **Type:** PPTX/Images
  - **Tier:** Business
  - **Topics:** Visual architecture, investment metrics, value proposition.

## 🔴 Excluded / Needs Review
Do NOT ingest these files into ChromaDB to prevent context collision:
- Duplicate CV variants (`Scott_CV_final_final.docx`)
- Obsolete scratch drafts
- Raw unedited exports from LinkedIn

---

## 🏗️ Folder Structure Standard
All files mapped above must be placed in this structure before running `embed_engine.py`:

```text
knowledge_base/
  public/
    cv/
      master_cv.md
      timeline.md
      certifications.md
    projects/
      sirtrav_public.md
  business/
    seatrace/
      four_pillars.md
```
