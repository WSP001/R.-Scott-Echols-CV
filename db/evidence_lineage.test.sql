-- ============================================================================
-- evidence_lineage.test.sql — regression suite for the anachronism rule and
-- parent-side revalidation (Sourcery #3 / #4 on PR #3).
--
-- Run against a FRESH database that has evidence_lineage.sql applied:
--   psql -v ON_ERROR_STOP=0 -f db/evidence_lineage.test.sql
-- Every block prints "T-x PASS" or "T-x FAIL". Expect 8 PASS lines.
-- ============================================================================

\set QUIET on
\pset format unaligned
\pset tuples_only on

-- Fixtures -------------------------------------------------------------------
INSERT INTO source_citation (short_key, title, publisher, citation, retrieved_on, is_primary)
VALUES ('SRC-1', 'Fixture source', 'GPO', '21 CFR 1.1330', CURRENT_DATE, true);

INSERT INTO authority (short_key, name, instrument_type, enacted_on, effective_on)
VALUES ('AUTH-1', 'Fixture authority', 'REGULATION', '2028-01-01', '2028-07-20');

INSERT INTO authority_requirement (authority_id, clause, requirement, disclosure, source_id)
VALUES ((SELECT id FROM authority WHERE short_key='AUTH-1'), 'c.1', 'keep a record', 'PUBLIC',
        (SELECT id FROM source_citation WHERE short_key='SRC-1'));

-- artifact A: same year as authority, PRE-dates it (Jan vs Jul)
INSERT INTO legacy_artifact (short_key, name, description, origin_year, origin_date, disclosure)
VALUES ('ART-PRE', 'pre', 'd', 2028, '2028-01-15', 'PUBLIC');
-- artifact B: same year, POST-dates it (Sep vs Jul)
INSERT INTO legacy_artifact (short_key, name, description, origin_year, origin_date, disclosure)
VALUES ('ART-POST', 'post', 'd', 2028, '2028-09-15', 'PUBLIC');
-- artifact C: same year, year-only evidence
INSERT INTO legacy_artifact (short_key, name, description, origin_year, disclosure)
VALUES ('ART-YEARONLY', 'yearonly', 'd', 2028, 'PUBLIC');
-- artifact D: later year, year-only evidence
INSERT INTO legacy_artifact (short_key, name, description, origin_year, disclosure)
VALUES ('ART-LATER', 'later', 'd', 2030, 'PUBLIC');

CREATE OR REPLACE FUNCTION _claim(p_art text, p_class match_class, p_temporal temporal_claim)
RETURNS void AS $$
BEGIN
  INSERT INTO crosswalk_claim (artifact_id, requirement_id, classification, temporal, rationale, disclosure)
  VALUES ((SELECT id FROM legacy_artifact WHERE short_key = p_art),
          (SELECT id FROM authority_requirement WHERE clause = 'c.1'),
          p_class, p_temporal, 'fixture', 'PUBLIC');
END; $$ LANGUAGE plpgsql;

-- T-A: same year, artifact pre-dates authority -> REJECT ----------------------
DO $$ BEGIN
  PERFORM _claim('ART-PRE', 'DIRECT_REGULATORY_MATCH', 'COMPLIED_WITH');
  RAISE NOTICE 'T-A FAIL (accepted anachronistic same-year claim)';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'T-A PASS';
END $$;

-- T-B: same year, artifact post-dates authority -> ACCEPT ---------------------
DO $$ BEGIN
  PERFORM _claim('ART-POST', 'DIRECT_REGULATORY_MATCH', 'COMPLIED_WITH');
  RAISE NOTICE 'T-B PASS';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'T-B FAIL (%)', SQLERRM;
END $$;

-- T-C: same year, year-only evidence -> REJECT --------------------------------
DO $$ BEGIN
  PERFORM _claim('ART-YEARONLY', 'DIRECT_REGULATORY_MATCH', 'COMPLIED_WITH');
  RAISE NOTICE 'T-C FAIL (accepted same-year claim without day precision)';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'T-C PASS';
END $$;

-- T-D: later year, year-only evidence -> ACCEPT -------------------------------
DO $$ BEGIN
  PERFORM _claim('ART-LATER', 'DIRECT_REGULATORY_MATCH', 'COMPLIED_WITH');
  RAISE NOTICE 'T-D PASS';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'T-D FAIL (%)', SQLERRM;
END $$;

-- T-E: correct origin_year backwards on a live claim -> ABORT -----------------
DO $$ BEGIN
  UPDATE legacy_artifact SET origin_year = 1999, origin_date = '1999-06-01' WHERE short_key = 'ART-POST';
  RAISE NOTICE 'T-E FAIL (parent correction left indefensible claim valid)';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'T-E PASS';
END $$;

-- T-F: move authority.effective_on forward past the artifact -> ABORT ---------
DO $$ BEGIN
  UPDATE authority SET effective_on = '2028-12-01' WHERE short_key = 'AUTH-1';
  RAISE NOTICE 'T-F FAIL (authority correction left indefensible claim valid)';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'T-F PASS';
END $$;

-- T-G: benign parent edit keeps all claims defensible -> SUCCEED + resync -----
DO $$
DECLARE n int;
BEGIN
  UPDATE authority SET effective_on = '2028-07-01' WHERE short_key = 'AUTH-1';
  SELECT count(*) INTO n FROM crosswalk_claim WHERE authority_date <> '2028-07-01';
  IF n = 0 THEN RAISE NOTICE 'T-G PASS';
  ELSE RAISE NOTICE 'T-G FAIL (% claim(s) not resynced)', n; END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'T-G FAIL (%)', SQLERRM;
END $$;

-- T-H: reclassify first, then correct the date (legal escape hatch) -> SUCCEED
DO $$
DECLARE n int;
BEGIN
  UPDATE crosswalk_claim SET classification = 'FUNCTIONAL_ANALOGUE', temporal = 'FUNCTIONALLY_ANALOGOUS'
   WHERE artifact_id = (SELECT id FROM legacy_artifact WHERE short_key = 'ART-POST');
  UPDATE legacy_artifact SET origin_year = 1999, origin_date = '1999-06-01' WHERE short_key = 'ART-POST';
  SELECT count(*) INTO n FROM v_stale_claims;
  IF n = 0 THEN RAISE NOTICE 'T-H PASS';
  ELSE RAISE NOTICE 'T-H FAIL (v_stale_claims has % row(s))', n; END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'T-H FAIL (%)', SQLERRM;
END $$;

DROP FUNCTION _claim(text, match_class, temporal_claim);
