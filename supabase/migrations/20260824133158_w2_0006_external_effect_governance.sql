BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='world8_effect_authorizer') THEN
        CREATE ROLE world8_effect_authorizer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='world8_effect_executor') THEN
        CREATE ROLE world8_effect_executor NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='effect_svc') THEN
        CREATE ROLE effect_svc NOLOGIN NOINHERIT;
    END IF;
END;
$$;

GRANT world8_effect_authorizer TO human_root_admin;
GRANT world8_effect_executor TO effect_svc;
GRANT USAGE ON SCHEMA public TO world8_effect_authorizer,world8_effect_executor,effect_svc;

CREATE TABLE IF NOT EXISTS w2_external_effect_authorizations (
    authorization_id TEXT PRIMARY KEY,
    world_id TEXT NOT NULL REFERENCES worlds(world_id),
    task_id TEXT NOT NULL REFERENCES company_task_specs(task_id),
    authorizer_id TEXT NOT NULL,
    decision TEXT NOT NULL CHECK (decision IN ('APPROVE','DENY')),
    effect_type TEXT NOT NULL CHECK (length(trim(effect_type)) > 0),
    destination_fingerprint TEXT NOT NULL CHECK (destination_fingerprint ~ '^[0-9a-f]{64}$'),
    effect_payload_hash TEXT NOT NULL CHECK (effect_payload_hash ~ '^[0-9a-f]{64}$'),
    evidence JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence)='object'),
    authorized_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_w2_effect_authorizations_task
    ON w2_external_effect_authorizations(world_id,task_id,authorized_at DESC);

CREATE OR REPLACE FUNCTION world8_prevent_effect_authorization_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path=pg_catalog,public
AS $$
BEGIN
    RAISE EXCEPTION 'w2_external_effect_authorizations is append-only';
END;
$$;

DROP TRIGGER IF EXISTS trg_w2_effect_authorizations_no_update_delete ON w2_external_effect_authorizations;
CREATE TRIGGER trg_w2_effect_authorizations_no_update_delete
BEFORE UPDATE OR DELETE ON w2_external_effect_authorizations
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_authorization_mutation();

DROP TRIGGER IF EXISTS trg_w2_effect_authorizations_no_truncate ON w2_external_effect_authorizations;
CREATE TRIGGER trg_w2_effect_authorizations_no_truncate
BEFORE TRUNCATE ON w2_external_effect_authorizations
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_authorization_mutation();

