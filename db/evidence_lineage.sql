-- ============================================================================
-- evidence_lineage.sql — U.S. Seafood Evidence-Continuity Lineage
-- Target: Netlify Database (managed Postgres)
-- Status: DESIGN ARTIFACT — reviewable DDL, not yet wired to an ORM.
--         See plans/HANDOFF_EVIDENCE_LINEAGE_ROUND.md for the wiring assignment.
--
-- PURPOSE
--   Model the "public map compounded with a private graph":
--     * PRIVATE GRAPH — the full lineage of authorities, requirements, legacy WSP
--       artifacts, and the classified claims that connect them.
--     * PUBLIC MAP    — a projection of that graph containing ONLY rows whose
--       disclosure_class is PUBLIC. Everything else is structurally excluded,
--       not merely filtered in application code.
--
-- TWO RULES FROM THE ASSIGNMENT ARE ENFORCED IN THE SCHEMA ITSELF, so that a
-- careless INSERT cannot produce an indefensible public claim:
--
--   1. ANACHRONISM RULE. "Do not claim that a historical WSP design complied
--      with FSMA 204 before FSMA 204 existed." A DIRECT_REGULATORY_MATCH is
--      rejected unless the artifact post-dates the authority it matches.
--      (see: crosswalk_claim.ck_no_anachronistic_compliance)
--
--   2. BOUNDARY RULE. A claim may only be projected publicly if the claim, the
--      authority requirement, AND the legacy artifact are all PUBLIC.
--      (see: v_public_map)
--
-- FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library.
-- ============================================================================

-- ─── Enumerations ───────────────────────────────────────────────────────────

-- The four classifications required by the research assignment.
CREATE TYPE match_class AS ENUM (
  'DIRECT_REGULATORY_MATCH', -- the authority literally requires this thing
  'FUNCTIONAL_ANALOGUE',     -- same function, no regulatory identity claimed
  'SEATRACE_EXTENSION',      -- SeaTrace goes beyond what is required
  'NO_SUPPORTED_MATCH'       -- examined and rejected. Recorded, never deleted.
);

-- Disclosure posture. Drives the public/private split end to end.
CREATE TYPE disclosure_class AS ENUM (
  'PUBLIC',            -- safe to publish, cite, and put in campaign language
  'COMPLIANCE_ONLY',   -- flows to a regulator, not to the public
  'PRIVATE_BUSINESS',  -- commercial information; never leaves the private graph
  'RESTRICTED'         -- statutorily confidential (e.g. MSA-submitted information)
);

-- Verification state of a research finding.
CREATE TYPE evidence_state AS ENUM (
  'READY_FOR_CROSSWALK',
  'HOLD_SOURCE_GAP',
  'HOLD_LEGAL_INTERPRETATION',
  'HOLD_BOUNDARY_RISK'
);

-- Temporal language permitted when describing a relationship. Prevents
-- "complied with" from being used where only "anticipated" is supportable.
CREATE TYPE temporal_claim AS ENUM (
  'COMPLIED_WITH',              -- only valid when artifact post-dates authority
  'ANTICIPATED',
  'FUNCTIONALLY_ANALOGOUS',
  'INFORMS_CURRENT_IMPLEMENTATION'
);

-- ─── Primary sources ────────────────────────────────────────────────────────
-- Every substantive row must trace to one of these. No citation, no claim.

CREATE TABLE source_citation (
  id               bigserial PRIMARY KEY,
  short_key        text NOT NULL UNIQUE,      -- e.g. 'MSA-402b', 'FSMA204-1.1455'
  title            text NOT NULL,
  publisher        text NOT NULL,             -- NOAA Fisheries, FDA, GPO, CBP...
  citation         text NOT NULL,             -- 16 U.S.C. 1881a / 21 CFR 1.1455
  url              text,
  published_on     date,
  retrieved_on     date NOT NULL,
  is_primary       boolean NOT NULL DEFAULT true,  -- false = secondary/commentary
  verbatim_excerpt text,                       -- the sentence the claim rests on
  CONSTRAINT ck_primary_needs_locator
    CHECK (NOT is_primary OR citation <> '')
);

COMMENT ON TABLE source_citation IS
  'Primary-source bibliography. is_primary=false marks commentary, which may '
  'contextualise but may never be the sole support for a DIRECT_REGULATORY_MATCH.';

-- ─── Authorities: statute, regulation, guidance ─────────────────────────────

CREATE TABLE authority (
  id                bigserial PRIMARY KEY,
  short_key         text NOT NULL UNIQUE,     -- 'MSA', 'SIMP', 'FSMA204'
  name              text NOT NULL,
  instrument_type   text NOT NULL
    CHECK (instrument_type IN ('STATUTE','REGULATION','GUIDANCE','SYSTEM','ORDER')),
  agency            text,                     -- NOAA/NMFS, FDA, CBP
  enacted_on        date,                     -- when the authority came into being
  effective_on      date,                     -- when obligations attach
  enforcement_on    date,                     -- e.g. FSMA 204 compliance date
  is_consumer_facing boolean NOT NULL DEFAULT false,
  notes             text
);

