import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { useAuth } from "../auth/AuthContext";
import { LoginPage } from "../auth/LoginPage";
import { useI18n } from "../i18n/I18nContext";
import { companyRoles, PlatformError, platformAuthRequest, readDirectory, readAuthenticatedPlatformContext, readPlatformOverview, sendPlatformCommand, transport, type AdminCommand, type Directory, type PendingCommand, type PlatformContext, type PlatformRow, type Resource } from "./platformApi";
import { platformDeadline } from "./platformDeadline";
import { platformText, type PlatformTextKey } from "./platformText";
import { clearPlatformAttempt, readPlatformAttempt, savePlatformAttempt } from "./platformRecovery";
import { ArrowDownUp, Plus, RefreshCw, Search } from "lucide-react";
import { CommercialOnboarding, CustomerPortfolio } from "./CommercialOnboarding";
import { PlatformShell } from "./PlatformShell";
import { DirectoryCell, EmptyState, LoadingState, PageHelp, PlatformOverview } from "./platformUi";
import "./platform.css";

function useText() { const { locale } = useI18n(); return (key: PlatformTextKey) => platformText[locale][key]; }
const value = (row: PlatformRow, key: string) => row[key] === null || row[key] === undefined ? "" : String(row[key]);
const labelKey = (key: string): PlatformTextKey | null => Object.hasOwn(platformText.en, key) ? key as PlatformTextKey : null;

function PlatformDialog({ title, close, children, busy }: { title: string; close: () => void; children: ReactNode; busy: boolean }) {
  const ref = useRef<HTMLDialogElement>(null); const t = useText();
  useEffect(() => { const node = ref.current; const previous = document.activeElement as HTMLElement | null; node?.showModal(); return () => { node?.close(); previous?.focus(); }; }, []);
  return <dialog ref={ref} className="platform-dialog" aria-labelledby="platform-dialog-title" onCancel={event => { event.preventDefault(); if (!busy) close(); }}>
    <header><h2 id="platform-dialog-title">{title}</h2><button type="button" disabled={busy} onClick={close}>{t("cancel")}</button></header>{children}
  </dialog>;
}

function Choice({ api, resource, name, title, selected = "", required = false, onSelect }: { api: ReturnType<typeof transport>; resource: Resource; name: string; title: string; selected?: string; required?: boolean; onSelect?: (row: PlatformRow) => void }) {
  const t = useText(); const [query, setQuery] = useState(""); const [page, setPage] = useState(0);
  const [rows, setRows] = useState<Directory>({ items: [], has_more: false }); const [error, setError] = useState(false);
  const [chosen, setChosen] = useState(selected);
  useEffect(() => { let alive = true; setRows({ items: [], has_more: false }); const timer = setTimeout(() => {
    void readDirectory(api, resource, page * 25, query).then(data => { if (alive) { setRows(data); setError(false); const current = data.items.find(row => value(row, "id") === selected); if (current) onSelect?.(current); } }, () => { if (alive) setError(true); });
  }, 150); return () => { alive = false; clearTimeout(timer); }; }, [api, resource, page, query, selected, onSelect]);
  return <fieldset className="platform-choice"><legend>{title}</legend>
    <input aria-label={`${title} — ${t("lookup")}`} placeholder={t("lookup")} value={query} onChange={e => { setQuery(e.target.value); setPage(0); }} maxLength={100}/>
    <select aria-label={title} name={name} required={required} value={chosen} onChange={e => { setChosen(e.target.value); const row = rows.items.find(r => value(r, "id") === e.target.value); if (row) onSelect?.(row); }}>
      <option value="">{t("optional")}</option>
      {chosen && !rows.items.some(row => value(row, "id") === chosen) && <option value={chosen}>{chosen}</option>}
      {rows.items.filter(row => !row.platform_identity).map(row => <option key={value(row, "id")} value={value(row, "id")}>{value(row, "name")} {value(row, "email")}</option>)}
    </select>
    {error && <p role="alert">{t("denied")}</p>}
    <div className="platform-pager"><button type="button" disabled={!page} onClick={() => setPage(n => n - 1)}>{t("previous")}</button><button type="button" disabled={!rows.has_more} onClick={() => setPage(n => n + 1)}>{t("next")}</button></div>
  </fieldset>;
}

