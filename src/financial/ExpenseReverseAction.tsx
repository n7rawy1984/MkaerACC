import { useEffect, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { readExpenseById, type ExpenseRead } from "./expenseRepository";
import { expenseReverseStorageKey, loadExpenseReverseAttempt, saveExpenseReverseAttempt, sendExpenseReverseAttempt,
  type ExpenseReverseAttempt } from "./expenseReverseAttempt";
import { canReverseExpense, normalizeExpenseReverseInput, type ExpenseReverseReceipt } from "./expenseReverseRepository";

export function ExpenseReverseAction({ userId, companyId, role, expense, onRefresh }: {
  userId: string; companyId: string; role: string; expense: ExpenseRead; onRefresh: () => void;
}) {
  const t = useT();
  const [initial] = useState(() => {
    try {
      let attempt = loadExpenseReverseAttempt(window.sessionStorage, userId, companyId, expense.id);
      let posted: ExpenseRead | null = null;
      if (attempt && !attempt.receipt && expense.status === "REVERSED" && expense.reversal_journal_entry_id) {
        const receipt: ExpenseReverseReceipt = { expense_id: expense.id, expense_reference: expense.expense_reference,
          reversal_journal_entry_id: expense.reversal_journal_entry_id, replayed: false };
        attempt = { ...attempt, receipt }; saveExpenseReverseAttempt(window.sessionStorage, attempt); posted = expense;
      } else if (attempt?.receipt && expense.status === "REVERSED"
        && attempt.receipt.reversal_journal_entry_id === expense.reversal_journal_entry_id) posted = expense;
      return { attempt, posted, ready: true };
    } catch { return { attempt: null, posted: null, ready: false }; }
  });
  const [attempt, setAttempt] = useState<ExpenseReverseAttempt | null>(initial.attempt);
  const [posted, setPosted] = useState<ExpenseRead | null>(initial.posted);
  const [ready, setReady] = useState(initial.ready);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const generation = useRef(0);
  const lock = useRef(false);

  useEffect(() => {
    const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) {
        generation.current++; setReady(false); setAttempt(null); setPosted(null); setMessage("denied");
      }
    });
    const invalidate = () => { generation.current++; };
    return () => { invalidate(); data.subscription.unsubscribe(); };
  }, [userId, companyId, expense.id]);

  const recover = async (pending: ExpenseReverseAttempt, firstSend = false) => {
    if (lock.current || !ready || role !== "ACCOUNTING_ADMIN") return;
    lock.current = true; setBusy(true); setMessage(null);
    const version = generation.current;
    const current = () => generation.current === version;
    let confirmed = pending;
    try {
      confirmed = await sendExpenseReverseAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend);
      if (!current()) return;
      const session = await getSupabaseClient().auth.getSession();
      if (!current()) return;
      if (session.error || session.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      setAttempt(confirmed);
      const row = await readExpenseById(getSupabaseClient(), companyId, expense.id);
      const live = await getSupabaseClient().auth.getSession();
      if (!current()) return;
      if (live.error || live.data.session?.user.id !== userId) { setReady(false); setAttempt(null); setMessage("denied"); return; }
      if (row.status !== "REVERSED" || row.posted_journal_entry_id !== expense.posted_journal_entry_id
        || row.reversal_journal_entry_id !== confirmed.receipt!.reversal_journal_entry_id) throw new Error("readback");
      setPosted(row); onRefresh();
    } catch (error) {
      if (current()) {
        if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); onRefresh(); }
        else { setAttempt(confirmed); setMessage(confirmed.receipt ? "readError" : "unresolved"); }
      }
    } finally { if (current()) { lock.current = false; setBusy(false); } }
  };

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (lock.current || attempt || busy || !ready || !canReverseExpense(role, expense.status)) return;
    const data = new FormData(event.currentTarget);
    try {
      if (data.get("confirmed") !== "yes") throw new Error("invalid");
      const input = normalizeExpenseReverseInput({ date: String(data.get("date") ?? ""), reason: String(data.get("reason") ?? "") });
      const pending: ExpenseReverseAttempt = { version: 1, userId, companyId, expenseId: expense.id, key: crypto.randomUUID(), input };
      saveExpenseReverseAttempt(window.sessionStorage, pending);
      setAttempt(pending); setConfirming(false); void recover(pending, true);
    } catch (error) { setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError"); }
  };

  if (role !== "ACCOUNTING_ADMIN" || (expense.status !== "POSTED" && !attempt)) return null;
  const field = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2";
  return <section className="mt-3 rounded-lg border border-red-200 p-3" aria-label={t("expenseReverse.title")}>
    {message && <p role="alert" className="mb-2 break-words text-red-800">{t(`expenseReverse.${message}`)}</p>}
    {busy && <p role="status">{t("expenseReverse.pending")}</p>}
    {attempt ? <div className="space-y-2 break-words">
      <p>{t(posted ? "expenseReverse.confirmed" : attempt.receipt ? "expenseReverse.readError" : "expenseReverse.frozen")}</p>
      <p>{t("expenseReverse.request")}: <bdi>{attempt.key}</bdi></p>
      {(posted?.reversal_journal_entry_id || attempt.receipt?.reversal_journal_entry_id) && <p>{t("expenseReverse.journal")}: <bdi>{posted?.reversal_journal_entry_id ?? attempt.receipt!.reversal_journal_entry_id}</bdi></p>}
      {!posted && <button type="button" disabled={busy || !ready} className={field} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "expenseReverse.readAgain" : "expenseReverse.retry")}</button>}
      {posted && <button type="button" className={field} onClick={() => {
        try { window.sessionStorage.removeItem(expenseReverseStorageKey(userId, companyId, expense.id)); setAttempt(null); setPosted(null); setMessage(null); }
        catch { setMessage("storageError"); }
      }}>{t("expenseReverse.dismiss")}</button>}
    </div> : confirming ? <form onSubmit={submit} className="space-y-3" aria-label={t("expenseReverse.confirmTitle")}>
      <p className="text-sm text-red-900">{t("expenseReverse.warning")}</p>
      <label>{t("expenseReverse.date")}<input name="date" type="date" required className={field} /></label>
      <label>{t("expenseReverse.reason")}<textarea name="reason" required maxLength={1000} className={field} /></label>
      <label><input name="confirmed" type="checkbox" value="yes" required /> {t("expenseReverse.confirmCheck")}</label>
      <div className="flex flex-wrap gap-2"><button type="submit" className="rounded-lg bg-red-800 px-3 py-2 text-white">{t("expenseReverse.confirm")}</button>
        <button type="button" className="rounded-lg border px-3 py-2" onClick={() => { setConfirming(false); setMessage(null); }}>{t("expenseReverse.cancel")}</button></div>
    </form> : <button type="button" disabled={!ready} className="rounded-lg border border-red-700 px-3 py-2 text-red-800 disabled:opacity-50" onClick={() => setConfirming(true)}>{t("expenseReverse.open")}</button>}
  </section>;
}