COMMENT ON COLUMN authority.is_consumer_facing IS
  'Set true ONLY where the authority itself creates a public-facing disclosure. '
  'NOAA states SIMP is not a consumer-facing labeling program; SIMP must be false. '
  'This column is the guard against marketing language that implies otherwise.';

-- Atomic obligations extracted from an authority. One row = one requirement.
CREATE TABLE authority_requirement (
  id                 bigserial PRIMARY KEY,
  authority_id       bigint NOT NULL REFERENCES authority(id) ON DELETE RESTRICT,
  clause             text NOT NULL,           -- '21 CFR 1.1330(a)'
  requirement        text NOT NULL,           -- what must be done
  data_elements      text[] NOT NULL DEFAULT '{}',  -- KDEs / fields required
  who_must_hold      text,                    -- who keeps the record
  who_may_receive    text,                    -- who it may be disclosed to
  disclosure         disclosure_class NOT NULL,
  retention_period   interval,
  correction_duty    text,                    -- supersession / amendment duty
  forward_trace      boolean NOT NULL DEFAULT false,
  reverse_trace      boolean NOT NULL DEFAULT false,
  crosses_org_boundary boolean NOT NULL DEFAULT false,
  source_id          bigint NOT NULL REFERENCES source_citation(id),
  UNIQUE (authority_id, clause, requirement)
);

-- ─── Legacy WSP / SeaTrace corpus ───────────────────────────────────────────

CREATE TABLE legacy_artifact (
  id             bigserial PRIMARY KEY,
  short_key      text NOT NULL UNIQUE,        -- 'harvest_ticket', 'scale_evidence'
  name           text NOT NULL,
  description    text NOT NULL,
  origin_year    integer,                     -- earliest defensible evidence of it
  evidence_of_date text,                      -- HOW origin_year is established
  disclosure     disclosure_class NOT NULL,
  repo_or_doc    text,                        -- where it is attested
  CONSTRAINT ck_origin_year_sane
    CHECK (origin_year IS NULL OR (origin_year BETWEEN 1970 AND 2100))
);

COMMENT ON COLUMN legacy_artifact.evidence_of_date IS
  'A dated artifact claim is only as good as its proof. Undated artifacts '
  '(origin_year IS NULL) can never support a DIRECT_REGULATORY_MATCH.';

-- ─── The crosswalk: the classified claim ────────────────────────────────────

CREATE TABLE crosswalk_claim (
  id              bigserial PRIMARY KEY,
  artifact_id     bigint NOT NULL REFERENCES legacy_artifact(id) ON DELETE RESTRICT,
  requirement_id  bigint NOT NULL REFERENCES authority_requirement(id) ON DELETE RESTRICT,
  classification  match_class NOT NULL,
  temporal        temporal_claim NOT NULL,
  rationale       text NOT NULL,
  disclosure      disclosure_class NOT NULL,
  state           evidence_state NOT NULL DEFAULT 'HOLD_SOURCE_GAP',
  reviewed_by     text,
  reviewed_on     date,
  -- Denormalised dates: required so the anachronism CHECK can be enforced at
  -- row level. Kept in sync by trg_sync_claim_dates below.
  artifact_year   integer,
  authority_year  integer,

  UNIQUE (artifact_id, requirement_id),

  -- RULE 1 — ANACHRONISM. A direct compliance claim requires that the artifact
  -- actually post-dates the authority, and that both dates are known.
  CONSTRAINT ck_no_anachronistic_compliance CHECK (
    classification <> 'DIRECT_REGULATORY_MATCH'
    OR (artifact_year IS NOT NULL
        AND authority_year IS NOT NULL
        AND artifact_year >= authority_year)
  ),

  -- "COMPLIED_WITH" is likewise only available to a genuine direct match.
  CONSTRAINT ck_complied_with_requires_direct CHECK (
    temporal <> 'COMPLIED_WITH' OR classification = 'DIRECT_REGULATORY_MATCH'
  )
);

-- Keep the denormalised years honest.
CREATE OR REPLACE FUNCTION sync_claim_dates() RETURNS trigger AS $$
BEGIN
  SELECT la.origin_year INTO NEW.artifact_year
    FROM legacy_artifact la WHERE la.id = NEW.artifact_id;

  SELECT EXTRACT(YEAR FROM COALESCE(a.effective_on, a.enacted_on))::int
    INTO NEW.authority_year
    FROM authority_requirement ar
    JOIN authority a ON a.id = ar.authority_id
   WHERE ar.id = NEW.requirement_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_claim_dates
  BEFORE INSERT OR UPDATE ON crosswalk_claim
  FOR EACH ROW EXECUTE FUNCTION sync_claim_dates();

