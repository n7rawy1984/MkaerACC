// Shared by the browser and Vite before bundling. Errors never include values.
export type PublicEnvironment = Record<string, string | undefined>;
function jwtRole(value: string): string | null {
  try {
    const parts = value.split('.');
    if (parts.length !== 3 || parts.some(p => !/^[A-Za-z0-9_-]+$/.test(p))) return null;
    const decode = (part: string) => JSON.parse(atob(part.replace(/-/g, '+').replace(/_/g, '/')));
    if (decode(parts[0]).alg !== 'HS256') return null;
    return decode(parts[1]).role ?? null;
  } catch { return null; }
}
export function browserSafeKey(value: string): boolean {
  return /^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(value) || jwtRole(value) === 'anon';
}
export function rejectPrivilegedPublicConfig(env: PublicEnvironment): void {
  for (const [name, raw] of Object.entries(env)) {
    if (!name.startsWith('VITE_') || !raw) continue;
    const value = raw.trim();
    if (/service.?role|secret|password|private.?key|access.?token|refresh.?token/i.test(name)
      || value.startsWith('sb_secret_') || jwtRole(value) === 'service_role'
      || value.includes('-----BEGIN ') || /^postgres(?:ql)?:\/\//i.test(value)) {
      throw new Error('Privileged credentials are forbidden in public configuration');
    }
  }
}
export function applicationMode(value: string | undefined, development: boolean): 'local-demo' | 'supabase-auth' {
  if (value === 'supabase-auth' || (value === 'local-demo' && development)) return value;
  throw new Error('Invalid application data mode');
}
export function supabaseBrowserConfig(env: PublicEnvironment, development: boolean): {url:string;key:string} {
  rejectPrivilegedPublicConfig(env);
  const url = env.VITE_SUPABASE_URL?.trim(), key = env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!url || !key) throw new Error('Missing browser-safe Supabase configuration');
  let parsed: URL;
  try { parsed = new URL(url); } catch { throw new Error('Invalid Supabase URL'); }
  if (parsed.username || parsed.password || parsed.search || parsed.hash
    || (parsed.protocol !== 'https:' && !(development && parsed.protocol === 'http:' && ['localhost','127.0.0.1','[::1]'].includes(parsed.hostname)))) {
    throw new Error('Invalid Supabase URL');
  }
  if (!browserSafeKey(key)) throw new Error('Invalid browser-safe Supabase key');
  return {url, key};
}
export function validateApplicationConfig(env: PublicEnvironment, development: boolean): void {
  rejectPrivilegedPublicConfig(env);
  const mode = applicationMode(env.VITE_APP_DATA_MODE, development);
  if (mode === 'supabase-auth') supabaseBrowserConfig(env, development);
}
