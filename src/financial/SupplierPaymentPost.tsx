import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "../master/productionMasterDataContext";
import { displayMinor } from "./expenseRepository";
import { loadSupplierPaymentAttempt, saveSupplierPaymentAttempt, sendSupplierPaymentAttempt, supplierPaymentAttemptStorageKey, type SupplierPaymentAttempt } from "./supplierPaymentPostAttempt";
import { canPostSupplierPayment, normalizeSupplierPaymentInput, parseSupplierPaymentAED, type SupplierPaymentInput } from "./supplierPaymentPostRepository";
import { readSupplierPaymentById, type SupplierCreditOutstanding, type SupplierPaymentRead } from "./supplierPaymentRepository";

export function SupplierPaymentPost({ userId, companyId, role, outstanding, onPosted }: { userId: string; companyId: string; role: string; outstanding: SupplierCreditOutstanding[]; onPosted: () => void }) {
  const t = useT(); const master = useProductionMasterData();
  const [initial] = useState(() => { try { return { attempt: loadSupplierPaymentAttempt(window.sessionStorage, userId, companyId), ready: true }; } catch { return { attempt: null, ready: false }; } });
  const [attempt, setAttempt] = useState<SupplierPaymentAttempt | null>(initial.attempt); const [ready, setReady] = useState(initial.ready);
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const [posted, setPosted] = useState<SupplierPaymentRead | null>(null); const [supplierId, setSupplierId] = useState(""); const [treasuryId, setTreasuryId] = useState("");
  const [amounts, setAmounts] = useState<Record<string, string>>({}); const [formKey, setFormKey] = useState(0); const generation = useRef(0); const lock = useRef(false);
  useEffect(() => { const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => { if (event === "SIGNED_OUT" || !session || session.user.id !== userId) { generation.current++; setReady(false); setAttempt(null); setPosted(null); setMessage("denied"); } }); const invalidate = () => { generation.current++; }; return () => { invalidate(); data.subscription.unsubscribe(); }; }, [userId, companyId]);
  const suppliers = useMemo(() => master.phase === "READY" ? master.parties.filter(p => p.companyId === companyId && p.type === "SUPPLIER" && outstanding.some(row => row.supplier_id === p.id)) : [], [master, companyId, outstanding]);
  const selectedTreasury = master.phase === "READY" ? master.treasuryAccounts.find(row => row.companyId === companyId && row.id === treasuryId) : undefined;
  const eligible = outstanding.filter(row => row.supplier_id === supplierId && (!selectedTreasury?.projectId || row.project_id === selectedTreasury.projectId));
  const recover = async (pending: SupplierPaymentAttempt, firstSend = false) => {
    if (lock.current || !ready || !canPostSupplierPayment(role)) return; lock.current = true; setBusy(true); setMessage(null); const version = generation.current; const current = () => generation.current === version; let confirmed = pending;
    try { confirmed = await sendSupplierPaymentAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend); if (!current()) return;
      const { data, error } = await getSupabaseClient().auth.getSession(); if (!current()) return; if (error || data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setAttempt(confirmed); const row = await readSupplierPaymentById(getSupabaseClient(), companyId, confirmed.receipt!.supplier_payment_id); const live = await getSupabaseClient().auth.getSession(); if (!current()) return;
      if (live.error || live.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      if (row.posted_journal_entry_id !== confirmed.receipt!.journal_entry_id || row.status !== "POSTED") throw new Error("readback"); setPosted(row); onPosted();
    } catch (error) { if (current()) { if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); } else { setAttempt(confirmed); setMessage(confirmed.receipt ? "readError" : "unresolved"); } } }
    finally { if (current()) { lock.current = false; setBusy(false); } }
  };
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (lock.current || attempt || busy || !ready || master.phase !== "READY" || !canPostSupplierPayment(role)) return; const data = new FormData(event.currentTarget); const value = (name: string) => String(data.get(name) ?? "");
    try { if (value("confirm") !== "yes") throw new Error("invalid");
      const allocations = eligible.filter(row => amounts[row.id]?.trim()).map(row => ({ expenseId: row.id, amountMinor: parseSupplierPaymentAED(amounts[row.id]) }));
      const input = normalizeSupplierPaymentInput({ date: value("date"), supplierId, treasuryId, totalMinor: parseSupplierPaymentAED(value("total")), method: value("method") as SupplierPaymentInput["method"], externalReference: value("externalReference") || null, notes: value("notes") || null, allocations });
      const byId = new Map(eligible.map(row => [row.id, row]));
      if (!suppliers.some(row => row.id === input.supplierId) || !selectedTreasury || selectedTreasury.status !== "ACTIVE"
        || !master.accounts.some(row => row.id === selectedTreasury.glAccountId && row.companyId === companyId && row.status === "ACTIVE" && row.accountType === "ASSET")
        || input.allocations.some(row => !byId.has(row.expenseId) || BigInt(row.amountMinor) > BigInt(byId.get(row.expenseId)!.outstanding_amount_minor))) throw new Error("invalid");
      const pending: SupplierPaymentAttempt = { version: 1, userId, companyId, key: crypto.randomUUID(), input }; saveSupplierPaymentAttempt(window.sessionStorage, pending); setAttempt(pending); void recover(pending, true);
    } catch (error) { setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError"); }
  };
  if (!canPostSupplierPayment(role)) return null; const field = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2";
  return <section className="mt-5 min-w-0 rounded-xl border border-slate-200 p-4" aria-label={t("supplierPaymentPost.title")}>
    <h3 className="font-semibold">{t("supplierPaymentPost.title")}</h3><p className="mt-2 text-sm text-slate-600">{t("supplierPaymentPost.scope")}</p>
    {message && <p role="alert" className="mt-3 break-words text-red-800">{t(`supplierPaymentPost.${message}`)}</p>}{busy && <p role="status">{t("supplierPaymentPost.pending")}</p>}
    {attempt ? <div className="mt-3 space-y-3 break-words"><p>{t(attempt.receipt ? "supplierPaymentPost.confirmed" : "supplierPaymentPost.frozen")}</p><p><bdi>{displayMinor(attempt.input.totalMinor)} AED · {attempt.input.allocations.length}</bdi></p><p>{t("supplierPaymentPost.request")}: <bdi>{attempt.key}</bdi></p>{attempt.receipt && <p><bdi>{attempt.receipt.payment_reference} · {attempt.receipt.journal_entry_id}</bdi></p>}{posted && <p role="status">{t("supplierPaymentPost.readback")}: <bdi>{posted.payment_reference} · {displayMinor(posted.total_amount_minor)} AED · {t(`supplierPaymentRead.${posted.status}`)}</bdi></p>}
      <button type="button" disabled={busy || !ready} className={field} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "supplierPaymentPost.readAgain" : "supplierPaymentPost.retry")}</button>
      {attempt.receipt && <button type="button" disabled={busy || !ready || !posted} className={field} onClick={() => { try { window.sessionStorage.removeItem(supplierPaymentAttemptStorageKey(userId, companyId)); setAttempt(null); setPosted(null); setMessage(null); setSupplierId(""); setTreasuryId(""); setAmounts({}); setFormKey(v => v + 1); } catch { setMessage("storageError"); } }}>{t("supplierPaymentPost.new")}</button>}
    </div> : master.phase !== "READY" ? <p role="status">{t("supplierPaymentPost.masters")}</p> : <form key={formKey} onSubmit={submit} className="mt-4 space-y-4" aria-label={t("supplierPaymentPost.title")}><fieldset disabled={busy || !ready} className="grid min-w-0 gap-3 sm:grid-cols-2">
      <label>{t("supplierPaymentPost.date")}<input name="date" type="date" required className={field} /></label>
      <label>{t("supplierPaymentPost.supplier")}<select value={supplierId} onChange={e => { setSupplierId(e.target.value); setAmounts({}); }} required className={field}><option value="">{t("supplierPaymentPost.select")}</option>{suppliers.map(row => <option key={row.id} value={row.id}>{row.code ? `${row.code} · ` : ""}{row.name}{row.status === "INACTIVE" ? ` · ${t("supplierPaymentPost.inactive")}` : ""}</option>)}</select></label>
      <label>{t("supplierPaymentPost.treasury")}<select value={treasuryId} onChange={e => { setTreasuryId(e.target.value); setAmounts({}); }} required className={field}><option value="">{t("supplierPaymentPost.select")}</option>{master.treasuryAccounts.filter(row => row.companyId === companyId && row.status === "ACTIVE" && master.accounts.some(a => a.id === row.glAccountId && a.status === "ACTIVE" && a.accountType === "ASSET")).map(row => <option key={row.id} value={row.id}>{row.code} · {row.name}</option>)}</select></label>
      <label>{t("supplierPaymentPost.total")}<input name="total" inputMode="decimal" required className={field} /></label>
      <label>{t("supplierPaymentPost.method")}<select name="method" defaultValue="TRANSFER" className={field}>{(["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"] as const).map(value => <option key={value} value={value}>{t(`expenseRead.${value}`)}</option>)}</select></label>
      <label>{t("supplierPaymentPost.externalReference")}<input name="externalReference" maxLength={200} className={field} /></label>
      <label className="sm:col-span-2">{t("supplierPaymentPost.notes")}<textarea name="notes" maxLength={2000} className={field} /></label>
    </fieldset><fieldset disabled={busy || !ready || !supplierId || !treasuryId} className="space-y-3"><legend className="font-medium">{t("supplierPaymentPost.allocations")}</legend>
      {supplierId && treasuryId && eligible.length === 0 && <p role="status">{t("supplierPaymentPost.noEligible")}</p>}
      {eligible.map(row => <label key={row.id} className="grid gap-2 rounded-lg border border-slate-200 p-3 sm:grid-cols-[1fr_11rem]"><span className="min-w-0 break-words"><bdi>{row.expense_reference} · {row.expense_date}</bdi><span className="block text-sm text-slate-600"><bdi>{row.description} · {displayMinor(row.outstanding_amount_minor)} AED</bdi></span></span><input aria-label={`${row.expense_reference} ${t("supplierPaymentPost.allocate")}`} inputMode="decimal" value={amounts[row.id] ?? ""} onChange={e => setAmounts(current => ({ ...current, [row.id]: e.target.value }))} className={field} /></label>)}
    </fieldset><label className="flex items-start gap-2"><input name="confirm" value="yes" type="checkbox" required /><span>{t("supplierPaymentPost.confirm")}</span></label><button type="submit" className={field}>{t("supplierPaymentPost.submit")}</button></form>}
  </section>;
}