CREATE OR REPLACE FUNCTION world8_authorize_task_external_effect(
    p_world_id TEXT,
    p_authorization_id TEXT,
    p_actor_id TEXT,
    p_task_id TEXT,
    p_decision TEXT,
    p_effect_type TEXT,
    p_destination_fingerprint TEXT,
    p_effect_payload JSONB,
    p_evidence JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    authorization_id TEXT,
    decision TEXT,
    effect_payload_hash TEXT,
    replayed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,extensions
AS $$
DECLARE
    v_payload_hash TEXT;
    v_existing w2_external_effect_authorizations%ROWTYPE;
BEGIN
    IF session_user <> p_actor_id OR NOT pg_has_role(session_user,'world8_effect_authorizer','MEMBER') THEN
        RAISE EXCEPTION 'W2_EFFECT_AUTHORIZER_NOT_AUTHORIZED actor=%',session_user USING ERRCODE='42501';
    END IF;
    IF coalesce(p_authorization_id,'')='' OR coalesce(p_task_id,'')='' OR length(trim(coalesce(p_effect_type,'')))=0 THEN
        RAISE EXCEPTION 'authorization_id, task_id and effect_type are required' USING ERRCODE='22023';
    END IF;
    IF p_decision NOT IN ('APPROVE','DENY') THEN
        RAISE EXCEPTION 'decision must be APPROVE or DENY' USING ERRCODE='22023';
    END IF;
    IF p_destination_fingerprint !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'destination_fingerprint must be lowercase sha256 hex' USING ERRCODE='22023';
    END IF;
    IF p_effect_payload IS NULL OR jsonb_typeof(p_effect_payload) <> 'object' THEN
        RAISE EXCEPTION 'effect_payload must be a JSON object' USING ERRCODE='22023';
    END IF;
    IF p_evidence IS NULL OR jsonb_typeof(p_evidence) <> 'object' THEN
        RAISE EXCEPTION 'evidence must be a JSON object' USING ERRCODE='22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM company_task_specs s
        JOIN company_task_state st USING(task_id)
        WHERE s.world_id=p_world_id AND s.task_id=p_task_id AND st.status='COMPLETED'
    ) THEN
        RAISE EXCEPTION 'external effect authorization requires a completed task' USING ERRCODE='55000';
    END IF;

    v_payload_hash := encode(digest(convert_to(p_effect_payload::text,'UTF8'),'sha256'),'hex');

    SELECT * INTO v_existing
    FROM w2_external_effect_authorizations a
    WHERE a.authorization_id=p_authorization_id;

    IF FOUND THEN
        IF v_existing.world_id<>p_world_id OR v_existing.task_id<>p_task_id OR
           v_existing.authorizer_id<>p_actor_id OR v_existing.decision<>p_decision OR
           v_existing.effect_type<>p_effect_type OR
           v_existing.destination_fingerprint<>p_destination_fingerprint OR
           v_existing.effect_payload_hash<>v_payload_hash OR v_existing.evidence<>p_evidence THEN
            RAISE EXCEPTION 'W2_EFFECT_AUTHORIZATION_COLLISION authorization_id=%',p_authorization_id USING ERRCODE='23505';
        END IF;
        RETURN QUERY SELECT v_existing.authorization_id,v_existing.decision,v_existing.effect_payload_hash,TRUE;
        RETURN;
    END IF;

    INSERT INTO w2_external_effect_authorizations(
        authorization_id,world_id,task_id,authorizer_id,decision,effect_type,
        destination_fingerprint,effect_payload_hash,evidence
    ) VALUES (
        p_authorization_id,p_world_id,p_task_id,p_actor_id,p_decision,p_effect_type,
        p_destination_fingerprint,v_payload_hash,p_evidence
    );

    RETURN QUERY SELECT p_authorization_id,p_decision,v_payload_hash,FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION world8_plan_task_external_effect(
    p_world_id TEXT,
    p_actor_id TEXT,
    p_event_id TEXT,
    p_authorization_id TEXT,
    p_effect_payload JSONB,
    p_expected_head_hash TEXT,
    p_fencing_token BIGINT,
    p_provenance JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    event_id TEXT,
    state_version BIGINT,
    head_hash TEXT,
    replayed BOOLEAN,
    outbox_id TEXT,
    outbox_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,extensions
AS $$
DECLARE
    v_auth w2_external_effect_authorizations%ROWTYPE;
    v_payload_hash TEXT;
    v_outbox_id TEXT;
    v_business_effect_key TEXT;
    v_event_payload JSONB;
    v_planned_effects JSONB;
    v_semantic_hash TEXT;
    v_event_id TEXT;
    v_state_version BIGINT;
    v_head_hash TEXT;
    v_replayed BOOLEAN;
    v_status TEXT;
BEGIN
    IF session_user<>p_actor_id OR NOT pg_has_role(session_user,'world8_sequencer_executor','MEMBER') THEN
        RAISE EXCEPTION 'W2_EFFECT_PLANNER_NOT_SEQUENCER actor=%',session_user USING ERRCODE='42501';
    END IF;
    IF p_effect_payload IS NULL OR jsonb_typeof(p_effect_payload)<>'object' THEN
        RAISE EXCEPTION 'effect_payload must be a JSON object' USING ERRCODE='22023';
    END IF;

    SELECT * INTO v_auth
    FROM w2_external_effect_authorizations a
    WHERE a.authorization_id=p_authorization_id AND a.world_id=p_world_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'external effect authorization not found' USING ERRCODE='23503';
    END IF;
    IF v_auth.decision<>'APPROVE' THEN
        RAISE EXCEPTION 'external effect authorization is not APPROVE' USING ERRCODE='42501';
    END IF;

    v_payload_hash := encode(digest(convert_to(p_effect_payload::text,'UTF8'),'sha256'),'hex');
    IF v_payload_hash<>v_auth.effect_payload_hash THEN
        RAISE EXCEPTION 'AUTHORIZED_EFFECT_PAYLOAD_MISMATCH authorization_id=%',p_authorization_id USING ERRCODE='42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM company_task_specs s
        JOIN company_task_state st USING(task_id)
        WHERE s.world_id=p_world_id AND s.task_id=v_auth.task_id AND st.status='COMPLETED'
    ) THEN
        RAISE EXCEPTION 'authorized task is not completed' USING ERRCODE='55000';
    END IF;

    v_outbox_id := 'outbox:'||p_authorization_id;
    v_business_effect_key := 'w2-task-effect:'||p_authorization_id;
    v_event_payload := jsonb_build_object(
        'task_id',v_auth.task_id,
        'authorization_id',p_authorization_id,
        'effect_type',v_auth.effect_type,
        'destination_fingerprint',v_auth.destination_fingerprint,
        'effect_payload_hash',v_auth.effect_payload_hash,
        'outbox_id',v_outbox_id
    );
    v_planned_effects := jsonb_build_array(jsonb_build_object(
        'outbox_id',v_outbox_id,
        'business_effect_key',v_business_effect_key,
        'effect_type',v_auth.effect_type,
        'payload',jsonb_build_object(
            'task_id',v_auth.task_id,
            'authorization_id',p_authorization_id,
            'destination_fingerprint',v_auth.destination_fingerprint,
            'effect_payload',p_effect_payload
        )
    ));
    v_semantic_hash := encode(digest(convert_to(v_event_payload::text,'UTF8'),'sha256'),'hex');

    SELECT c.event_id,c.state_version,c.head_hash,c.replayed
    INTO v_event_id,v_state_version,v_head_hash,v_replayed
    FROM world8_commit_event(
        p_world_id,p_actor_id,p_event_id,v_auth.task_id,'COMPANY_TASK_EXTERNAL_EFFECT_PLANNED',
        'w2-effect-plan:'||p_authorization_id,v_semantic_hash,p_expected_head_hash,p_fencing_token,
        v_event_payload,p_provenance||jsonb_build_object('source','w2-external-effect-governance'),v_planned_effects
    ) c;

    SELECT o.status INTO v_status FROM outbox o WHERE o.outbox_id=v_outbox_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'planned outbox row missing after canonical commit' USING ERRCODE='55000';
    END IF;

    RETURN QUERY SELECT v_event_id,v_state_version,v_head_hash,v_replayed,v_outbox_id,v_status;