export function PlatformMfa({ client, complete }: { client: SupabaseClient<Database>; complete: () => void }) {
  const t = useText(); const [factor, setFactor] = useState<string | null>(null); const [qr, setQr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false); const [error, setError] = useState(false);
  const [checking, setChecking] = useState(true); const [lookupRevision, setLookupRevision] = useState(0);
  const [failure, setFailure] = useState<PlatformError | null>(null);
  useEffect(() => {
    let alive = true; const controller = new AbortController();
    void (async () => {
      try {
        const result = await platformAuthRequest("mfa_factors", () => client.auth.mfa.listFactors(), { signal: controller.signal });
        if (!result.data) throw new PlatformError("uncertain", { operation: "mfa_factors", code: "INVALID_RESPONSE" });
        if (alive) { setFactor(result.data.totp.find(f => f.status === "verified")?.id ?? null); setError(false); setFailure(null); }
      } catch (error) { if (alive) { setFactor(null); setError(true); setFailure(error instanceof PlatformError ? error : null); } }
      finally { if (alive) setChecking(false); }
    })();
    return () => { alive = false; controller.abort(); };
  }, [client, lookupRevision]);
  const enroll = async () => { if (busy || checking || error) return; setBusy(true); setError(false); try {
    const factors = await platformAuthRequest("mfa_factors", () => client.auth.mfa.listFactors());
    if (!factors.data) throw new PlatformError("uncertain", { operation: "mfa_factors", code: "INVALID_RESPONSE" });
    // Another tab may have verified a factor since the initial lookup.
    const verified = factors.data.totp.find(f => f.status === "verified");
    if (verified) { setFactor(verified.id); setQr(null); return; }
    // Replace only this application's unfinished enrollment. Preserve other devices.
    const unfinished = factors.data.totp.filter(f => f.status !== "verified" && f.friendly_name === "NARVO ERP Platform");
    for (const f of unfinished) await platformAuthRequest("mfa_unenroll", () => client.auth.mfa.unenroll({ factorId: f.id }));
    const result = await platformAuthRequest("mfa_enroll", () => client.auth.mfa.enroll({ factorType: "totp", friendlyName: "NARVO ERP Platform" }));
    if (result.error) throw result.error; setFactor(result.data.id); setQr(result.data.totp.qr_code);
  } catch (error) { setError(true); setFailure(error instanceof PlatformError ? error : null); } finally { setBusy(false); } };
  const submit = async (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); if (!factor || busy) return; const code = String(new FormData(event.currentTarget).get("code")); setBusy(true); setError(false);
    try { await platformAuthRequest("mfa_verify", () => client.auth.mfa.challengeAndVerify({ factorId: factor, code })); setQr(null); complete(); } catch (error) { setError(true); setFailure(error instanceof PlatformError ? error : null); } finally { setBusy(false); }
  };
  return <section className="platform-panel"><h2>{t("mfa")}</h2><p>{t("mfaHelp")}</p>{error && <p role="alert">{t(failure?.code === "REQUEST_TIMEOUT" ? "requestTimedOut" : "mfaRequestFailed")}</p>}
    {error && failure?.operation && <p><code>{failure.operation}{failure.code ? ` · ${failure.code}` : ""}</code></p>}
    {checking && <p role="status">{t("loading")}</p>}
    {error && !factor && <button disabled={busy || checking} onClick={() => { setChecking(true); setError(false); setLookupRevision(n => n + 1); }}>{t("retry")}</button>}
    {!factor && <button onClick={() => void enroll()} disabled={busy || checking || error}>{t("enroll")}</button>}
    {qr && <><p>{t("screenshot")}</p><img className="platform-qr" src={qr.startsWith("data:") ? qr : `data:image/svg+xml;charset=utf-8,${encodeURIComponent(qr)}`} alt={t("enroll")}/></>}
    {factor && <form onSubmit={event => void submit(event)}><label>{t("authenticatorCode")}<input name="code" dir="ltr" inputMode="numeric" pattern="[0-9]{6}" autoComplete="one-time-code" required maxLength={6}/></label><button disabled={busy}>{busy ? t("pending") : t("verify")}</button></form>}
  </section>;
}

