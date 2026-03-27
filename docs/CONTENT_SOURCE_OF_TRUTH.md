# Content Source of Truth

This repo now uses a truth-first profile pack for public CV answers and future vector ingest.

## Purpose

The public CV site mixed verified identity with generated or weakly grounded history. The goal of this pack is to keep the public-facing chatbot and fallback UI anchored to files that are safe to trust.

## Trust Order

1. `knowledge_base/public/cv/identity_verified.md`
2. `public/data/identity.json`
3. `public/api/identity.json`
4. `public/data/voice.json`
5. `public/data/hashtags.json`
6. Retrieved vector context from cleaned ingest runs
7. Older narrative briefs only after manual review

## Current Rule

Read before write.

- Public answers must stay inside the verified profile pack unless retrieval returns stronger grounded context.
- If a user asks about early-career details that are not present in the verified pack, the assistant should say the source package is under review instead of filling gaps.
- SirScott, SirTrav, SeaTrace, and Sir James must remain separate identities.

## Identity Boundaries

- `SirScott` = professional CV and consulting identity
- `SirTrav` = personal studio and agent orchestration work
- `SeaTrace` = business and commercial marine traceability work
- `SirJames` = creative and family storytelling work

## Vector Plan

Use these namespaces or partitions when the cleaned ingest is run:

- `cv_verified_public`
- `cv_projects_public`
- `sirtrav_personal`
- `seatrace_business`
- `sirjames_creative`

## Cleanup Status

- `knowledge_base/docs/CHATBOT_KNOWLEDGE_BRIEF.md` is a mixed-trust draft and should not be treated as the sole public profile source.
- The static site fallback copy has been reduced to conservative, source-aware language.
- The chat edge function has been shifted to a verified profile pack instead of the legacy embedded brief.