END;
$$;

CREATE OR REPLACE FUNCTION world8_guard_outbox_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SET search_path=pg_catalog,public
AS $$
BEGIN
    IF NEW.status=OLD.status THEN RETURN NEW; END IF;
    IF (OLD.status='PENDING' AND NEW.status IN ('IN_PROGRESS','CANCELLED')) OR
       (OLD.status='IN_PROGRESS' AND NEW.status IN ('SUCCEEDED','FAILED','CANCELLED')) OR
       (OLD.status='FAILED' AND NEW.status='IN_PROGRESS') THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'INVALID_OUTBOX_STATUS_TRANSITION % -> %',OLD.status,NEW.status USING ERRCODE='23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_outbox_status_transition ON outbox;
CREATE TRIGGER trg_outbox_status_transition
BEFORE UPDATE OF status ON outbox
FOR EACH ROW EXECUTE FUNCTION world8_guard_outbox_status_transition();

CREATE OR REPLACE FUNCTION world8_guard_effect_attempt_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path=pg_catalog,public
AS $$
BEGIN
    IF NEW.attempt_id<>OLD.attempt_id OR NEW.outbox_id<>OLD.outbox_id OR NEW.attempt_no<>OLD.attempt_no OR NEW.started_at<>OLD.started_at THEN
        RAISE EXCEPTION 'effect attempt identity/specification is immutable' USING ERRCODE='23514';
    END IF;
    IF OLD.status='STARTED' AND NEW.status IN ('SUCCEEDED','FAILED') AND NEW.completed_at IS NOT NULL THEN
        RETURN NEW;
    END IF;
    IF NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'invalid effect attempt transition' USING ERRCODE='23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_effect_attempt_update_guard ON effect_attempts;