type Editor = { kind: AdminCommand["name"] | "details"; row?: PlatformRow };
type SensitiveAction = { kind: "command"; attempt: PendingCommand } | { kind: "delivery"; invitationId: string };
function EditorForm({ editor, api, busy, submit }: { editor: Editor; api: ReturnType<typeof transport>; busy: boolean; submit: (command: AdminCommand) => void }) {
  const t = useText(); const { kind, row = {} } = editor;
  const [entity, setEntity] = useState<PlatformRow | null>(null);
  const field = (name: string, required = false, max = 200, type = "text", fallback = "") => <label key={name}>{t(name === "code" ? kind === "create_customer" ? "customerCode" : "entityCode" : name as PlatformTextKey)}<input name={name} required={required} maxLength={max} type={type} defaultValue={value(row, name) || fallback}/></label>;
  const select = (name: string, options: readonly string[], fallback = "") => <label key={name}>{t(name as PlatformTextKey)}<select name={name} required defaultValue={options.includes(value(row, name)) ? value(row, name) : fallback || options[0]}>{options.map(option => <option key={option} value={option}>{labelKey(option) ? t(option as PlatformTextKey) : option.replaceAll("_", " ")}</option>)}</select></label>;
  const companyChoice = <Choice api={api} resource="entities" name="company_id" title={t("company_id")} required selected={value(row, "company_id")} onSelect={setEntity}/>;
  const onSubmit = (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); if (busy) return;
    const data = Object.fromEntries([...new FormData(event.currentTarget).entries()].filter(([key]) => key !== "confirm").map(([key, v]) => [key, String(v).trim()]));
    if (kind === "set_membership") { data.version = String(entity?.version ?? row.version ?? 0); }
    // Server validates the same closed field set and all authoritative relations.
    submit({ name: kind, input: data } as AdminCommand);
  };
  if (kind === "details") return <dl className="platform-details">{Object.entries(row).map(([key, v]) => <div key={key}><dt>{labelKey(key) ? t(key as PlatformTextKey) : key.replaceAll("_", " ")}</dt><dd><bdi>{typeof v === "object" ? JSON.stringify(v) : String(v ?? "—")}</bdi></dd></div>)}</dl>;
  return <form onSubmit={onSubmit}><fieldset disabled={busy} className="platform-fields">
    {!["create_customer", "create_entity", "invite", "set_membership"].includes(kind) && <>{kind !== "update_settings" && <input type="hidden" name="id" value={value(row, "id")}/>}<input type="hidden" name="version" value={value(row, "version")}/></>}
    {(kind === "create_customer" || kind === "update_customer") && <>{kind === "create_customer" && field("code", true, 50)}{field("name", true)}{field("contact_email", false, 254, "email")}</>}
    {(kind === "create_entity" || kind === "update_entity") && <>
      <p className="platform-wide">{t("entityHelp")}</p>{kind === "create_entity" && field("code", true, 50)}{field("name", true)}{field("legal_name")}{field("trn", false, 100)}{field("address", false, 1000)}{field("region", false, 100)}
      {select("entity_kind", ["BUSINESS", "PERSONAL"], "BUSINESS")}
      <Choice api={api} resource="customers" name="customer_id" title={t("customer_id")} selected={value(row, "customer_id")}/>
      {kind === "create_entity" ? <>{field("tenant_slug", true, 63)}{select("locale", ["en", "ar"], "en")}<Choice api={api} resource="users" name="initial_admin_id" title={t("initial_admin_id")}/></> : <><input type="hidden" name="plan_key" value={value(row, "plan_key") || "UNASSIGNED"}/><p>{t("managedPlanHelp")}</p></>}
    </>}
    {kind === "set_subscription" && <><p className="platform-wide">{t("manualSubscriptionHelp")}</p><p className="platform-wide"><bdi>{value(row, "name")} · {value(row, "code")}</bdi></p>{select("plan_key", ["TRIAL", "STANDARD"])}{select("subscription_state", ["TRIAL", "ACTIVE", "EXPIRED", "CANCELLED"])}{field("starts_on", true, 10, "date")}{field("ends_on", true, 10, "date")}{select("billing_method", ["NONE", "MANUAL_CASH", "MANUAL_BANK_TRANSFER", "MANUAL_OTHER"])}{select("payment_status", ["NOT_REQUIRED", "UNPAID", "PAID", "WAIVED"])}{field("payment_reference")}{field("reason", true, 500)}</>}
    {kind === "provision_accounting" && <><p className="platform-wide">{t("provisionHelp")}</p><p className="platform-wide"><bdi>{value(row, "name")} · {value(row, "code")}</bdi></p><input type="hidden" name="code" value={value(row, "code")}/>{field("treasury_name", true)}{select("treasury_type", ["CASH", "BANK"])}{field("bank_name")}{field("reason", true, 500)}</>}
    {kind === "set_lifecycle" && <><p className="platform-wide">{t("freeze")}</p>{select("state", row.lifecycle === "ARCHIVED" ? ["SUSPENDED"] : row.lifecycle === "DRAFT" ? ["ACTIVE", "ARCHIVED"] : row.lifecycle === "SUSPENDED" ? ["ACTIVE", "ARCHIVED"] : ["SUSPENDED", "ARCHIVED"])}{field("reason", true, 500)}</>}
    {kind === "set_user_status" && <>{select("status", [row.status === "ACTIVE" ? "INACTIVE" : "ACTIVE"])}{field("reason", true, 500)}</>}
    {kind === "set_membership" && <>{companyChoice}<Choice api={api} resource="users" name="user_id" title={t("user_id")} required selected={value(row, "user_id") || value(row, "id")}/>{select("role", [...companyRoles, "REVOKED"], "MANAGEMENT_VIEWER")}{field("reason", true, 500)}</>}
    {kind === "invite" && <>{companyChoice}{field("email", true, 254, "email")}{select("role", companyRoles, "MANAGEMENT_VIEWER")}<p className="platform-wide">{t("deliveryHelp")}</p></>}
    {kind === "revoke" && field("reason", true, 500)}
    {kind === "resend" && <p>{t("deliveryHelp")}</p>}
    {kind === "update_settings" && <>{field("support_email", false, 254, "email")}{field("notice_en", false, 500)}{field("notice_ar", false, 500)}</>}
    <label className="platform-confirm platform-wide"><input type="checkbox" name="confirm" required/>{t("confirm")}</label>
    <button type="submit" className="platform-primary platform-wide">{busy ? t("pending") : kind.startsWith("create") || kind === "invite" ? t("create") : t("save")}</button>
  </fieldset></form>;
}

