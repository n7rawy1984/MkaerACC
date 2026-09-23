import { useEffect, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "../master/productionMasterDataContext";
import { canPostExpense, normalizeExpenseInput, parseAED, type TreasuryExpenseInput } from "./expensePostRepository";
import { attemptStorageKey, loadAttempt, saveAttempt, sendAttempt, type ExpenseAttempt } from "./expensePostAttempt";
import { displayMinor, readExpenseById, type ExpenseRead } from "./expenseRepository";

export function TreasuryExpensePost({ userId, companyId, role, onPosted }: { userId: string; companyId: string; role: string; onPosted: () => void }) {
  const t = useT();
  const master = useProductionMasterData();
  // Parent keys this component by actor/Company/role; restore only that scope.
  const [initial] = useState(() => {
    try { return { attempt: loadAttempt(window.sessionStorage, userId, companyId), ready: true }; }
    catch { return { attempt: null, ready: false }; }
  });
  const [attempt, setAttempt] = useState<ExpenseAttempt | null>(initial.attempt);
  const [ready, setReady] = useState(initial.ready);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const [posted, setPosted] = useState<ExpenseRead | null>(null);
  const [project, setProject] = useState("");
  const [vat, setVat] = useState<TreasuryExpenseInput["vatMode"]>("ZERO");
  const [invoice, setInvoice] = useState(false);
  const [formKey, setFormKey] = useState(0);
  const generation = useRef(0);
  const lock = useRef(false);
  useEffect(() => {
    const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) {
        generation.current++; setReady(false); setPosted(null); setAttempt(null); setMessage("denied");
      }
    });
    // This mutable counter deliberately invalidates every outstanding operation.
    const invalidate = () => { generation.current++; };
    return () => { invalidate(); data.subscription.unsubscribe(); };
  }, [userId, companyId]);
  const recover = async (pending: ExpenseAttempt, firstSend = false) => {
    if (lock.current || !ready || !canPostExpense(role)) return;
    lock.current = true; setBusy(true); setMessage(null);
    const version = generation.current;
    const current = () => generation.current === version;
    let confirmed = pending;
    try {
      confirmed = await sendAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend);
      if (!current()) return;
      const { data, error } = await getSupabaseClient().auth.getSession();
      if (!current()) return;
      if (error || data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setAttempt(confirmed);
      onPosted(); // Expense READ only; never refresh masters or settings.
      const row = await readExpenseById(getSupabaseClient(), companyId, confirmed.receipt!.expense_id);
      const live = await getSupabaseClient().auth.getSession();
      if (!current()) return;
      if (live.error || live.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      if (row.posted_journal_entry_id !== confirmed.receipt!.journal_entry_id || row.funding_mode !== "TREASURY") throw new Error("readback");
      setPosted(row);
    } catch (error) {
      if (current()) {
        if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); }
        else { setAttempt(confirmed); setMessage(confirmed.receipt ? "readError" : "unresolved"); }
      }
    } finally { if (current()) { lock.current = false; setBusy(false); } }
  };
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (lock.current || attempt || busy || !ready || master.phase !== "READY" || !canPostExpense(role)) return;
    const data = new FormData(event.currentTarget);
    const value = (name: string) => String(data.get(name) ?? "");
    try {
      const input = normalizeExpenseInput({ date: value("date"), projectId: project || null, categoryId: value("category"),
        supplierId: value("supplier") || null, treasuryId: value("treasury"), description: value("description"),
        netMinor: parseAED(value("net")), vatMode: vat, manualVatMinor: vat === "MANUAL" ? parseAED(value("manualVat")) : null,
        paymentMethod: value("method") as TreasuryExpenseInput["paymentMethod"], hasInvoice: invoice,
        invoiceNumber: invoice ? value("invoice") : null, notes: value("notes") || null });
      // Selection checks use current scoped master snapshots; DB checks remain final.
      if (!master.expenseCategories.some(r => r.companyId === companyId && r.id === input.categoryId && r.status === "ACTIVE")
        || !master.treasuryAccounts.some(r => r.companyId === companyId && r.id === input.treasuryId && r.status === "ACTIVE" && (r.projectId === null || r.projectId === input.projectId))
        || (input.projectId && !master.projects.some(r => r.companyId === companyId && r.id === input.projectId && r.status !== "CLOSED"))
        || (input.supplierId && !master.parties.some(r => r.companyId === companyId && r.id === input.supplierId && r.type === "SUPPLIER" && r.status === "ACTIVE"))) throw new Error("invalid");
      const pending: ExpenseAttempt = { version: 1, userId, companyId, key: crypto.randomUUID(), input };
      saveAttempt(window.sessionStorage, pending);
      setAttempt(pending); void recover(pending, true);
    } catch (error) { setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError"); }
  };
  if (!canPostExpense(role)) return null;
  const field = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2";
  return <section className="mt-5 min-w-0 rounded-xl border border-slate-200 p-4" aria-label={t("expensePost.title")}>
    <h3 className="font-semibold">{t("expensePost.title")}</h3>
    <p className="mt-2 text-sm text-slate-600">{t("expensePost.scope")}</p>
    {message && <p role="alert" className="mt-3 break-words text-red-800">{t(`expensePost.${message}`)}</p>}
    {busy && <p role="status">{t("expensePost.pending")}</p>}
    {attempt ? <div className="mt-3 space-y-3 break-words">
      <p>{t(attempt.receipt ? "expensePost.confirmed" : "expensePost.frozen")}</p>
      <p><bdi>{attempt.input.description} · {displayMinor(attempt.input.netMinor)} AED</bdi></p>
      <p>{t("expensePost.request")}: <bdi>{attempt.key}</bdi></p>
      {attempt.receipt && <p><bdi>{attempt.receipt.expense_reference} · {attempt.receipt.journal_entry_id}</bdi></p>}
      {posted && <p role="status">{t("expensePost.readback")}: <bdi>{displayMinor(posted.net_amount_minor)} / {displayMinor(posted.vat_amount_minor)} / {displayMinor(posted.gross_amount_minor)} AED</bdi> · {t(`expenseRead.${posted.status}`)}</p>}
      <button type="button" disabled={busy || !ready} className={field} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "expensePost.readAgain" : "expensePost.retry")}</button>
      {attempt.receipt && <button type="button" disabled={busy || !ready || !posted} className={field} onClick={() => {
        try { window.sessionStorage.removeItem(attemptStorageKey(userId, companyId)); setAttempt(null); setPosted(null); setMessage(null); setProject(""); setVat("ZERO"); setInvoice(false); setFormKey(value => value + 1); }
        catch { setMessage("storageError"); }
      }}>{t("expensePost.new")}</button>}
    </div> : master.phase !== "READY" ? <p role="status">{t("expensePost.masters")}</p> : <form key={formKey} onSubmit={submit} className="mt-4" aria-label={t("expensePost.title")}>
      <fieldset disabled={busy || !ready} className="grid min-w-0 gap-3 sm:grid-cols-2">
        <label>{t("expensePost.date")}<input name="date" type="date" required className={field} /></label>
        <label>{t("expensePost.project")}<select value={project} onChange={e => setProject(e.target.value)} className={field}><option value="">{t("expensePost.companyCost")}</option>{master.projects.filter(r => r.companyId === companyId && r.status !== "CLOSED").map(r => <option key={r.id} value={r.id}>{r.code} · {r.name}</option>)}</select></label>
        <label>{t("expensePost.category")}<select name="category" required className={field} defaultValue=""><option value="">{t("expensePost.select")}</option>{master.expenseCategories.filter(r => r.companyId === companyId && r.status === "ACTIVE").map(r => <option key={r.id} value={r.id}>{r.code} · {r.name}</option>)}</select></label>
        <label>{t("expensePost.treasury")}<select name="treasury" key={project} required className={field} defaultValue=""><option value="">{t("expensePost.select")}</option>{master.treasuryAccounts.filter(r => r.companyId === companyId && r.status === "ACTIVE" && (r.projectId === null || r.projectId === project)).map(r => <option key={r.id} value={r.id}>{r.code} · {r.name}</option>)}</select></label>
        <label>{t("expensePost.supplier")}<select name="supplier" className={field} defaultValue=""><option value="">{t("expenseRead.absent")}</option>{master.parties.filter(r => r.companyId === companyId && r.type === "SUPPLIER" && r.status === "ACTIVE").map(r => <option key={r.id} value={r.id}>{r.name}</option>)}</select></label>
        <label>{t("expensePost.net")}<input name="net" required inputMode="decimal" placeholder="0.00" className={field} /></label>
        <label>{t("expensePost.vat")}<select value={vat} onChange={e => { const mode = e.target.value as TreasuryExpenseInput["vatMode"]; setVat(mode); if (mode !== "ZERO") setInvoice(true); }} className={field}>{(["ZERO", "AUTO_5", "MANUAL"] as const).map(v => <option key={v} value={v}>{t(`expenseRead.${v}`)}</option>)}</select></label>
        {vat === "MANUAL" && <label>{t("expensePost.manualVat")}<input name="manualVat" required inputMode="decimal" className={field} /></label>}
        <label>{t("expenseRead.method")}<select name="method" className={field}>{(["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"] as const).map(v => <option key={v} value={v}>{t(`expenseRead.${v}`)}</option>)}</select></label>
        <label className="self-center"><input type="checkbox" checked={invoice} disabled={vat !== "ZERO"} onChange={e => setInvoice(e.target.checked)} /> {t("expenseRead.invoice")}</label>
        {invoice && <label>{t("expenseRead.invoice_number")}<input name="invoice" required maxLength={100} className={field} /></label>}
        <label className="sm:col-span-2">{t("expensePost.description")}<textarea name="description" required maxLength={1000} className={field} /></label>
        <label className="sm:col-span-2">{t("expenseRead.notes")}<textarea name="notes" maxLength={2000} className={field} /></label>
        <button type="submit" className="rounded-lg bg-slate-900 px-4 py-2 text-white">{t("expensePost.submit")}</button>
      </fieldset>
    </form>}
  </section>;
}