CREATE TRIGGER trg_effect_attempt_update_guard
BEFORE UPDATE ON effect_attempts
FOR EACH ROW EXECUTE FUNCTION world8_guard_effect_attempt_update();

CREATE OR REPLACE FUNCTION world8_prevent_effect_attempt_removal()
RETURNS trigger
LANGUAGE plpgsql
SET search_path=pg_catalog,public
AS $$
BEGIN
    RAISE EXCEPTION 'effect_attempts are append-preserved';
END;
$$;

DROP TRIGGER IF EXISTS trg_effect_attempt_no_delete ON effect_attempts;
CREATE TRIGGER trg_effect_attempt_no_delete
BEFORE DELETE ON effect_attempts
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_attempt_removal();

DROP TRIGGER IF EXISTS trg_effect_attempt_no_truncate ON effect_attempts;
CREATE TRIGGER trg_effect_attempt_no_truncate
BEFORE TRUNCATE ON effect_attempts
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_attempt_removal();

CREATE OR REPLACE FUNCTION world8_prevent_effect_receipt_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path=pg_catalog,public
AS $$
BEGIN
    RAISE EXCEPTION 'effect_receipts are immutable';
END;
$$;

DROP TRIGGER IF EXISTS trg_effect_receipts_no_update_delete ON effect_receipts;
CREATE TRIGGER trg_effect_receipts_no_update_delete
BEFORE UPDATE OR DELETE ON effect_receipts
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_receipt_mutation();

DROP TRIGGER IF EXISTS trg_effect_receipts_no_truncate ON effect_receipts;
CREATE TRIGGER trg_effect_receipts_no_truncate
BEFORE TRUNCATE ON effect_receipts
FOR EACH STATEMENT EXECUTE FUNCTION world8_prevent_effect_receipt_mutation();

