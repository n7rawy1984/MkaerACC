import { useEffect, useRef, useState, type FormEvent } from "react";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import {
  loadRetentionReleaseReverseAttempt,
  retentionReleaseReverseStorageKey,
  saveRetentionReleaseReverseAttempt,
  sendRetentionReleaseReverseAttempt,
  type RetentionReleaseReverseAttempt,
} from "./retentionReleaseReverseAttempt";
import { canReverseRetentionRelease, normalizeRetentionReleaseReverseInput } from "./retentionReleaseReverseRepository";
import { readRetentionReleaseById, type RetentionReleaseRead } from "./retentionReleaseRepository";

export function RetentionReleaseReverseAction({ userId, companyId, role, release, onRefresh }: { userId: string; companyId: string; role: string; release: RetentionReleaseRead; onRefresh: () => void }) {
  const t = useT();
  const [initial] = useState(() => {
    try { return { attempt: loadRetentionReleaseReverseAttempt(window.sessionStorage, userId, companyId, release.id), ready: true }; }
    catch { return { attempt: null, ready: false }; }
  });
  const [open, setOpen] = useState(Boolean(initial.attempt));
  const [attempt, setAttempt] = useState<RetentionReleaseReverseAttempt | null>(initial.attempt);
  const [ready, setReady] = useState(initial.ready);
  const [busy, setBusy] = useState(false);
  const [confirmed, setConfirmed] = useState<RetentionReleaseRead | null>(null);
  const [message, setMessage] = useState<"invalid" | "unresolved" | "rejected" | "readError" | "storageError" | "denied" | null>(initial.ready ? null : "storageError");
  const generation = useRef(0);
  const lock = useRef(false);

  useEffect(() => {
    const { data } = getSupabaseClient().auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) {
        generation.current++;
        setReady(false);
        setAttempt(null);
        setConfirmed(null);
        setMessage("denied");
      }
    });
    const invalidate = () => { generation.current++; };
    return () => { invalidate(); data.subscription.unsubscribe(); };
  }, [userId, companyId, release.id]);

  const recover = async (pending: RetentionReleaseReverseAttempt, firstSend = false) => {
    if (lock.current || !ready || !(role === "ACCOUNTING_ADMIN" && (pending.receipt || canReverseRetentionRelease(role, release.status)))) return;
    lock.current = true;
    setBusy(true);
    setMessage(null);
    const version = generation.current;
    const current = () => generation.current === version;
    let result = pending;
    try {
      result = await sendRetentionReleaseReverseAttempt(getSupabaseClient(), window.sessionStorage, pending, firstSend);
      if (!current()) return;
      setAttempt(result);
      const row = await readRetentionReleaseById(getSupabaseClient(), companyId, result.receipt!.retention_release_id);
      const live = await getSupabaseClient().auth.getSession();
      if (!current()) return;
      if (live.error || live.data.session?.user.id !== userId) {
        setReady(false);
        setAttempt(null);
        setMessage("denied");
        return;
      }
      if (row.status !== "REVERSED" || row.reversal_journal_entry_id !== result.receipt!.reversal_journal_entry_id) throw new Error("readback");
      setConfirmed(row);
      if (release.status === "POSTED") onRefresh();
    } catch (error) {
      if (current()) {
        if (firstSend && error instanceof Error && error.message === "rejected") { setAttempt(null); setMessage("rejected"); }
        else { setAttempt(result); setMessage(result.receipt ? "readError" : "unresolved"); }
      }
    } finally {
      if (current()) { lock.current = false; setBusy(false); }
    }
  };

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (attempt || busy || !ready) return;
    const data = new FormData(event.currentTarget);
    try {
      if (String(data.get("confirm")) !== "yes") throw new Error("invalid");
      const input = normalizeRetentionReleaseReverseInput({ date: String(data.get("date") ?? ""), reason: String(data.get("reason") ?? "") });
      const pending: RetentionReleaseReverseAttempt = { version: 1, userId, companyId, releaseId: release.id, key: crypto.randomUUID(), input };
      saveRetentionReleaseReverseAttempt(window.sessionStorage, pending);
      setAttempt(pending);
      void recover(pending, true);
    } catch (error) {
      setMessage(error instanceof Error && error.message === "invalid" ? "invalid" : "storageError");
    }
  };

  if (!canReverseRetentionRelease(role, release.status) && !attempt) return null;
  const button = "rounded-lg border border-slate-300 px-3 py-2 disabled:opacity-50";
  return <div className="mt-3">{!open ? <button type="button" className={button} onClick={() => setOpen(true)}>{t("retentionReleaseReverse.open")}</button> : <section className="rounded-lg border border-amber-300 p-4" aria-label={t("retentionReleaseReverse.title")}><h4 className="font-semibold">{t("retentionReleaseReverse.title")}</h4><p className="mt-2 text-sm">{t("retentionReleaseReverse.warning")}</p>{message && <p role="alert" className="mt-2 text-red-800">{t(`retentionReleaseReverse.${message}`)}</p>}{busy && <p role="status">{t("retentionReleaseReverse.pending")}</p>}
    {attempt ? <div className="mt-3 space-y-2"><p>{t(attempt.receipt ? "retentionReleaseReverse.confirmed" : "retentionReleaseReverse.frozen")}</p><p>{t("retentionReleaseReverse.request")}: <bdi>{attempt.key}</bdi></p>{attempt.receipt && <p>{t("retentionReleaseReverse.journal")}: <bdi>{attempt.receipt.reversal_journal_entry_id}</bdi></p>}{confirmed && <p role="status"><bdi>{confirmed.release_reference} · {t(`retentionReleaseRead.${confirmed.status}`)}</bdi></p>}<button type="button" className={button} disabled={busy || !ready} onClick={() => void recover(attempt)}>{t(attempt.receipt ? "retentionReleaseReverse.readAgain" : "retentionReleaseReverse.retry")}</button>{attempt.receipt && <button type="button" className={button} disabled={busy || !confirmed} onClick={() => { try { window.sessionStorage.removeItem(retentionReleaseReverseStorageKey(userId, companyId, release.id)); setAttempt(null); setConfirmed(null); setMessage(null); setOpen(false); } catch { setMessage("storageError"); } }}>{t("retentionReleaseReverse.dismiss")}</button>}</div>
    : <form onSubmit={submit} className="mt-3 space-y-3"><label className="block">{t("retentionReleaseReverse.date")}<input name="date" type="date" required className={button} /></label><label className="block">{t("retentionReleaseReverse.reason")}<textarea name="reason" required maxLength={1000} className="block w-full rounded-lg border p-2" /></label><label className="flex gap-2"><input name="confirm" value="yes" type="checkbox" required />{t("retentionReleaseReverse.confirmCheck")}</label><div className="flex gap-2"><button type="submit" className={button}>{t("retentionReleaseReverse.confirm")}</button><button type="button" className={button} onClick={() => { setOpen(false); setMessage(null); }}>{t("retentionReleaseReverse.cancel")}</button></div></form>}</section>}</div>;
}
