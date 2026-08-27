import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const WORKER_ID = "world8-provider-worker-canary-v01";
const TRANSPORT_ID = "transport-supabase-world8-provider-canary-v01";
const OPENAI_ENV = "OPENAI_API_KEY";
const OPENAI_CREDENTIAL_REF = "envref:OPENAI_API_KEY";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });
}
function safeToken(v: unknown) { return typeof v === "string" && /^[0-9a-f]{32,64}$/i.test(v.trim()) ? v.trim() : ""; }
function safeId(v: unknown, prefix: string) { const s = typeof v === "string" ? v.trim() : ""; return s.startsWith(prefix) && /^[A-Za-z0-9._:-]+$/.test(s) ? s : ""; }

async function rpc(name: string, payload: Record<string, unknown>) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) return { ok: false, status: 503, payload: { error: "WORKER_RUNTIME_NOT_CONFIGURED" } };
  const res = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${serviceRole}`, apikey: serviceRole }, body: JSON.stringify(payload) });
  const text = await res.text(); let parsed: unknown;
  try { parsed = text ? JSON.parse(text) : null; } catch { parsed = { upstream_body_unparsed: true }; }
  return { ok: res.ok, status: res.status, payload: parsed };
}
function extractText(payload: any): string {
  if (typeof payload?.output_text === "string" && payload.output_text.trim()) return payload.output_text.trim();
  const parts: string[] = [];
  if (Array.isArray(payload?.output)) for (const item of payload.output) if (Array.isArray(item?.content)) for (const c of item.content) if (c?.type === "output_text" && typeof c?.text === "string") parts.push(c.text);
  return parts.join("\n").trim();
}
async function failRequest(requestId: string, claimToken: string, errorCode: string, evidence: string[], metadata: Record<string, unknown>) {
  return await rpc("world8_provider_execution_fail_v1", { p_request_id: requestId, p_claim_token: claimToken, p_error_code: errorCode, p_evidence_refs: evidence, p_metadata: { ...metadata, raw_secret_present: false, private_reasoning_present: false } });
}

Deno.serve(async (req: Request) => {
  if (req.method === "GET") return json({ schema: "WORLD8_PROVIDER_WORKER_HEALTH/1.2", worker_id: WORKER_ID, transport_id: TRANSPORT_ID, state: "ACTIVE", challenge_attestation: true, credential_probe_enabled: true, credential_env_present: Boolean(Deno.env.get(OPENAI_ENV)), provider_task_execution_enabled: true, governed_queued_request_only: true, raw_secret_returned: false });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  let body: Record<string, unknown>; try { body = await req.json(); } catch { return json({ error: "INVALID_JSON" }, 400); }
  const action = typeof body.action === "string" ? body.action : "worker_challenge";

  if (action === "model_probe") {
    const key = Deno.env.get(OPENAI_ENV) ?? "";
    if (!key) return json({ schema: "WORLD8_PROVIDER_MODEL_PROBE/1.0", credential_present: false, candidates: {}, raw_secret_returned: false }, 503);
    try {
      const r = await fetch("https://api.openai.com/v1/models", { headers: { authorization: `Bearer ${key}` } });
      const p = r.ok ? await r.json() : null;
      const ids = new Set(Array.isArray(p?.data) ? p.data.map((x: any) => String(x?.id ?? "")) : []);
      const candidates = ["gpt-5-mini","gpt-4.1-mini","gpt-4o-mini"];
      return json({ schema: "WORLD8_PROVIDER_MODEL_PROBE/1.0", provider: "OpenAI", provider_http_status: r.status, credential_present: true, candidates: Object.fromEntries(candidates.map(x => [x, ids.has(x)])), raw_secret_returned: false });
    } catch { return json({ schema: "WORLD8_PROVIDER_MODEL_PROBE/1.0", provider: "OpenAI", provider_http_status: 0, credential_present: true, candidates: {}, raw_secret_returned: false }, 502); }
  }

  if (action === "worker_challenge") {
    const challengeId = safeId(body.challenge_id, "worker-challenge-"); const challengeToken = safeToken(body.challenge_token);
    if (!challengeId || !challengeToken) return json({ error: "INVALID_CHALLENGE_ENVELOPE" }, 400);
    const att = await rpc("world8_provider_worker_challenge_attest_v1", { p_challenge_id: challengeId, p_challenge_token: challengeToken, p_evidence_refs: [`edge:${WORKER_ID}`,`transport:${TRANSPORT_ID}`,`challenge:${challengeId}`], p_metadata: { worker_kind: "SUPABASE_EDGE", worker_version: "0.3.0", provider_invoked: false, raw_secret_present: false, private_reasoning_present: false } });
    if (!att.ok) return json({ schema: "WORLD8_PROVIDER_WORKER_ATTESTATION_PROXY/1.2", state: "REJECTED", upstream_status: att.status, challenge_token_returned: false, provider_invoked: false }, 400);
    return json({ schema: "WORLD8_PROVIDER_WORKER_ATTESTATION_PROXY/1.2", state: "ATTESTED", worker_id: WORKER_ID, transport_id: TRANSPORT_ID, result: att.payload, challenge_token_returned: false, provider_invoked: false, raw_secret_returned: false });
  }

  if (action === "credential_probe") {
    const challengeId = safeId(body.challenge_id, "credential-challenge-"); const probeToken = safeToken(body.probe_token); const credentialRef = typeof body.credential_ref === "string" ? body.credential_ref.trim() : "";
    if (!challengeId || !probeToken || credentialRef !== OPENAI_CREDENTIAL_REF) return json({ error: "INVALID_CREDENTIAL_PROBE_ENVELOPE" }, 400);
    const key = Deno.env.get(OPENAI_ENV) ?? ""; let probeResult: "PASS"|"FAIL" = "FAIL"; let providerStatus = 0; let providerInvoked = false;
    if (key) { providerInvoked = true; try { const providerRes = await fetch("https://api.openai.com/v1/models", { headers: { authorization: `Bearer ${key}` } }); providerStatus = providerRes.status; probeResult = providerRes.ok ? "PASS" : "FAIL"; try { await providerRes.body?.cancel(); } catch {} } catch {} }
    const att = await rpc("world8_provider_credential_probe_attest_v1", { p_challenge_id: challengeId, p_probe_token: probeToken, p_probe_result: probeResult, p_evidence_refs: [`edge:${WORKER_ID}`,`transport:${TRANSPORT_ID}`,`challenge:${challengeId}`,`provider:openai:auth-probe:status-${providerStatus}`], p_metadata: { worker_kind: "SUPABASE_EDGE", worker_version: "0.3.0", credential_ref: OPENAI_CREDENTIAL_REF, credential_present: Boolean(key), provider_invoked: providerInvoked, provider_http_status: providerStatus, provider_response_body_stored: false, raw_secret_present: false, private_reasoning_present: false } });
    if (!att.ok) return json({ schema: "WORLD8_PROVIDER_CREDENTIAL_PROBE_PROXY/1.1", state: "REJECTED", upstream_status: att.status, probe_token_returned: false, raw_secret_returned: false }, 400);
    return json({ schema: "WORLD8_PROVIDER_CREDENTIAL_PROBE_PROXY/1.1", state: probeResult === "PASS" ? "VERIFIED" : "FAILED", worker_id: WORKER_ID, transport_id: TRANSPORT_ID, provider: "OpenAI", provider_http_status: providerStatus, provider_invoked: providerInvoked, result: att.payload, probe_token_returned: false, raw_secret_returned: false });
  }

  if (action === "execute_request") {
    const requestId = safeId(body.request_id, "provider-request-");
    if (!requestId) return json({ error: "INVALID_REQUEST_ID" }, 400);
    const claim = await rpc("world8_provider_execution_worker_claim_v1", { p_request_id: requestId, p_transport_id: TRANSPORT_ID, p_claim_ttl_seconds: 300 });
    if (!claim.ok) return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "CLAIM_REJECTED", request_id: requestId, upstream_status: claim.status, raw_secret_returned: false }, 409);
    const cp: any = claim.payload ?? {}; const claimToken = safeToken(cp.claim_token); const dispatch = cp.dispatch ?? {};
    if (!claimToken) return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "INVALID_CLAIM", request_id: requestId, raw_secret_returned: false }, 500);
    const key = Deno.env.get(OPENAI_ENV) ?? "";
    if (!key) { await failRequest(requestId, claimToken, "OPENAI_CREDENTIAL_NOT_PRESENT", [`edge:${WORKER_ID}`], { provider_invoked: false }); return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "FAILED", error_code: "OPENAI_CREDENTIAL_NOT_PRESENT", request_id: requestId, raw_secret_returned: false }, 502); }
    const modelId = String(dispatch.model_id ?? "").trim(); const taskSummary = String(dispatch.task_summary ?? "").trim();
    if (!modelId || !taskSummary) { await failRequest(requestId, claimToken, "INVALID_DISPATCH_ENVELOPE", [`edge:${WORKER_ID}`], { provider_invoked: false }); return json({ state: "FAILED", error_code: "INVALID_DISPATCH_ENVELOPE", request_id: requestId, raw_secret_returned: false }, 500); }
    let providerRes: Response; let providerPayload: any; let providerRequestId = "";
    try {
      providerRes = await fetch("https://api.openai.com/v1/responses", { method: "POST", headers: { authorization: `Bearer ${key}`, "content-type": "application/json" }, body: JSON.stringify({ model: modelId, input: `Return ONLY final code. Do not include reasoning, markdown fences, secrets, credentials, network calls, or filesystem calls.\n\nTask:\n${taskSummary}`, max_output_tokens: 900 }) });
      providerRequestId = providerRes.headers.get("x-request-id") ?? "";
      providerPayload = await providerRes.json().catch(() => null);
    } catch { await failRequest(requestId, claimToken, "OPENAI_NETWORK_ERROR", [`edge:${WORKER_ID}`], { provider_invoked: true }); return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "FAILED", error_code: "OPENAI_NETWORK_ERROR", request_id: requestId, provider_invoked: true, raw_secret_returned: false }, 502); }
    if (!providerRes.ok) { const code = `OPENAI_HTTP_${providerRes.status}`; await failRequest(requestId, claimToken, code, [`edge:${WORKER_ID}`,`provider:openai:http-${providerRes.status}`], { provider_invoked: true, provider_http_status: providerRes.status, provider_response_body_stored: false }); return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "FAILED", error_code: code, request_id: requestId, provider_http_status: providerRes.status, provider_invoked: true, raw_secret_returned: false }, 502); }
    const outputText = extractText(providerPayload);
    if (!outputText) { await failRequest(requestId, claimToken, "OPENAI_EMPTY_OUTPUT", [`edge:${WORKER_ID}`,`provider:openai:http-${providerRes.status}`], { provider_invoked: true, provider_http_status: providerRes.status }); return json({ state: "FAILED", error_code: "OPENAI_EMPTY_OUTPUT", request_id: requestId, provider_invoked: true, raw_secret_returned: false }, 502); }
    const out = await rpc("world8_provider_execution_output_record_v1", { p_request_id: requestId, p_claim_token: claimToken, p_content_kind: "CODE_TEXT", p_content_text: outputText, p_metadata: { worker_id: WORKER_ID, provider: "OpenAI", provider_http_status: providerRes.status, provider_request_id: providerRequestId || null, actual_model_id: String(providerPayload?.model ?? modelId), raw_secret_present: false, private_reasoning_present: false } });
    if (!out.ok) { await failRequest(requestId, claimToken, "OUTPUT_RECORD_FAILED", [`edge:${WORKER_ID}`,`provider:openai:http-${providerRes.status}`], { provider_invoked: true }); return json({ state: "FAILED", error_code: "OUTPUT_RECORD_FAILED", request_id: requestId, provider_invoked: true, raw_secret_returned: false }, 500); }
    const op: any = out.payload ?? {}; const outputRef = String(op.output_ref ?? "");
    const evidenceRef = providerRequestId ? `provider:openai:request-id:${providerRequestId}` : `provider:openai:responses:http-${providerRes.status}`;
    const done = await rpc("world8_provider_execution_complete_v2", { p_request_id: requestId, p_claim_token: claimToken, p_provider_invocation_evidence_ref: evidenceRef, p_output_refs: [outputRef], p_evidence_refs: [`edge:${WORKER_ID}`,`transport:${TRANSPORT_ID}`,`output:${String(op.output_id ?? "")}`], p_metadata: { provider_http_status: providerRes.status, provider_request_id: providerRequestId || null, actual_model_id: String(providerPayload?.model ?? modelId), output_sha256: String(op.content_sha256 ?? ""), live_provider_invoked: true, provider_response_body_stored_in_receipt: false, raw_secret_present: false, private_reasoning_present: false } });
    if (!done.ok) return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "COMPLETION_FAILED", request_id: requestId, provider_invoked: true, output_ref: outputRef, raw_secret_returned: false }, 500);
    return json({ schema: "WORLD8_PROVIDER_WORKER_EXECUTION/1.0", state: "SUCCEEDED", request_id: requestId, execution_id: cp.execution_id, provider: "OpenAI", model_id: modelId, provider_http_status: providerRes.status, provider_request_id_present: Boolean(providerRequestId), output_ref: outputRef, output_sha256: String(op.content_sha256 ?? ""), byte_length: op.byte_length, provider_invoked: true, raw_secret_returned: false, completion: done.payload });
  }
  return json({ error: "UNSUPPORTED_ACTION" }, 400);
});