CREATE OR REPLACE FUNCTION world8_begin_external_effect_attempt(
    p_actor_id TEXT,
    p_outbox_id TEXT,
    p_attempt_id TEXT,
    p_attempt_no INTEGER,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    attempt_id TEXT,
    outbox_id TEXT,
    attempt_no INTEGER,
    status TEXT,
    replayed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public
AS $$
DECLARE
    v_outbox outbox%ROWTYPE;
    v_existing effect_attempts%ROWTYPE;
BEGIN
    IF session_user<>p_actor_id OR NOT pg_has_role(session_user,'world8_effect_executor','MEMBER') THEN
        RAISE EXCEPTION 'W2_EFFECT_EXECUTOR_NOT_AUTHORIZED actor=%',session_user USING ERRCODE='42501';
    END IF;
    IF coalesce(p_attempt_id,'')='' OR p_attempt_no IS NULL OR p_attempt_no<=0 THEN
        RAISE EXCEPTION 'attempt_id and positive attempt_no are required' USING ERRCODE='22023';
    END IF;
    IF p_metadata IS NULL OR jsonb_typeof(p_metadata)<>'object' THEN
        RAISE EXCEPTION 'metadata must be a JSON object' USING ERRCODE='22023';
    END IF;

    SELECT * INTO v_outbox FROM outbox o WHERE o.outbox_id=p_outbox_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown outbox %',p_outbox_id USING ERRCODE='23503'; END IF;
    IF v_outbox.status='SUCCEEDED' OR v_outbox.status='CANCELLED' THEN
        RAISE EXCEPTION 'outbox is not executable status=%',v_outbox.status USING ERRCODE='55000';
    END IF;
    IF v_outbox.status='IN_PROGRESS' AND NOT EXISTS (
        SELECT 1 FROM effect_attempts ea WHERE ea.outbox_id=p_outbox_id AND ea.status='STARTED'
    ) THEN
        RAISE EXCEPTION 'outbox IN_PROGRESS without active attempt' USING ERRCODE='55000';
    END IF;

    SELECT * INTO v_existing FROM effect_attempts ea WHERE ea.attempt_id=p_attempt_id;
    IF FOUND THEN
        IF v_existing.outbox_id<>p_outbox_id OR v_existing.attempt_no<>p_attempt_no OR
           v_existing.status<>'STARTED' OR v_existing.response_metadata<>p_metadata THEN
            RAISE EXCEPTION 'EFFECT_ATTEMPT_ID_COLLISION attempt_id=%',p_attempt_id USING ERRCODE='23505';
        END IF;
        RETURN QUERY SELECT v_existing.attempt_id,v_existing.outbox_id,v_existing.attempt_no,v_existing.status,TRUE;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM effect_attempts ea WHERE ea.outbox_id=p_outbox_id AND ea.attempt_no=p_attempt_no) THEN
        RAISE EXCEPTION 'EFFECT_ATTEMPT_NUMBER_COLLISION outbox=% attempt_no=%',p_outbox_id,p_attempt_no USING ERRCODE='23505';
    END IF;
    IF EXISTS (SELECT 1 FROM effect_attempts ea WHERE ea.outbox_id=p_outbox_id AND ea.status='STARTED') THEN
        RAISE EXCEPTION 'another attempt is already STARTED for outbox=%',p_outbox_id USING ERRCODE='55000';
    END IF;

    INSERT INTO effect_attempts(attempt_id,outbox_id,attempt_no,status,response_metadata)
    VALUES(p_attempt_id,p_outbox_id,p_attempt_no,'STARTED',p_metadata);
    UPDATE outbox SET status='IN_PROGRESS',updated_at=clock_timestamp() WHERE outbox_id=p_outbox_id;

    RETURN QUERY SELECT p_attempt_id,p_outbox_id,p_attempt_no,'STARTED'::TEXT,FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION world8_finish_external_effect_attempt(
    p_actor_id TEXT,
    p_outbox_id TEXT,
    p_attempt_id TEXT,
    p_outcome TEXT,
    p_provider_effect_id TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    attempt_id TEXT,
    outbox_id TEXT,
    outcome TEXT,
    receipt_id TEXT,
    receipt_hash TEXT,
    replayed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,extensions
AS $$
DECLARE
    v_outbox outbox%ROWTYPE;
    v_attempt effect_attempts%ROWTYPE;
    v_receipt effect_receipts%ROWTYPE;
    v_receipt_id TEXT;
    v_receipt_hash TEXT;
    v_receipt_doc JSONB;
BEGIN
    IF session_user<>p_actor_id OR NOT pg_has_role(session_user,'world8_effect_executor','MEMBER') THEN
        RAISE EXCEPTION 'W2_EFFECT_EXECUTOR_NOT_AUTHORIZED actor=%',session_user USING ERRCODE='42501';
    END IF;
    IF p_outcome NOT IN ('SUCCEEDED','FAILED') THEN
        RAISE EXCEPTION 'outcome must be SUCCEEDED or FAILED' USING ERRCODE='22023';
    END IF;
    IF p_metadata IS NULL OR jsonb_typeof(p_metadata)<>'object' THEN
        RAISE EXCEPTION 'metadata must be a JSON object' USING ERRCODE='22023';
    END IF;
    IF p_outcome='SUCCEEDED' AND length(trim(coalesce(p_provider_effect_id,'')))=0 THEN
        RAISE EXCEPTION 'provider_effect_id is required for SUCCEEDED outcome' USING ERRCODE='22023';
    END IF;

    SELECT * INTO v_outbox FROM outbox o WHERE o.outbox_id=p_outbox_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown outbox %',p_outbox_id USING ERRCODE='23503'; END IF;
    SELECT * INTO v_attempt FROM effect_attempts ea WHERE ea.attempt_id=p_attempt_id AND ea.outbox_id=p_outbox_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown effect attempt %',p_attempt_id USING ERRCODE='23503'; END IF;

    IF v_attempt.status IN ('SUCCEEDED','FAILED') THEN
        IF v_attempt.status<>p_outcome OR v_attempt.response_metadata<>p_metadata THEN
            RAISE EXCEPTION 'EFFECT_ATTEMPT_FINISH_COLLISION attempt_id=%',p_attempt_id USING ERRCODE='23505';
        END IF;
        IF p_outcome='SUCCEEDED' THEN
            SELECT * INTO v_receipt FROM effect_receipts er WHERE er.outbox_id=p_outbox_id;
            IF NOT FOUND OR v_receipt.provider_effect_id<>p_provider_effect_id THEN
                RAISE EXCEPTION 'EFFECT_RECEIPT_REPLAY_MISMATCH outbox=%',p_outbox_id USING ERRCODE='23505';
            END IF;
            RETURN QUERY SELECT p_attempt_id,p_outbox_id,p_outcome,v_receipt.receipt_id,v_receipt.receipt_hash,TRUE;
        ELSE
            RETURN QUERY SELECT p_attempt_id,p_outbox_id,p_outcome,NULL::TEXT,NULL::TEXT,TRUE;
        END IF;
        RETURN;
    END IF;

    IF v_attempt.status<>'STARTED' OR v_outbox.status<>'IN_PROGRESS' THEN
        RAISE EXCEPTION 'effect attempt/outbox not in finishable state' USING ERRCODE='55000';
    END IF;

    UPDATE effect_attempts
       SET status=p_outcome,response_metadata=p_metadata,completed_at=clock_timestamp()
     WHERE attempt_id=p_attempt_id;

    IF p_outcome='FAILED' THEN
        UPDATE outbox SET status='FAILED',updated_at=clock_timestamp() WHERE outbox_id=p_outbox_id;
        RETURN QUERY SELECT p_attempt_id,p_outbox_id,p_outcome,NULL::TEXT,NULL::TEXT,FALSE;
        RETURN;
    END IF;

    v_receipt_id := 'receipt:'||p_outbox_id;
    v_receipt_doc := jsonb_build_object(
        'outbox_id',p_outbox_id,
        'provider_effect_id',p_provider_effect_id,
        'metadata',p_metadata
    );
    v_receipt_hash := encode(digest(convert_to(v_receipt_doc::text,'UTF8'),'sha256'),'hex');

    INSERT INTO effect_receipts(receipt_id,outbox_id,provider_effect_id,receipt_hash,metadata)
    VALUES(v_receipt_id,p_outbox_id,p_provider_effect_id,v_receipt_hash,p_metadata);
    UPDATE outbox SET status='SUCCEEDED',updated_at=clock_timestamp() WHERE outbox_id=p_outbox_id;

    RETURN QUERY SELECT p_attempt_id,p_outbox_id,p_outcome,v_receipt_id,v_receipt_hash,FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION world8_external_effect_readiness(p_authorization_id TEXT)
RETURNS TABLE(
    authorization_ok BOOLEAN,
    planned BOOLEAN,
    outbox_status TEXT,
    receipt_ok BOOLEAN,
    ready BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path=pg_catalog,public
AS $$
WITH a AS (
    SELECT * FROM w2_external_effect_authorizations WHERE authorization_id=p_authorization_id
), o AS (
    SELECT ob.*
    FROM a JOIN outbox ob ON ob.outbox_id='outbox:'||a.authorization_id
), r AS (
    SELECT er.* FROM o JOIN effect_receipts er ON er.outbox_id=o.outbox_id
)
SELECT
    EXISTS(SELECT 1 FROM a WHERE decision='APPROVE') AS authorization_ok,
    EXISTS(SELECT 1 FROM o) AS planned,
    (SELECT status FROM o) AS outbox_status,
    EXISTS(SELECT 1 FROM r) AS receipt_ok,
    EXISTS(SELECT 1 FROM a WHERE decision='APPROVE')
      AND EXISTS(SELECT 1 FROM o WHERE status='SUCCEEDED')
      AND EXISTS(SELECT 1 FROM r) AS ready;
$$;

ALTER TABLE w2_external_effect_authorizations OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_prevent_effect_authorization_mutation() OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_authorize_task_external_effect(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,JSONB) OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_plan_task_external_effect(TEXT,TEXT,TEXT,TEXT,JSONB,TEXT,BIGINT,JSONB) OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_guard_outbox_status_transition() OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_guard_effect_attempt_update() OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_prevent_effect_attempt_removal() OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_prevent_effect_receipt_mutation() OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_begin_external_effect_attempt(TEXT,TEXT,TEXT,INTEGER,JSONB) OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_finish_external_effect_attempt(TEXT,TEXT,TEXT,TEXT,TEXT,JSONB) OWNER TO world8_runtime_owner;
ALTER FUNCTION world8_external_effect_readiness(TEXT) OWNER TO world8_runtime_owner;

ALTER TABLE w2_external_effect_authorizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY world8_runtime_owner_all_w2_effect_authorizations
ON w2_external_effect_authorizations TO world8_runtime_owner USING(true) WITH CHECK(true);

REVOKE ALL ON TABLE w2_external_effect_authorizations FROM PUBLIC,world8_effect_authorizer,world8_effect_executor,effect_svc;
REVOKE ALL ON TABLE outbox,effect_attempts,effect_receipts FROM world8_effect_authorizer,world8_effect_executor,effect_svc;

REVOKE ALL ON FUNCTION world8_authorize_task_external_effect(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION world8_plan_task_external_effect(TEXT,TEXT,TEXT,TEXT,JSONB,TEXT,BIGINT,JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION world8_begin_external_effect_attempt(TEXT,TEXT,TEXT,INTEGER,JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION world8_finish_external_effect_attempt(TEXT,TEXT,TEXT,TEXT,TEXT,JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION world8_external_effect_readiness(TEXT) FROM PUBLIC;

GRANT SELECT,INSERT ON w2_external_effect_authorizations TO world8_runtime_owner;
GRANT SELECT,UPDATE ON outbox,effect_attempts TO world8_runtime_owner;
GRANT SELECT,INSERT ON effect_attempts,effect_receipts TO world8_runtime_owner;

GRANT EXECUTE ON FUNCTION world8_authorize_task_external_effect(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,JSONB) TO world8_effect_authorizer;
GRANT EXECUTE ON FUNCTION world8_plan_task_external_effect(TEXT,TEXT,TEXT,TEXT,JSONB,TEXT,BIGINT,JSONB) TO world8_sequencer_executor;
GRANT EXECUTE ON FUNCTION world8_begin_external_effect_attempt(TEXT,TEXT,TEXT,INTEGER,JSONB) TO world8_effect_executor;
GRANT EXECUTE ON FUNCTION world8_finish_external_effect_attempt(TEXT,TEXT,TEXT,TEXT,TEXT,JSONB) TO world8_effect_executor;
GRANT EXECUTE ON FUNCTION world8_external_effect_readiness(TEXT) TO world8_effect_authorizer,world8_effect_executor,world8_sequencer_executor,world8_verifier_executor;

COMMIT;