-- Every claim needs at least one supporting citation.
CREATE TABLE claim_support (
  claim_id  bigint NOT NULL REFERENCES crosswalk_claim(id) ON DELETE CASCADE,
  source_id bigint NOT NULL REFERENCES source_citation(id) ON DELETE RESTRICT,
  PRIMARY KEY (claim_id, source_id)
);

-- ─── The private graph: lineage edges ───────────────────────────────────────
-- Predecessor / backlink relationships between artifacts and authorities.
-- This is the "graph" half. It is never exposed wholesale.

CREATE TABLE lineage_edge (
  id           bigserial PRIMARY KEY,
  from_kind    text NOT NULL CHECK (from_kind IN ('AUTHORITY','ARTIFACT','CLAIM')),
  from_id      bigint NOT NULL,
  to_kind      text NOT NULL CHECK (to_kind   IN ('AUTHORITY','ARTIFACT','CLAIM')),
  to_id        bigint NOT NULL,
  relation     text NOT NULL
    CHECK (relation IN ('PREDECESSOR_OF','SUPERSEDES','IMPLEMENTS',
                        'INFORMS','CONFLICTS_WITH','CORRECTS')),
  disclosure   disclosure_class NOT NULL,
  note         text,
  UNIQUE (from_kind, from_id, to_kind, to_id, relation)
);

CREATE INDEX idx_lineage_from ON lineage_edge (from_kind, from_id);
CREATE INDEX idx_lineage_to   ON lineage_edge (to_kind, to_id);

-- ─── Conflicts and gaps register ────────────────────────────────────────────

CREATE TABLE conflict_gap (
  id          bigserial PRIMARY KEY,
  kind        text NOT NULL CHECK (kind IN ('CONFLICT','GAP','AMBIGUITY')),
  summary     text NOT NULL,
  detail      text NOT NULL,
  blocks_state evidence_state,
  opened_on   date NOT NULL DEFAULT CURRENT_DATE,
  resolved_on date,
  disclosure  disclosure_class NOT NULL DEFAULT 'COMPLIANCE_ONLY'
);

-- ─── RULE 2 — THE PUBLIC MAP ────────────────────────────────────────────────
-- The ONLY sanctioned public surface. A claim reaches the public map only when
-- the claim, its requirement, and its artifact are ALL public, it has cleared
-- review, and it is supported by at least one primary source.

CREATE VIEW v_public_map AS
SELECT
  c.id                AS claim_id,
  la.short_key        AS artifact_key,
  la.name             AS artifact_name,
  a.short_key         AS authority_key,
  a.name              AS authority_name,
  ar.clause           AS clause,
  c.classification,
  c.temporal,
  c.rationale,
  a.is_consumer_facing
FROM crosswalk_claim c
JOIN legacy_artifact       la ON la.id = c.artifact_id
JOIN authority_requirement ar ON ar.id = c.requirement_id
JOIN authority             a  ON a.id  = ar.authority_id
WHERE c.disclosure  = 'PUBLIC'
  AND ar.disclosure = 'PUBLIC'
  AND la.disclosure = 'PUBLIC'
  AND c.state       = 'READY_FOR_CROSSWALK'
  AND EXISTS (
    SELECT 1 FROM claim_support cs
    JOIN source_citation s ON s.id = cs.source_id
    WHERE cs.claim_id = c.id AND s.is_primary
  );

COMMENT ON VIEW v_public_map IS
  'Public projection. Campaign and chatbot language may cite ONLY these rows. '
  'Anything absent from this view is, by construction, not yet public-safe.';

-- Public-safe lineage edges only, for rendering the public map graph.
CREATE VIEW v_public_lineage AS
  SELECT * FROM lineage_edge WHERE disclosure = 'PUBLIC';

-- Operator view: what is blocking publication right now.
CREATE VIEW v_publication_blockers AS
SELECT c.id AS claim_id, la.short_key AS artifact_key, a.short_key AS authority_key,
       c.state,
       CASE
         WHEN c.state <> 'READY_FOR_CROSSWALK' THEN 'state: ' || c.state::text
         WHEN c.disclosure  <> 'PUBLIC' THEN 'claim disclosure: '     || c.disclosure::text
         WHEN ar.disclosure <> 'PUBLIC' THEN 'requirement disclosure: '|| ar.disclosure::text
         WHEN la.disclosure <> 'PUBLIC' THEN 'artifact disclosure: '  || la.disclosure::text
         ELSE 'missing primary source'
       END AS blocker
FROM crosswalk_claim c
JOIN legacy_artifact       la ON la.id = c.artifact_id
JOIN authority_requirement ar ON ar.id = c.requirement_id
JOIN authority             a  ON a.id  = ar.authority_id
WHERE c.id NOT IN (SELECT claim_id FROM v_public_map);