function Console({ client, userId, revalidate }: { client: SupabaseClient<Database>; userId: string; revalidate: () => void }) {
  const navigate=useNavigate();
  const chooseCustomer=useCallback((row:PlatformRow)=>navigate(`/platform/onboarding?customer=${value(row,"id")}`),[navigate]);
  const api = useMemo(() => transport(client), [client]); const t = useText(); const { locale } = useI18n(); const { pathname } = useLocation();
  const pathParts = pathname.split("/"); const tab = pathParts[2] || "overview"; const selectedEntity = tab === "entities" ? pathParts[3] : undefined;
  const resource: Resource = ["entities", "customers", "users", "memberships", "invitations", "audit", "settings", "subscriptions"].includes(tab) ? tab as Resource : "entities";
  const [data, setData] = useState<Directory | null>(null); const [overview, setOverview] = useState<Record<string, unknown> | null>(null);
  const [query, setQuery] = useState(""); const [page, setPage] = useState(0); const [generation, setGeneration] = useState(0);
  const [error, setError] = useState<string | null>(null); const [editor, setEditor] = useState<Editor | null>(() => {
    try { if (readPlatformAttempt(userId)) return null; } catch { return null; }
    return tab === "entities" && selectedEntity === "new" ? { kind: "create_entity" } : null;
  });
  const [readFailure, setReadFailure] = useState<PlatformError | null>(null);
  const [sensitiveAction, setSensitiveAction] = useState<SensitiveAction | null>(null);
  const [stepPhase, setStepPhase] = useState<"verify" | "confirm">("verify");
  const [busy, setBusy] = useState(false); const [pending, setPending] = useState<PendingCommand | null>(() => { try { return readPlatformAttempt(userId); } catch { return null; } }); const [receipt, setReceipt] = useState<string | null>(null);
  const [rejected, setRejected] = useState(false); const live = useRef(0); const commandLock = useRef(false);
  useEffect(() => { const request = ++live.current; let alive = true; setData(null); setOverview(null); setError(null); setReadFailure(null);
    const controller = new AbortController();
    const load = tab === "onboarding" ? Promise.resolve(null) : tab === "overview" ? readPlatformOverview(api, { signal: controller.signal }) : readDirectory(api, resource, page * 25, selectedEntity && selectedEntity !== "new" ? selectedEntity : query);
    void load.then(result => { if (!alive || live.current !== request) return; setError(null); setReadFailure(null); if (tab === "overview") setOverview(result as Record<string, unknown>); else if (result) setData(result as Directory); }, e => { if (alive && live.current === request) { const kind = e instanceof PlatformError ? e.kind : "uncertain"; setError(kind); setReadFailure(e instanceof PlatformError ? e : null); if (kind === "mfa" || kind === "denied") revalidate(); } });
    return () => { alive = false; controller.abort(); };
  }, [api, resource, tab, selectedEntity, query, page, generation, revalidate]);
  useEffect(() => () => { live.current++; }, []);
  const submit = async (command: AdminCommand, prior?: PendingCommand) => {
    if (commandLock.current) return; commandLock.current = true;
    const attempt = prior ?? { command, requestId: crypto.randomUUID() }; setPending(attempt); setBusy(true); setReceipt(null); setError(null); setRejected(false);
    const request = live.current;
    try { savePlatformAttempt(userId, attempt); const result = await sendPlatformCommand(api, attempt); clearPlatformAttempt(userId); if (live.current !== request) return; setReceipt(result.id); setPending(null); setEditor(null); setSensitiveAction(null); setGeneration(n => n + 1); if(tab === "onboarding" && command.name === "create_customer")navigate(`/platform/onboarding?customer=${result.id}`); if(tab === "onboarding" && command.name === "create_entity")navigate(`/platform/onboarding?company=${result.id}`); }
    catch (e) { if (live.current !== request) return; const kind = e instanceof PlatformError ? e.kind : "uncertain"; setError(kind); setRejected(kind !== "uncertain"); if (kind === "mfa") { setStepPhase("verify"); setSensitiveAction({ kind: "command", attempt }); } else { setSensitiveAction(null); if (kind === "denied") revalidate(); } }
    finally { commandLock.current = false; setBusy(false); }
  };
  const deliver = async (id: string) => { if (commandLock.current) return; commandLock.current = true; setBusy(true); setError(null); const request = live.current; try {
    await platformDeadline(async () => {
      const result = await client.functions.invoke("platform-invitation-delivery", { body: { invitation_id: id } });
      if (result.error) {
        if ("context" in result.error && result.error.context instanceof Response) {
          const body: unknown = await result.error.context.clone().json();
          if (body && typeof body === "object" && "error" in body && body.error === "MFA_REQUIRED") throw new PlatformError("mfa");
          if (body && typeof body === "object" && "error" in body && body.error === "EXISTING_USER_SIGN_IN_REQUIRED") throw new PlatformError("existing_user");
        }
        throw new PlatformError("uncertain");
      }
    });
    if (live.current !== request) return; setSensitiveAction(null); setGeneration(n => n + 1);
  } catch (error) { if (live.current !== request) return; const kind = error instanceof PlatformError ? error.kind : "uncertain"; setError(kind === "existing_user" ? "existingUserDelivery" : kind); if (kind === "mfa") { setStepPhase("verify"); setSensitiveAction({ kind: "delivery", invitationId: id }); } else setSensitiveAction(null); } finally { commandLock.current = false; setBusy(false); } };
  const [filter, setFilter] = useState("");
  const [sort, setSort] = useState({ column: "", descending: resource === "audit" });
  const columns: Record<Resource, string[]> = { subscriptions: ["name", "plan_key", "effective_state", "ends_on", "renewal_due_on", "billing_method", "payment_status", "subscription_access"], entities: ["name", "code", "entity_kind", "lifecycle", "onboarding", "accounting_setup"], customers: ["name", "code", "contact_email", "portfolio"], users: ["name", "email", "status"], memberships: ["company_name", "name", "role", "status"], invitations: ["company_name", "email", "role", "state", "invalidation_reason", "delivery", "expires_at", "error_code"], audit: ["created_at", "action", "actor_id", "target_id", "metadata"], settings: ["support_email", "notice_en", "notice_ar", "version"] };
  const filterField = resource === "subscriptions" ? "effective_state" : resource === "entities" ? "lifecycle" : resource === "invitations" ? "state" : resource === "audit" ? "action" : ["users", "memberships"].includes(resource) ? "status" : null;
  const filterValues = [...new Set([...(data?.items.map(row => value(row, filterField || "")) ?? []), filter])].filter(Boolean).sort();
  const sortColumn = sort.column || columns[resource][0];
  const collator = new Intl.Collator(locale, { numeric: true, sensitivity: "base" });
  const visibleRows = (data?.items ?? []).filter(row => !filter || value(row, filterField || "") === filter).toSorted((a, b) => (sort.descending ? -1 : 1) * collator.compare(value(a, sortColumn), value(b, sortColumn)));
  const resetFilters = () => { setQuery(""); setFilter(""); setPage(0); };
  const titleKey = tab === "onboarding" ? "commercialOnboarding" : labelKey(tab) ? tab as PlatformTextKey : "overview";
  const description = `${titleKey}Description` as PlatformTextKey;
  return <>
    <header className="platform-page-title"><div><p className="platform-eyebrow">{t("context")}</p><h1>{t(titleKey)}</h1><p>{t(description)}</p></div><button disabled={busy} onClick={() => { setGeneration(n => n + 1); }}><RefreshCw size={16} aria-hidden="true"/>{t("refresh")}</button></header>
    {error && <p role="alert" className="platform-error">{t(readFailure?.code === "REQUEST_TIMEOUT" ? "requestTimedOut" : readFailure?.kind === "uncertain" ? "accessRequestFailed" : labelKey(error) ? error as PlatformTextKey : "uncertain")}</p>}
    {readFailure?.operation && <div><code>{readFailure.operation}{readFailure.code ? ` · ${readFailure.code}` : ""}</code><button onClick={() => setGeneration(n => n + 1)}>{t("retry")}</button></div>}
    {receipt && <p role="status" className="platform-success">{t("confirmed")} <bdi>{receipt}</bdi></p>}
    {pending && !editor && <section className="platform-panel"><p>{t("uncertain")}</p><button disabled={busy} onClick={() => void submit(pending.command, pending)}>{t("recover")}</button>{rejected && <button disabled={busy} onClick={() => { clearPlatformAttempt(userId); setPending(null); setError(null); }}>{t("discard")}</button>}</section>}
    {tab === "onboarding" ? <CommercialOnboarding customerSelector={<Choice api={api} resource="customers" name="onboarding_customer" title={t("customer_id")} onSelect={chooseCustomer}/>} api={api} generation={generation} disabled={busy||!!pending} open={(kind,row)=>setEditor({kind,row})} denied={revalidate}/> : tab === "overview" ? overview ? <PlatformOverview data={overview}/> : !error && <LoadingState/> : <>
      <div className="platform-toolbar"><label className="platform-search">{t("search")}<span><Search size={17} aria-hidden="true"/><input type="search" value={query} maxLength={100} disabled={!!selectedEntity && selectedEntity !== "new"} onChange={e => { setPage(0); setQuery(e.target.value); }}/></span></label>
        {filterField && <label>{t(filterField === "action" ? "filterAction" : "filterStatus")}<select aria-label={t(filterField === "action" ? "filterAction" : "filterStatus")} value={filter} onChange={e => setFilter(e.target.value)}><option value="">{t("allStatuses")}</option>{filterValues.map(option => <option key={option} value={option}>{labelKey(option) ? t(option as PlatformTextKey) : option}</option>)}</select></label>}
        <label className="platform-sort">{t("sortBy")}<select aria-label={t("sortBy")} value={sortColumn} onChange={e => setSort(previous => ({ ...previous, column: e.target.value }))}>{columns[resource].filter(key => key !== "metadata" && key !== "portfolio").map(key => <option key={key} value={key}>{labelKey(key) ? t(key as PlatformTextKey) : key}</option>)}</select></label>
        <button className="platform-sort-direction" aria-label={t(sort.descending ? "sortAscending" : "sortDescending")} onClick={() => setSort(previous => ({ ...previous, descending: !previous.descending }))}><ArrowDownUp size={17} aria-hidden="true"/></button>
        <div className="platform-create-actions">
        {tab === "customers" && <button className="platform-primary" disabled={!!pending} onClick={() => setEditor({ kind: "create_customer" })}><Plus size={16} aria-hidden="true"/>{t("newCustomer")}</button>}
        {tab === "entities" && <button className="platform-primary" disabled={!!pending} onClick={() => setEditor({ kind: "create_entity" })}><Plus size={16} aria-hidden="true"/>{t("newEntity")}</button>}
        {tab === "invitations" && <button className="platform-primary" disabled={!!pending} onClick={() => setEditor({ kind: "invite" })}><Plus size={16} aria-hidden="true"/>{t("invite")}</button>}
        </div>
      </div>
      <div className="platform-directory-meta"><p>{t("loadedPageOnly")}</p>{data && <span>{t("visibleRecords")}: {visibleRows.length} · {t("loadedRecords")}: {data.items.length}</span>}</div>
      {selectedEntity && selectedEntity !== "new" && <Link className="platform-back-link" to="/platform/entities">{t("entities")}</Link>}
      {!data && !error && <LoadingState/>}
      {data && <div className="platform-table-wrap" role="region" aria-label={`${t(titleKey)} — ${t("directoryLabel")}`} tabIndex={0}><table><caption className="platform-sr-only">{t(titleKey)} · {t("page")} {page + 1}</caption><thead><tr>{columns[resource].map(key => <th key={key} scope="col">{labelKey(key) ? t(key as PlatformTextKey) : key.replaceAll("_", " ")}</th>)}<th scope="col">{t("actions")}</th></tr></thead><tbody>
        {visibleRows.map((row, i) => <tr key={value(row, "id") || i}>{columns[resource].map(key => <td key={key} data-label={labelKey(key) ? t(key as PlatformTextKey) : key.replaceAll("_", " ")}>{resource === "customers" && key === "portfolio" ? <CustomerPortfolio api={api} customerId={value(row,"id")} generation={generation}/> : <DirectoryCell row={row} field={key} showCode={resource === "subscriptions"}/>}</td>)}<td data-label={t("actions")}><div className="platform-row-actions">
          <button disabled={busy} onClick={() => setEditor({ kind: "details", row })}>{t("details")}</button>
          {tab === "entities" && <><Link to={`/platform/onboarding?company=${value(row,"id")}`}>{t("commercialOnboarding")}</Link><Link to={`/platform/entities/${value(row, "id")}`}>{t("openEntity")}</Link><button disabled={!!pending} onClick={() => setEditor({ kind: "update_entity", row })}>{t("edit")}</button><button disabled={!!pending} onClick={() => setEditor({ kind: "set_lifecycle", row })}>{t("lifecycle")}</button>{row.lifecycle === "ACTIVE" && row.accounting_setup === "INCOMPLETE" && <button disabled={!!pending} onClick={() => setEditor({ kind: "provision_accounting", row })}>{t("provisionAccounting")}</button>}</>}
          {tab === "subscriptions" && <button aria-label={t("manageSubscription")} disabled={!!pending} onClick={() => setEditor({ kind: "set_subscription", row })}>{t("manageShort")}</button>}
          {tab === "customers" && <Link to={`/platform/onboarding?customer=${value(row,"id")}`}>{t("portfolio")}</Link>}
          {tab === "customers" && <button disabled={!!pending} onClick={() => setEditor({ kind: "update_customer", row })}>{t("edit")}</button>}
          {tab === "users" && !row.platform_identity && <><button disabled={!!pending} onClick={() => setEditor({ kind: "set_membership", row })}>{t("access")}</button><button disabled={!!pending} onClick={() => setEditor({ kind: "set_user_status", row })}>{t("status")}</button></>}
          {tab === "memberships" && <button disabled={!!pending} onClick={() => setEditor({ kind: "set_membership", row })}>{t("access")}</button>}
          {tab === "settings" && <button disabled={!!pending} onClick={() => setEditor({ kind: "update_settings", row })}>{t("edit")}</button>}
          {tab === "invitations" && row.state === "PENDING" && <><label>{t("invitationReviewLink")}<input readOnly value={`${window.location.origin}/auth/callback?invitation_id=${value(row, "id")}`} onFocus={event => event.currentTarget.select()}/></label><button disabled={!!pending || busy} onClick={() => { setStepPhase("confirm"); setSensitiveAction({ kind: "delivery", invitationId: value(row, "id") }); }}>{t("deliver")}</button><button disabled={!!pending} onClick={() => setEditor({ kind: "resend", row })}>{t("resend")}</button><button disabled={!!pending} onClick={() => setEditor({ kind: "revoke", row })}>{t("revoke")}</button></>}
        </div></td></tr>)}
      </tbody></table>{!visibleRows.length && <EmptyState reset={resetFilters}/>}</div>}
      {data && <p className="platform-scroll-help">{t("tableScrollHelp")}</p>}
      <div className="platform-pager"><button disabled={!page || busy} onClick={() => setPage(n => n - 1)}>{t("previous")}</button><span>{t("page")} {page + 1}</span><button disabled={!data?.has_more || busy} onClick={() => setPage(n => n + 1)}>{t("next")}</button></div>
      {["entities", "invitations", "subscriptions"].includes(tab) && <PageHelp>{tab === "entities" ? <p>{t("freeze")}</p> : tab === "subscriptions" ? <p>{t("manualSubscriptionHelp")}</p> : <><p>{t("deliveryHelp")}</p><p>{t("invitationLinkHelp")}</p></>}</PageHelp>}
    </>}
    {editor && !sensitiveAction && <PlatformDialog title={t(editor.kind === "set_subscription" ? "manageSubscription" : editor.kind === "provision_accounting" ? "provisionAccounting" : editor.kind === "details" ? "details" : editor.kind === "set_lifecycle" ? "lifecycle" : editor.kind === "set_membership" ? "access" : editor.kind === "create_entity" ? "newEntity" : editor.kind === "create_customer" ? "newCustomer" : editor.kind === "invite" ? "invite" : "edit")} busy={busy} close={() => setEditor(null)}>
      {pending ? <section><p role="alert">{t(labelKey(error ?? "") ? error as PlatformTextKey : "uncertain")}</p><button disabled={busy} onClick={() => void submit(pending.command, pending)}>{t("recover")}</button>{rejected && <button disabled={busy} onClick={() => { clearPlatformAttempt(userId); setPending(null); setError(null); }}>{t("discard")}</button>}</section> : <EditorForm editor={editor} api={api} busy={busy} submit={command => void submit(command)}/>}
    </PlatformDialog>}
    {sensitiveAction && <PlatformDialog title={t(stepPhase === "verify" ? "mfa" : "confirmResume")} busy={busy} close={() => setSensitiveAction(null)}>
      {stepPhase === "verify" ? <><p>{t("mutationMfaHelp")}</p><PlatformMfa client={client} complete={() => setStepPhase("confirm")}/></> : <form onSubmit={event => { event.preventDefault(); if (!busy) { if (sensitiveAction.kind === "command") void submit(sensitiveAction.attempt.command, sensitiveAction.attempt); else void deliver(sensitiveAction.invitationId); } }}>
        <p>{t("reviewResume")}</p><p>{sensitiveAction.kind === "command" ? sensitiveAction.attempt.command.name : t("deliver")}</p>
        <dl>{Object.entries(sensitiveAction.kind === "command" ? sensitiveAction.attempt.command.input : { invitation_id: sensitiveAction.invitationId }).map(([key, item]) => <div key={key}><dt>{labelKey(key) ? t(key as PlatformTextKey) : key}</dt><dd><bdi>{String(item)}</bdi></dd></div>)}</dl>
        <label className="platform-confirm"><input name="confirmResume" type="checkbox" required disabled={busy}/>{t("confirm")}</label><button disabled={busy}>{busy ? t("pending") : t("confirmResume")}</button>
      </form>}
    </PlatformDialog>}
  </>;
}

