// Parse before invoking Auth. Reject ambiguous credentials instead of choosing one.
export function callbackInput(url: URL) {
  const params = url.searchParams;
  for (const key of ["code", "token_hash", "type", "invitation_id"]) {
    if (params.getAll(key).length > 1 || (params.has(key) && !params.get(key))) throw new Error("Unsupported callback");
  }
  if (url.hash || params.has("error") || params.has("error_code") || params.has("error_description")) throw new Error("Unsupported callback");
  const code = params.get("code"); const tokenHash = params.get("token_hash"); const type = params.get("type");
  if (code && tokenHash) throw new Error("Unsupported callback");
  if (tokenHash) {
    if (type !== "invite" && type !== "recovery") throw new Error("Unsupported callback");
    return { kind: "token" as const, tokenHash, type };
  }
  if (code) return { kind: "code" as const, code };
  if (type) throw new Error("Unsupported callback");
  return { kind: "session" as const };
}
