// Server-only handler with injected Auth/DB ports. Never imported by browser code.
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function deliveryHandler({ appOrigin, additionalOrigins = '[]', authorize, claim, deliver, finish }) {
  return async request => {
    let configured, allowedOrigins;
    try {
      const parseOrigin = value => {
        if (typeof value !== 'string') throw Error();
        const url = new URL(value);
        if (url.protocol !== 'https:' || url.hostname.includes('*') || url.pathname !== '/' || url.search || url.hash || url.username || url.password) throw Error();
        return url.origin;
      };
      configured = parseOrigin(appOrigin);
      const additional = JSON.parse(additionalOrigins);
      if (!Array.isArray(additional)) throw Error();
      allowedOrigins = new Set([configured, ...additional.map(parseOrigin)]);
    }
    catch { return Response.json({ error: 'CONFIGURATION_REQUIRED' }, { status: 503 }); }
    const origin = request.headers.get('origin');
    const headers = { 'Access-Control-Allow-Origin': origin && allowedOrigins.has(origin) ? origin : configured, 'Vary': 'Origin', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Cache-Control': 'no-store' };
    const reply = (body, status = 200) => Response.json(body, { status, headers });
    if (origin && !allowedOrigins.has(origin)) return reply({ error: 'DENIED' }, 403);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method !== 'POST') return reply({ error: 'METHOD_NOT_ALLOWED' }, 405);
    const authorization = request.headers.get('authorization');
    if (!authorization?.startsWith('Bearer ') || Number(request.headers.get('content-length') ?? 0) > 2000) return reply({ error: 'DENIED' }, 403);
    let input;
    try { const raw = await request.text(); if (raw.length > 2000) throw Error(); input = JSON.parse(raw); }
    catch { return reply({ error: 'INVALID_REQUEST' }, 400); }
    if (!input || typeof input !== 'object' || Object.keys(input).join(',') !== 'invitation_id' || !uuid.test(input.invitation_id)) return reply({ error: 'INVALID_REQUEST' }, 400);
    let lease;
    try {
      // Validated user token is forwarded to the DB; registry/session/MFA are
      // rechecked inside the lease RPC, never inferred from decoded client claims.
      await authorize(authorization);
      lease = await claim(authorization, input.invitation_id);
      if (!lease || lease.id !== input.invitation_id || !uuid.test(lease.lease_id) || typeof lease.email !== 'string') throw Error();
    } catch (error) { return reply({ error: error instanceof Error && error.message === 'MFA_REQUIRED' ? 'MFA_REQUIRED' : 'DENIED_OR_IN_PROGRESS' }, 403); }
    let outcome = 'DELIVERED', existingUser = false;
    try { await deliver(lease.email, `${configured}/auth/callback?invitation_id=${lease.id}`); }
    catch (error) { outcome = 'AUTH_DELIVERY_FAILED'; existingUser = error instanceof Error && error.message === 'EXISTING_USER_SIGN_IN_REQUIRED'; }
    try { await finish(lease.id, lease.lease_id, outcome); }
    catch { return reply({ error: 'DELIVERY_UNCERTAIN' }, 503); }
    if (existingUser) return reply({ error: 'EXISTING_USER_SIGN_IN_REQUIRED' }, 409);
    return reply({ invitation_id: lease.id, status: outcome }, outcome === 'DELIVERED' ? 200 : 502);
  };
}
