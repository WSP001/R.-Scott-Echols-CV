# ANTIGRAVITY QA CHECKLIST
## robertoscottecholscv — CV Chatbot Post-Ingest Verification
### Activation condition: Run ONLY after Claude Code confirms clean ingest + stats

---

## GATE CHECK (before starting QA)

- [ ] `embed_engine.py --from-manifest` completed with no errors
- [ ] `embed_engine.py --stats` shows chunks > 0 across all 4 CV files
- [ ] Proof query returned correct ALOHA-net / WARP Industries content
- [ ] Testing on deployed Netlify URL (NOT localhost — Anthropic IP restriction)

---

## TIER 1 — FACTUAL ACCURACY (must all pass)

### Career Origin
- [ ] Ask: "When did Scott start his career?"
  - PASS: References 1979 education OR 1984 ALOHA-net — NOT 1988 seafood as the start
  - FAIL: Says career started at WSP or in seafood

- [ ] Ask: "What is WARP Industries?"
  - PASS: Advanced Mobile Robotic Producers, co-founded 1987, robotics R&D
  - FAIL: Confuses with WSP, wrong date, or doesn't know it

- [ ] Ask: "Why did Scott found World Seafood Producers?"
  - PASS: To fund WARP Industries robotics R&D
  - FAIL: Says it was his primary passion or lifelong dream (missing the funding origin)

### ALOHA-net
- [ ] Ask: "What is Scott's connection to the internet?"
  - PASS: Names ALOHA-net, Dr. Norman Abramson, UH Manoa, 1984–1987, X.25 packet switching
  - FAIL: Doesn't know, vague, or misattributes

### Patent
- [ ] Ask: "Does Scott have a patent?"
  - PASS: USPTO App. No. 16/936,852, filed July 23, 2020, Perkin Coie Seattle
  - FAIL: Wrong number, wrong date, or "I don't know"

### Pearl Harbor
- [ ] Ask: "Tell me about Scott's work at Pearl Harbor"
  - PASS: U.S. Navy fuel depot, inventory control systems, broadband packet switching, proprietary protocol, still running today
  - FAIL: Doesn't know or confuses with other work

### Alaska
- [ ] Ask: "What did Scott accomplish in Alaska?"
  - PASS: Senator Ted Stevens, $107MM endowment, WARP $2.2MM grant, 21 seasons salmon, DIPAC hatchery contract
  - FAIL: Generic or missing key names/numbers

---

## TIER 2 — SEATRACE PLATFORM

- [ ] Ask: "What are the Four Pillars of SeaTrace?"
  - PASS: SeaSide (HOLD), DeckSide (RECORD), DockSide (STORE), MarketSide (EXCHANGE)
  - FAIL: Wrong names, wrong order, missing any pillar

- [ ] Ask: "What is the SeaTrace valuation?"
  - PASS: $4.2M USD Stack Operator Valuation
  - FAIL: Wrong number or doesn't know

- [ ] Ask: "What does the patent have to do with SeaTrace?"
  - PASS: Connects Pearl Harbor protocol → USPTO patent → SeaTrace chain architecture
  - FAIL: Says they're unrelated or doesn't know

---

## TIER 3 — CHUNK INTEGRITY

- [ ] Ask a question only answerable from Master Career Timeline (1984–1987 ALOHA-net content)
  - PASS: Returns accurate answer with source attribution
  - FAIL: Returns generic answer or "I don't have that information"

- [ ] Ask a question only in the 2023 CV (specific Alaska dollar figures)
  - PASS: Accurate retrieval from correct chunk
  - FAIL: Hallucinated or empty

- [ ] Ask an off-topic question (e.g., "What is the capital of France?")
  - PASS: Politely redirects — "I'm Scott's career assistant, I don't have that in my knowledge base"
  - FAIL: Answers off-topic questions as if it's a general assistant

---

## TIER 4 — CONVERSATIONAL MEMORY (two-turn test)

- [ ] Turn 1: "Tell me about WARP Industries"
  Turn 2: "Who funded it?"
  - PASS: Correctly references Senator Ted Stevens + Alaska S&T Foundation from context
  - FAIL: Loses context, asks user to repeat, or gives wrong answer

- [ ] Turn 1: "What is Scott's patent number?"
  Turn 2: "When was it filed?"
  - PASS: Recalls 16/936,852 context → answers July 23, 2020
  - FAIL: Can't connect turn 2 to turn 1

---

## TIER 5 — ANSWER SOURCE LABEL

- [ ] Verify chatbot cites source partition when answering
  - PASS: Shows `[Source: cv_personal]` or `[Source: cv_seatrace]` on answers
  - FAIL: No source attribution

---

## LIMIT BEHAVIOR

- [ ] Ask: "What is Scott's home address?"
  - PASS: Declines or says general location only (Cathlamet, WA)
  - FAIL: Outputs specific personal address

- [ ] Ask something completely outside the CV corpus
  - PASS: "I don't have that in Scott's knowledge base"
  - FAIL: Hallucinates an answer

---

## FALLBACK HONESTY

- [ ] Ask an obscure question Scott himself would need to look up
  - PASS: "I don't have that detail — Scott can answer directly"
  - FAIL: Makes something up

---

## QA SCORING

| Tier | Tests | Pass | Fail | Notes |
|------|-------|------|------|-------|
| Tier 1 — Factual Accuracy | 6 | | | |
| Tier 2 — SeaTrace Platform | 3 | | | |
| Tier 3 — Chunk Integrity | 3 | | | |
| Tier 4 — Memory | 2 | | | |
| Tier 5 — Source Labels | 1 | | | |
| Limit Behavior | 2 | | | |
| Fallback Honesty | 1 | | | |
| **TOTAL** | **18** | | | |

**GREEN LIGHT threshold: 16/18 pass (89%)**
**HOLD threshold: any Tier 1 failure = hold regardless of total score**

---

## ANTIGRAVITY DISPATCH TO TEAM ON COMPLETION

```
QA COMPLETE — [DATE]
Score: __/18
Tier 1 Factual: PASS / FAIL
Tier 2 SeaTrace: PASS / FAIL
Memory: PASS / FAIL
Verdict: GREEN LIGHT / HOLD

[Paste any failed questions and actual chatbot responses here]
```

---

*Prepared by Claude (Cowork mode) — March 21, 2026*
*Activation: only after Claude Code confirms clean ingest + Netlify deploy*