export default function PlatformApplication({ client }: { client: SupabaseClient<Database> }) {
  const t = useText(); const { state, signOut } = useAuth();
  const { pathname } = useLocation();
  const [access, setAccess] = useState<PlatformContext | null>(null); const [loading, setLoading] = useState(true); const [denied, setDenied] = useState(false); const [revision, setRevision] = useState(0);
  const [failure, setFailure] = useState<PlatformError | null>(null);
  const signedOut = state.phase === "SIGNED_OUT";
  const accessRef = useRef<PlatformContext | null>(null);
  const refresh = useCallback(() => { accessRef.current = null; setAccess(null); setLoading(true); setRevision(n => n + 1); }, []);
  useEffect(() => {
    if (signedOut) { accessRef.current = null; return; }
    let alive = true; let request = 0; let pending: AbortController | null = null; let failed = false; let actor: string | null = null;
    const cancel = () => { request++; pending?.abort(); pending = null; };
    const load = () => {
      // Focus, visibility and Auth notifications share one bounded read. Failed
      // reads stay actionable until explicit Retry or a real Auth transition.
      if (!alive || pending || failed) return;
      const sequence = ++request; const controller = new AbortController(); pending = controller;
      if (!accessRef.current) { setAccess(null); setLoading(true); } setDenied(false); setFailure(null);
      void readAuthenticatedPlatformContext(client, { signal: controller.signal }).then(data => { if (alive && sequence === request) {
        accessRef.current = data; setAccess(previous => previous?.user_id === data.user_id && previous.step_up_required === data.step_up_required ? previous : data); setLoading(false);
      } }, error => { if (alive && sequence === request) { failed = true; accessRef.current = null; setAccess(null); setDenied(true); setFailure(error instanceof PlatformError ? error : null); setLoading(false); } }).finally(() => { if (sequence === request) pending = null; });
    };
    const visible = () => { if (document.visibilityState === "visible") load(); };
    const { data: { subscription } } = client.auth.onAuthStateChange((event, session) => {
      if (!session) { cancel(); actor = null; accessRef.current = null; setAccess(null); setLoading(false); return; }
      if (actor && actor !== session.user.id) {
        cancel(); accessRef.current = null; setAccess(null); failed = false;
      }
      if (event === "MFA_CHALLENGE_VERIFIED") { cancel(); failed = false; }
      actor = session.user.id;
      if (event === "TOKEN_REFRESHED") failed = false;
      queueMicrotask(() => { if (alive) load(); });
    });
    load(); const interval = window.setInterval(load, 60000); window.addEventListener("focus", load); document.addEventListener("visibilitychange", visible);
    return () => { alive = false; cancel(); subscription.unsubscribe(); clearInterval(interval); window.removeEventListener("focus", load); document.removeEventListener("visibilitychange", visible); };
  }, [client, revision, signedOut]);
  if (state.phase === "SIGNED_OUT") return <LoginPage context={t("title")} footer={<Link to="/auth/recovery">{t("recoveryRequest")}</Link>}/>;
  return <PlatformShell signOut={() => void signOut()}>{loading ? <p role="status">{t("loading")}</p> : denied || !access ? <section className="platform-panel"><p role="alert">{t(failure?.code === "REQUEST_TIMEOUT" ? "requestTimedOut" : failure?.code === "SIGN_IN_REQUIRED" ? "sessionRevoked" : failure?.kind === "uncertain" ? "accessRequestFailed" : "denied")}</p>{failure?.reason && <p>{t(failure.reason === "session_revoked" ? "sessionRevoked" : "ownerAccountRequired")}</p>}{failure?.operation && <p><code>{failure.operation}{failure.code ? ` · ${failure.code}` : ""}</code></p>}<button onClick={refresh}>{t("retry")}</button><button onClick={() => void signOut()}>{t("switchAccount")}</button></section> : access.step_up_required ? <PlatformMfa client={client} complete={refresh}/> : <Console key={access.user_id + ":" + revision + ":" + pathname} userId={access.user_id} client={client} revalidate={refresh}/>}</PlatformShell>;
}
