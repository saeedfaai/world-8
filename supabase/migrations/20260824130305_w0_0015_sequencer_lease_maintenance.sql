-- World 8 W0 sequencer lease maintenance
-- Purpose: keep the canonical commit path usable without bypassing lease/fencing.
-- Active same-holder renewal preserves the fencing token. Expired reacquisition
-- atomically rotates the token so stale executors remain fenced out.

BEGIN;

CREATE OR REPLACE FUNCTION world8_maintain_sequencer_lease(
    p_world_id TEXT,
    p_actor_id TEXT,
    p_expected_fencing_token BIGINT,
    p_lease_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
    world_id TEXT,
    holder_id TEXT,
    fencing_token BIGINT,
    lease_expires_at TIMESTAMPTZ,
    rotated BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_lease sequencer_leases%ROWTYPE;
    v_now TIMESTAMPTZ;
    v_new_token BIGINT;
    v_rotated BOOLEAN := FALSE;
BEGIN
    IF coalesce(p_world_id,'')='' OR coalesce(p_actor_id,'')='' THEN
        RAISE EXCEPTION 'world_id and actor_id are required' USING ERRCODE='22023';
    END IF;
    IF session_user <> p_actor_id THEN
        RAISE EXCEPTION 'AUTHENTICATED_ACTOR_MISMATCH session_user=% actor=%',session_user,p_actor_id
            USING ERRCODE='42501';
    END IF;
    IF NOT pg_has_role(session_user,'world8_sequencer_executor','MEMBER') THEN
        RAISE EXCEPTION 'SEQUENCER_LEASE_ACTOR_NOT_AUTHORIZED actor=%',session_user
            USING ERRCODE='42501';
    END IF;
    IF p_expected_fencing_token IS NULL OR p_expected_fencing_token <= 0 THEN
        RAISE EXCEPTION 'expected_fencing_token must be positive' USING ERRCODE='22023';
    END IF;
    IF p_lease_seconds IS NULL OR p_lease_seconds < 1 OR p_lease_seconds > 86400 THEN
        RAISE EXCEPTION 'lease_seconds must be 1..86400' USING ERRCODE='22023';
    END IF;

    SELECT sl.* INTO v_lease
    FROM sequencer_leases AS sl
    WHERE sl.world_id=p_world_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SEQUENCER_LEASE_NOT_FOUND world=%',p_world_id USING ERRCODE='55000';
    END IF;
    IF v_lease.fencing_token <> p_expected_fencing_token THEN
        RAISE EXCEPTION 'STALE_EXPECTED_FENCING_TOKEN world=% expected_current=% supplied=%',
            p_world_id,v_lease.fencing_token,p_expected_fencing_token
            USING ERRCODE='40001';
    END IF;

    v_now := clock_timestamp();

    IF v_lease.lease_expires_at > v_now THEN
        IF v_lease.holder_id <> p_actor_id THEN
            RAISE EXCEPTION 'ACTIVE_SEQUENCER_LEASE_HELD_BY_OTHER world=% holder=% actor=%',
                p_world_id,v_lease.holder_id,p_actor_id
                USING ERRCODE='42501';
        END IF;
        v_new_token := v_lease.fencing_token;
    ELSE
        IF v_lease.fencing_token = 9223372036854775807 THEN
            RAISE EXCEPTION 'FENCING_TOKEN_EXHAUSTED world=%',p_world_id USING ERRCODE='54000';
        END IF;
        v_new_token := v_lease.fencing_token + 1;
        v_rotated := TRUE;
    END IF;

    UPDATE sequencer_leases AS sl
       SET holder_id=p_actor_id,
           fencing_token=v_new_token,
           lease_expires_at=v_now + make_interval(secs => p_lease_seconds),
           updated_at=v_now
     WHERE sl.world_id=p_world_id;

    RETURN QUERY
    SELECT sl.world_id,sl.holder_id,sl.fencing_token,sl.lease_expires_at,v_rotated
    FROM sequencer_leases AS sl
    WHERE sl.world_id=p_world_id;
END;
$$;

ALTER FUNCTION world8_maintain_sequencer_lease(TEXT,TEXT,BIGINT,INTEGER)
OWNER TO world8_runtime_owner;

COMMENT ON FUNCTION world8_maintain_sequencer_lease(TEXT,TEXT,BIGINT,INTEGER)
IS 'Governed sequencer lease maintenance: same-holder active renewal keeps token; expired reacquisition rotates token atomically under expected-token CAS.';

REVOKE ALL ON FUNCTION world8_maintain_sequencer_lease(TEXT,TEXT,BIGINT,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION world8_maintain_sequencer_lease(TEXT,TEXT,BIGINT,INTEGER)
TO world8_sequencer_executor;

COMMIT;