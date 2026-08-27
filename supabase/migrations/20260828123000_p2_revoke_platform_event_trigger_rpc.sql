-- P2V hardening: new hosted projects include this provider-managed event
-- trigger helper in public with default EXECUTE. It is not an application RPC
-- and browser roles do not need to invoke it.

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
