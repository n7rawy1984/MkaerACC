import { useEffect, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "../master/productionMasterDataContext";
import { displayMinor } from "./expenseRepository";
import { loadRetentionPaymentAttempt, saveRetentionPaymentAttempt, sendRetentionPaymentAttempt, retentionPaymentAttemptStorageKey, type RetentionPaymentAttempt } from "./retentionPaymentPostAttempt";
import { canPostRetentionPayment, normalizeRetentionPaymentInput, parseRetentionPaymentAED, type RetentionPaymentInput } from "./retentionPaymentPostRepository";
import { readRetentionPaymentById, type RetentionReleaseOutstanding, type RetentionPaymentRead } from "./retentionPaymentRepository";

export function RetentionPaymentPost({ userId, companyId, role, outstanding, onPosted }: { userId: string; companyId: string; role: string; outstanding: RetentionReleaseOutstanding[]; onPosted: () => void }) {
  const t = useT(); const master = useProductionMasterData();
  const [initial] = useState(() => { try { return { attempt: loadRetentionPaymentAttempt(window.sessionStorage, userId, companyId), ready: true }; } catch { return { attempt: null, ready: false }; } });
  const [attempt, setAttempt] = useState<RetentionPaymentAttempt | null>(initial.attempt); const [ready, setReady] = useState(initial.ready);
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const [posted, setPosted] = useState<RetentionPaymentRead | null>(null); const [subcontractId, setSubcontractId] = useState(""); const [treasuryId, setTreasuryId] = useState("");
  const [amounts, setAmounts] = useState<Record<string, string>>({}); const [formKey, setFormKey] = useState(0); const generation = useRef(0); const lock = useRef(false);
  useEffect(() => { const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => { if (event === "SIGNED_OUT" || !session || session.user.id !== userId) { generation.current++; setReady(false); setAttempt(null); setPosted(null); setMessage("denied"); } }); const invalidate = () => { generation.current++; }; return () => { invalidate(); data.subscription.unsubscribe(); }; }, [userId, companyId]);
  const subcontracts = master.phase === "READY" ? master.subcontracts.filter(row => row.companyId === companyId && outstanding.some(item => item.subcontract_id === row.id)) : [];
  const selectedTreasury = master.phase === "READY" ? master.treasuryAccounts.find(row => row.companyId === companyId && row.id === treasuryId) : undefined;
  const eligible = outstanding.filter(row => row.subcontract_id === subcontractId && (!selectedTreasury?.projectId || row.project_id === selectedTreasury.projectId));
  const recover = async (pending: RetentionPaymentAttempt, firstSend = false) => {
    if (lock.current || !ready || !canPostRetentionPayment(role)) return; lock.current = true; setBusy(true); setMessage(null); const version = generation.current; const current = () => generation.current === version; let confirmed = pending;
    try { confirmed = await sendRetentionPaymentAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend); if (!current()) return;
      const { data, error } = await getSupabaseClient().auth.getSession(); if (!current()) return; if (error || data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setAttempt(confirmed); const row = await readRetentionPaymentById(getSupabaseClient(), companyId, confirmed.receipt!.retention_payment_id); const live = await getSupabaseClient().auth.getSession(); if (!current()) return;
      if (live.error || live.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      if (row.posted_journal_entry_id !== confirmed.receipt!.journal_entry_id || row.status !== "POSTED") throw new Error("readback"); setPosted(row); onPosted();
    } catch (error) { if (current()) { if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); } else { setAttempt(confirmed); setMessage(confirmed.receipt ? "readError" : "unresolved"); } } }
    finally { if (current()) { lock.current = false; setBusy(false); } }
  };
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (lock.current || attempt || busy || !ready || master.phase !== "READY" || !canPostRetentionPayment(role)) return; const data = new FormData(event.currentTarget); const value = (name: string) => String(data.get(name) ?? "");
    try { if (value("confirm") !== "yes") throw new Error("invalid");
      const allocations = eligible.filter(row => amounts[row.id]?.trim()).map(row => ({ releaseId: row.id, amountMinor: parseRetentionPaymentAED(amounts[row.id]) }));
      const input = normalizeRetentionPaymentInput({ date: value("date"), subcontractId, treasuryId, totalMinor: parseRetentionPaymentAED(value("total")), method: value("method") as RetentionPaymentInput["method"], externalReference: value("externalReference") || null, notes: value("notes") || null, allocations });
      const byId = new Map(eligible.map(row => [row.id, row]));
      if (!subcontracts.some(row => row.id === input.subcontractId) || !selectedTreasury || selectedTreasury.status !== "ACTIVE"
        || !master.accounts.some(row => row.id === selectedTreasury.glAccountId && row.companyId === companyId && row.status === "ACTIVE" && row.accountType === "ASSET")
        || input.allocations.some(row => !byId.has(row.releaseId) || BigInt(row.amountMinor) > BigInt(byId.get(row.releaseId)!.outstanding_amount_minor))) throw new Error("invalid");
      const pending: RetentionPaymentAttempt = { version: 1, userId, companyId, key: crypto.randomUUID(), input }; saveRetentionPaymentAttempt(window.sessionStorage, pending); setAttempt(pending); void recover(pending, true);
    } catch (error) { setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError"); }
  };
  if (!canPostRetentionPayment(role)) return null; const field = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2";
  return <section className="mt-5 min-w-0 rounded-xl border border-slate-200 p-4" aria-label={t("retentionPaymentPost.title")}>
    <h3 className="font-semibold">{t("retentionPaymentPost.title")}</h3><p className="mt-2 text-sm text-slate-600">{t("retentionPaymentPost.scope")}</p>
    {message && <p role="alert" className="mt-3 break-words text-red-800">{t(`retentionPaymentPost.${message}`)}</p>}{busy && <p role="status">{t("retentionPaymentPost.pending")}</p>}
    {attempt ? <div className="mt-3 space-y-3 break-words"><p>{t(attempt.receipt ? "retentionPaymentPost.confirmed" : "retentionPaymentPost.frozen")}</p><p><bdi>{displayMinor(attempt.input.totalMinor)} AED · {attempt.input.allocations.length}</bdi></p><p>{t("retentionPaymentPost.request")}: <bdi>{attempt.key}</bdi></p>{attempt.receipt && <p><bdi>{attempt.receipt.payment_reference} · {attempt.receipt.journal_entry_id}</bdi></p>}{posted && <p role="status">{t("retentionPaymentPost.readback")}: <bdi>{posted.payment_reference} · {displayMinor(posted.total_amount_minor)} AED · {t(`retentionPaymentRead.${posted.status}`)}</bdi></p>}
      <button type="button" disabled={busy || !ready} className={field} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "retentionPaymentPost.readAgain" : "retentionPaymentPost.retry")}</button>
      {attempt.receipt && <button type="button" disabled={busy || !ready || !posted} className={field} onClick={() => { try { window.sessionStorage.removeItem(retentionPaymentAttemptStorageKey(userId, companyId)); setAttempt(null); setPosted(null); setMessage(null); setSubcontractId(""); setTreasuryId(""); setAmounts({}); setFormKey(v => v + 1); } catch { setMessage("storageError"); } }}>{t("retentionPaymentPost.new")}</button>}
    </div> : master.phase !== "READY" ? <p role="status">{t("retentionPaymentPost.masters")}</p> : <form key={formKey} onSubmit={submit} className="mt-4 space-y-4" aria-label={t("retentionPaymentPost.title")}><fieldset disabled={busy || !ready} className="grid min-w-0 gap-3 sm:grid-cols-2">
      <label>{t("retentionPaymentPost.date")}<input name="date" type="date" required className={field} /></label>
      <label>{t("retentionPaymentPost.subcontract")}<select value={subcontractId} onChange={e => { setSubcontractId(e.target.value); setAmounts({}); }} required className={field}><option value="">{t("retentionPaymentPost.select")}</option>{subcontracts.map(row => <option key={row.id} value={row.id}>{row.contractNumber} · {row.scopeOfWork} · {master.parties.find(p => p.id === row.subcontractorId)?.name ?? row.subcontractorId}</option>)}</select></label>
      <label>{t("retentionPaymentPost.treasury")}<select value={treasuryId} onChange={e => { setTreasuryId(e.target.value); setAmounts({}); }} required className={field}><option value="">{t("retentionPaymentPost.select")}</option>{master.treasuryAccounts.filter(row => row.companyId === companyId && row.status === "ACTIVE" && master.accounts.some(a => a.id === row.glAccountId && a.status === "ACTIVE" && a.accountType === "ASSET")).map(row => <option key={row.id} value={row.id}>{row.code} · {row.name}</option>)}</select></label>
      <label>{t("retentionPaymentPost.total")}<input name="total" inputMode="decimal" required className={field} /></label>
      <label>{t("retentionPaymentPost.method")}<select name="method" defaultValue="TRANSFER" className={field}>{(["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"] as const).map(value => <option key={value} value={value}>{t(`expenseRead.${value}`)}</option>)}</select></label>
      <label>{t("retentionPaymentPost.externalReference")}<input name="externalReference" maxLength={200} className={field} /></label>
      <label className="sm:col-span-2">{t("retentionPaymentPost.notes")}<textarea name="notes" maxLength={2000} className={field} /></label>
    </fieldset><fieldset disabled={busy || !ready || !subcontractId || !treasuryId} className="space-y-3"><legend className="font-medium">{t("retentionPaymentPost.allocations")}</legend>
      {subcontractId && treasuryId && eligible.length === 0 && <p role="status">{t("retentionPaymentPost.noEligible")}</p>}
      {eligible.map(row => <label key={row.id} className="grid gap-2 rounded-lg border border-slate-200 p-3 sm:grid-cols-[1fr_11rem]"><span className="min-w-0 break-words"><bdi>{row.release_reference} · {row.release_date}</bdi><span className="block text-sm text-slate-600"><bdi>{displayMinor(row.outstanding_amount_minor)} AED</bdi></span></span><input aria-label={`${row.release_reference} ${t("retentionPaymentPost.allocate")}`} inputMode="decimal" value={amounts[row.id] ?? ""} onChange={e => setAmounts(current => ({ ...current, [row.id]: e.target.value }))} className={field} /></label>)}
    </fieldset><label className="flex items-start gap-2"><input name="confirm" value="yes" type="checkbox" required /><span>{t("retentionPaymentPost.confirm")}</span></label><button type="submit" className={field}>{t("retentionPaymentPost.submit")}</button></form>}
  </section>;
}
