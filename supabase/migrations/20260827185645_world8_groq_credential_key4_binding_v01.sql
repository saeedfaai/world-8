-- World 8 Groq credential binding correction v0.1
-- The runtime secret exists under GROQ_API_KEY4. Only the opaque envref is stored here.

select public.world8_provider_credential_binding_register_v1(
  'binding-groq-envref-key4-v01',
  'adapter-groq-external-v01',
  'envref:GROQ_API_KEY4',
  jsonb_build_object(
    'failover_candidate',true,
    'supersedes','binding-groq-envref-v01',
    'reason','runtime_env_name_discovered'
  ),
  'human-root'
);

-- Verification remains runtime evidence: replay does not synthesize VERIFIED state.
-- A live credential probe must pass before readiness_v2 can select this binding.