# SeaTrace — Four Pillars Architecture

SeaTrace is a fisheries traceability platform built by R. Scott Echols / WorldSeafoodProducers.com. It is designed to bring trusted, machine-level transparency to wild fisheries supply chains from harvest to market.

## The Four Pillars of SeaTrace

**Pillar 1 — Accurate Capture**
Electronic monitoring and reporting at the point of harvest. Vessel-level catch data is recorded at sea using SIMP-compliant forms, AIS/VMS transponder activity, and dockside offload verification. Goal: trusted harvest records that cannot be manipulated after the fact.

**Pillar 2 — Chain of Custody**
Immutable document trail from vessel to processor to importer. Each transfer of custody is logged with verifiable weight, species, gear type, and flag state. Designed to meet NOAA SIMP, EU IUU, and GFW compliance standards.

**Pillar 3 — Market Transparency**
Consumer-facing traceability certificates and QR-code product labeling that links retail seafood back to the original harvest event. Retailers and importers can verify sourcing claims without relying solely on paperwork.

**Pillar 4 — Co-Management Data Share**
Bi-directional data sharing between fishing communities, processors, regulators, and conservation partners. Supports ecosystem-based fisheries management (EBFM) by giving all stakeholders access to the same verified dataset — ending the information asymmetry that enables IUU fishing.

## Context
- Founder: R. Scott Echols, WorldSeafoodProducers.com
- Architecture: FastAPI backend, ChromaDB/pgvector RAG, Gemini Embedding 2
- Mission: FOR THE COMMONS GOOD — trusted seafood supply chains at machine scale
- Related: WAFC, GGSE, GFW compliance, NOAA SIMP framework
