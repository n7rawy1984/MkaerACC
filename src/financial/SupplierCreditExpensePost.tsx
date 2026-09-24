import { useEffect, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "../master/productionMasterDataContext";
import { canPostExpense, parseAED } from "./expensePostRepository";
import { displayMinor, readExpenseById, type ExpenseRead } from "./expenseRepository";
import { readSupplierPayments } from "./supplierPaymentRepository";
import { loadSupplierCreditExpenseAttempt, saveSupplierCreditExpenseAttempt, sendSupplierCreditExpenseAttempt, supplierCreditExpenseAttemptStorageKey, type SupplierCreditExpenseAttempt } from "./supplierCreditExpensePostAttempt";
import { normalizeSupplierCreditExpenseInput, type SupplierCreditExpenseInput } from "./supplierCreditExpensePostRepository";

export function SupplierCreditExpensePost({ userId, companyId, role, onPosted }: { userId: string; companyId: string; role: string; onPosted: () => void }) {
  const t = useT(); const master = useProductionMasterData();
  const [initial] = useState(() => { try { return { attempt: loadSupplierCreditExpenseAttempt(window.sessionStorage, userId, companyId), ready: true }; } catch { return { attempt: null, ready: false }; } });
  const [attempt, setAttempt] = useState<SupplierCreditExpenseAttempt | null>(initial.attempt); const [ready, setReady] = useState(initial.ready); const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "outstandingError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const [posted, setPosted] = useState<ExpenseRead | null>(null); const [outstandingConfirmed, setOutstandingConfirmed] = useState(false); const [project, setProject] = useState("");
  const [vat, setVat] = useState<SupplierCreditExpenseInput["vatMode"]>("ZERO"); const [invoice, setInvoice] = useState(false); const [formKey, setFormKey] = useState(0); const generation = useRef(0); const lock = useRef(false);
  useEffect(() => { const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => { if (event === "SIGNED_OUT" || !session || session.user.id !== userId) { generation.current++; setReady(false); setAttempt(null); setPosted(null); setOutstandingConfirmed(false); setMessage("denied"); } }); const invalidate = () => { generation.current++; }; return () => { invalidate(); data.subscription.unsubscribe(); }; }, [userId, companyId]);
  const recover = async (pending: SupplierCreditExpenseAttempt, firstSend = false) => {
    if (lock.current || !ready || !canPostExpense(role)) return; lock.current = true; setBusy(true); setMessage(null); const version = generation.current; const current = () => generation.current === version; let confirmed = pending;
    try { confirmed = await sendSupplierCreditExpenseAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend); if (!current()) return;
      const session = await getSupabaseClient().auth.getSession(); if (!current()) return; if (session.error || session.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setAttempt(confirmed); const row = await readExpenseById(getSupabaseClient(), companyId, confirmed.receipt!.expense_id); if (!current()) return;
      if (row.posted_journal_entry_id !== confirmed.receipt!.journal_entry_id || row.funding_mode !== "SUPPLIER_CREDIT" || row.supplier_id !== pending.input.supplierId) throw new Error("readback"); setPosted(row); onPosted();
      const snapshot = await readSupplierPayments(getSupabaseClient(), companyId); if (!current()) return;
      const due = snapshot.outstanding.find(item => item.id === row.id && item.supplier_id === row.supplier_id);
      if (!due || due.outstanding_amount_minor !== row.gross_amount_minor) { setOutstandingConfirmed(false); setMessage("outstandingError"); return; }
      const live = await getSupabaseClient().auth.getSession(); if (!current()) return; if (live.error || live.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setOutstandingConfirmed(true);
    } catch (error) { if (current()) { if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); } else { setAttempt(confirmed); setMessage(confirmed.receipt ? "readError" : "unresolved"); } } }
    finally { if (current()) { lock.current = false; setBusy(false); } }
  };
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (lock.current || attempt || busy || !ready || master.phase !== "READY" || !canPostExpense(role)) return; const data = new FormData(event.currentTarget); const value = (name: string) => String(data.get(name) ?? "");
    try { const input = normalizeSupplierCreditExpenseInput({ date: value("date"), projectId: project || null, categoryId: value("category"), supplierId: value("supplier"), description: value("description"), netMinor: parseAED(value("net")), vatMode: vat,
        manualVatMinor: vat === "MANUAL" ? parseAED(value("manualVat")) : null, paymentMethod: value("method") as SupplierCreditExpenseInput["paymentMethod"], hasInvoice: invoice, invoiceNumber: invoice ? value("invoice") : null, notes: value("notes") || null });
      if (!master.expenseCategories.some(row => row.companyId === companyId && row.id === input.categoryId && row.status === "ACTIVE")
        || !master.parties.some(row => row.companyId === companyId && row.id === input.supplierId && row.type === "SUPPLIER" && row.status === "ACTIVE")
        || (input.projectId && !master.projects.some(row => row.companyId === companyId && row.id === input.projectId && row.status !== "CLOSED"))) throw new Error("invalid");
      const pending: SupplierCreditExpenseAttempt = { version: 1, userId, companyId, key: crypto.randomUUID(), input }; saveSupplierCreditExpenseAttempt(window.sessionStorage, pending); setAttempt(pending); void recover(pending, true);
    } catch (error) { setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError"); }
  };
  if (!canPostExpense(role)) return null; const field = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2";
  return <section className="mt-5 min-w-0 rounded-xl border border-slate-200 p-4" aria-label={t("supplierCreditPost.title")}><h3 className="font-semibold">{t("supplierCreditPost.title")}</h3><p className="mt-2 text-sm text-slate-600">{t("supplierCreditPost.scope")}</p>
    {message && <p role="alert" className="mt-3 break-words text-red-800">{t(`supplierCreditPost.${message}`)}</p>}{busy && <p role="status">{t("supplierCreditPost.pending")}</p>}
    {attempt ? <div className="mt-3 space-y-3 break-words"><p>{t(attempt.receipt ? "supplierCreditPost.confirmed" : "supplierCreditPost.frozen")}</p><p><bdi>{attempt.input.description} · {displayMinor(attempt.input.netMinor)} AED</bdi></p><p>{t("supplierCreditPost.request")}: <bdi>{attempt.key}</bdi></p>{attempt.receipt && <p><bdi>{attempt.receipt.expense_reference} · {attempt.receipt.journal_entry_id}</bdi></p>}{posted && <p role="status">{t("supplierCreditPost.readback")}: <bdi>{displayMinor(posted.net_amount_minor)} / {displayMinor(posted.vat_amount_minor)} / {displayMinor(posted.gross_amount_minor)} AED</bdi></p>}{outstandingConfirmed && <p role="status">{t("supplierCreditPost.outstandingConfirmed")}</p>}
      <button type="button" disabled={busy || !ready} className={field} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "supplierCreditPost.readAgain" : "supplierCreditPost.retry")}</button>
      {attempt.receipt && <button type="button" disabled={busy || !ready || !posted || !outstandingConfirmed} className={field} onClick={() => { try { window.sessionStorage.removeItem(supplierCreditExpenseAttemptStorageKey(userId, companyId)); setAttempt(null); setPosted(null); setOutstandingConfirmed(false); setMessage(null); setProject(""); setVat("ZERO"); setInvoice(false); setFormKey(value => value + 1); } catch { setMessage("storageError"); } }}>{t("supplierCreditPost.new")}</button>}
    </div> : master.phase !== "READY" ? <p role="status">{t("supplierCreditPost.masters")}</p> : <form key={formKey} onSubmit={submit} className="mt-4" aria-label={t("supplierCreditPost.title")}><fieldset disabled={busy || !ready} className="grid min-w-0 gap-3 sm:grid-cols-2">
      <label>{t("expensePost.date")}<input name="date" type="date" required className={field} /></label><label>{t("expensePost.project")}<select value={project} onChange={event => setProject(event.target.value)} className={field}><option value="">{t("expensePost.companyCost")}</option>{master.projects.filter(row => row.companyId === companyId && row.status !== "CLOSED").map(row => <option key={row.id} value={row.id}>{row.code} · {row.name}</option>)}</select></label>
      <label>{t("expensePost.category")}<select name="category" required defaultValue="" className={field}><option value="">{t("expensePost.select")}</option>{master.expenseCategories.filter(row => row.companyId === companyId && row.status === "ACTIVE").map(row => <option key={row.id} value={row.id}>{row.code} · {row.name}</option>)}</select></label>
      <label>{t("expensePost.supplier")}<select name="supplier" required defaultValue="" className={field}><option value="">{t("expensePost.select")}</option>{master.parties.filter(row => row.companyId === companyId && row.type === "SUPPLIER" && row.status === "ACTIVE").map(row => <option key={row.id} value={row.id}>{row.code ? `${row.code} · ` : ""}{row.name}</option>)}</select></label>
      <label>{t("expensePost.net")}<input name="net" required inputMode="decimal" placeholder="0.00" className={field} /></label><label>{t("expensePost.vat")}<select value={vat} onChange={event => { const mode = event.target.value as SupplierCreditExpenseInput["vatMode"]; setVat(mode); if (mode !== "ZERO") setInvoice(true); }} className={field}>{(["ZERO", "AUTO_5", "MANUAL"] as const).map(value => <option key={value} value={value}>{t(`expenseRead.${value}`)}</option>)}</select></label>
      {vat === "MANUAL" && <label>{t("expensePost.manualVat")}<input name="manualVat" required inputMode="decimal" className={field} /></label>}
      <label>{t("expenseRead.method")}<select name="method" required defaultValue="" className={field}><option value="">{t("expensePost.select")}</option>{(["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"] as const).map(value => <option key={value} value={value}>{t(`expenseRead.${value}`)}</option>)}</select></label>
      <label className="self-center"><input type="checkbox" checked={invoice} disabled={vat !== "ZERO"} onChange={event => setInvoice(event.target.checked)} /> {t("expenseRead.invoice")}</label>{invoice && <label>{t("expenseRead.invoice_number")}<input name="invoice" required maxLength={100} className={field} /></label>}
      <label className="sm:col-span-2">{t("expensePost.description")}<textarea name="description" required maxLength={1000} className={field} /></label><label className="sm:col-span-2">{t("expenseRead.notes")}<textarea name="notes" maxLength={2000} className={field} /></label>
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 font-medium text-white sm:col-span-2">{t("supplierCreditPost.submit")}</button>
    </fieldset></form>}
  </section>;
}
