BEGIN;

GRANT world8_effect_authorizer TO postgres;
GRANT world8_effect_executor TO postgres;

REVOKE ALL ON TABLE w2_external_effect_authorizations FROM anon, authenticated;

REVOKE ALL ON FUNCTION world8_authorize_task_external_effect(
    TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,JSONB
) FROM anon, authenticated;
REVOKE ALL ON FUNCTION world8_plan_task_external_effect(
    TEXT,TEXT,TEXT,TEXT,JSONB,TEXT,BIGINT,JSONB
) FROM anon, authenticated;
REVOKE ALL ON FUNCTION world8_begin_external_effect_attempt(
    TEXT,TEXT,TEXT,INTEGER,JSONB
) FROM anon, authenticated;
REVOKE ALL ON FUNCTION world8_finish_external_effect_attempt(
    TEXT,TEXT,TEXT,TEXT,TEXT,JSONB
) FROM anon, authenticated;
REVOKE ALL ON FUNCTION world8_external_effect_readiness(TEXT)
FROM anon, authenticated;

REVOKE ALL ON FUNCTION world8_prevent_effect_authorization_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION world8_guard_outbox_status_transition() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION world8_guard_effect_attempt_update() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION world8_prevent_effect_attempt_removal() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION world8_prevent_effect_receipt_mutation() FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON TABLES FROM anon, authenticated;

COMMIT;