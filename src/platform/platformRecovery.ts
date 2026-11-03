import { isUuid, type PendingCommand } from "./platformApi";
const key = (user: string) => `narvo:platform:pending:${user}`;
// A request envelope only, never proof of authority or success. No auth tokens.
export function readPlatformAttempt(user: string): PendingCommand | null {
  const raw = window.sessionStorage.getItem(key(user)); if (!raw) return null;
  const data = JSON.parse(raw) as PendingCommand;
  if (!isUuid(data.requestId) || !data.command || !["set_subscription", "provision_accounting", "create_customer", "update_customer", "create_entity", "update_entity", "set_lifecycle", "set_membership", "set_user_status", "update_settings", "invite", "resend", "revoke"].includes(data.command.name)
    || !data.command.input || typeof data.command.input !== "object" || Object.values(data.command.input).some(v => typeof v !== "string") || raw.length > 16000) throw new Error("Invalid request envelope");
  return data;
}
export function savePlatformAttempt(user: string, pending: PendingCommand) { window.sessionStorage.setItem(key(user), JSON.stringify(pending)); }
export function clearPlatformAttempt(user: string) { window.sessionStorage.removeItem(key(user)); }
