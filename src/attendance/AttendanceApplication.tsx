import { useTenantSettings } from "../tenant/TenantSettingsContext";
import { TenantBrandMark } from "../tenant/TenantBrandMark";
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { LanguageButton } from '../auth/AuthFrame';
import { useI18n } from '../i18n/I18nContext';
import { getSupabaseClient } from '../lib/supabase';
import { attendanceText, type AttendanceLabels } from './attendanceText';
import { absenceHalfUnits, attendanceRequest, attendanceRole, attendanceStaff, canCorrectAttendance, exceptionInput,
 type AttendanceContext, type AttendanceEntry, type DaySnapshot, type MonthSnapshot, type Named, type SiteAssignment } from './attendanceRepository';

const field = 'block w-full min-w-0 rounded border border-slate-300 bg-white p-2';
const button = 'rounded border border-slate-300 px-3 py-2 disabled:opacity-50';
export default function AttendanceApplication() {
 const { state, signOut, showCompanySelector } = useAuth();
 const { locale } = useI18n(); const t = attendanceText[locale];
 const branding = useTenantSettings();
 const displayName = branding.phase === 'READY' ? branding.settings.effectiveDisplayName : state.phase === 'TENANT_READY' ? state.activeTenant.companyName : '';
 if (state.phase !== 'TENANT_READY') return null;
 return <div className="min-h-screen bg-slate-50 p-4 sm:p-6"><header className="mx-auto mb-6 flex max-w-5xl flex-wrap items-center justify-between gap-3">
  <div className="flex min-w-0 items-center gap-3"><TenantBrandMark logoUrl={branding.phase === "READY" ? branding.settings.logoUrl : null}/><h1 className="min-w-0 break-words text-xl font-semibold"><bdi>{displayName}</bdi> · {t.title}</h1></div><div className="flex flex-wrap gap-2">
  {state.activeTenant.role !== 'FOREMAN' && <Link className={button} to="/">{t.back}</Link>}
  {state.memberships.length > 1 && <button className={button} onClick={showCompanySelector}>{t.switchCompany}</button>}
  <LanguageButton /><button className={button} onClick={() => void signOut()}>{t.signOut}</button></div></header>
  <AttendanceContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`}
   userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />
 </div>;
}
export function AttendanceContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
 const { locale } = useI18n(); const t = attendanceText[locale];
 const [loaded, setLoaded] = useState<{ revision: number; data: AttendanceContext } | null>(null);
 const [project, setProject] = useState(''); const [date, setDate] = useState(''); const [month, setMonth] = useState('');
 const [tab, setTab] = useState<'day' | 'review'>('day'); const [revision, setRevision] = useState(0);
 const [errorRevision, setErrorRevision] = useState<number | null>(null);
 const context = loaded?.revision === revision ? loaded.data : null; const error = errorRevision === revision;
 useEffect(() => {
  let current = true;
  if (!attendanceRole(role)) return;
  attendanceRequest(getSupabaseClient(), userId, 'attendance_context', { target_company_id: companyId }, () => current).then(data => {
   if (!current) return; const value = data as unknown as AttendanceContext;
   setLoaded({ revision, data: value }); setProject(old => value.projects.some(p => p.id === old) ? old : value.projects[0]?.id ?? '');
   setDate(old => old || value.today); setMonth(old => old || value.today.slice(0, 7));
  }).catch(() => { if (current) setErrorRevision(revision); });
  return () => { current = false; };
 }, [userId, companyId, role, revision]);
 if (!attendanceRole(role)) return <p role="alert">{t.denied}</p>;
 return <main className="mx-auto max-w-5xl space-y-4 rounded-xl border bg-white p-4 sm:p-6">
  <p>{t.scope}</p><p className="text-sm text-slate-500">{t.utc}</p>
  <div className="flex flex-wrap gap-2"><button className={button} onClick={() => setTab('day')}>{t.day}</button>
   {attendanceStaff(role) && <button className={button} onClick={() => setTab('review')}>{t.review}</button>}
   <button className={button} onClick={() => setRevision(v => v + 1)}>{t.refresh}</button></div>
  {error && <p role="alert" className="text-red-800">{t.error}</p>}
  {!context && !error && <p role="status">{t.loading}</p>}
  {context && (tab === 'day' ? <><div className="grid gap-3 sm:grid-cols-2">
   <label>{t.project}<select className={field} value={project} onChange={e => setProject(e.target.value)}><option value="">{t.select}</option>{context.projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
   <label>{t.date}<input dir="ltr" className={field} type="date" value={date} max={context.today} onChange={e => setDate(e.target.value)} /></label></div>
   {project && date && date <= context.today && <DayPanel key={`${project}:${date}`} userId={userId} companyId={companyId} role={role} project={project} date={date} t={t} />}
  </> : <><label className="block max-w-xs">{t.month}<input dir="ltr" className={field} type="month" value={month} max={context.today.slice(0, 7)} onChange={e => setMonth(e.target.value)} /></label>
   {month && <MonthPanel key={month} userId={userId} companyId={companyId} role={role} month={`${month}-01`} context={context} t={t} />}</>)}
 </main>;
}
function DayPanel({ userId, companyId, role, project, date, t }: { userId: string; companyId: string; role: string; project: string; date: string; t: AttendanceLabels }) {
 const [loaded, setLoaded] = useState<{ revision: number; data: DaySnapshot } | null>(null); const [errorRevision, setErrorRevision] = useState<number | null>(null); const [revision, setRevision] = useState(0);
 const snapshot = loaded?.revision === revision ? loaded.data : null; const error = errorRevision === revision;
 useEffect(() => { let current = true;
  attendanceRequest(getSupabaseClient(), userId, 'attendance_day', { target_company_id: companyId, target_project_id: project, target_date: date }, () => current)
   .then(data => { if (current) setLoaded({ revision, data: data as unknown as DaySnapshot }); }).catch(() => { if (current) setErrorRevision(revision); });
  return () => { current = false; };
 }, [userId, companyId, project, date, revision]);
 if (error) return <><p role="alert">{t.error}</p><button className={button} onClick={() => setRevision(v => v + 1)}>{t.refresh}</button></>;
 if (!snapshot) return <p role="status">{t.loading}</p>;
 return <section className="space-y-3">{snapshot.locked && <p role="status">{t.locked}</p>}
  {!snapshot.rows.length && <p>{t.empty}</p>}{snapshot.rows.map(row => <article key={`${row.employee_id}:${row.entry?.version ?? 0}`} className="rounded border p-3">
   <h2 className="font-semibold"><bdi>{row.employee_name}</bdi></h2>
   <p>{!row.entry ? t.present : row.entry.voided ? t.voided : row.entry.kind === 'HALF_DAY' ? t.half : t.full}</p>
   {row.entry && <details><summary>{t.history}</summary><p className="break-all">{t.recorded}: {row.entry.created_by} · {row.entry.created_at}</p><p className="break-all">{t.updated}: {row.entry.updated_by} · {row.entry.updated_at}</p><p>{row.entry.note}</p><p>{row.entry.correction_reason}</p></details>}
   {canCorrectAttendance(role, userId, row.entry, snapshot.locked) && <ExceptionForm userId={userId} companyId={companyId} project={project} date={date} employeeId={row.employee_id} entry={row.entry} t={t} onRefresh={() => setRevision(v => v + 1)} />}
  </article>)}
 </section>;
}
function ExceptionForm({ userId, companyId, project, date, employeeId, entry, t, onRefresh }: {
 userId: string; companyId: string; project: string; date: string; employeeId: string; entry: AttendanceEntry | null; t: AttendanceLabels; onRefresh: () => void;
}) {
 const [kind, setKind] = useState(entry?.kind ?? 'HALF_DAY'); const [note, setNote] = useState(entry?.note ?? ''); const [reason, setReason] = useState('');
 const [busy, setBusy] = useState(false); const [failed, setFailed] = useState(false); const sending = useRef(false);
 const mounted = useRef(true); useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
 async function save(voided: boolean) {
  if (sending.current || failed) return; sending.current = true; setBusy(true);
  try {
   const args = exceptionInput(companyId, project, employeeId, date, kind, note, entry, voided, reason);
   await attendanceRequest(getSupabaseClient(), userId, 'save_attendance_exception', args, () => mounted.current);
   if (mounted.current) onRefresh();
  } catch { if (mounted.current) setFailed(true); }
  finally { sending.current = false; if (mounted.current) setBusy(false); }
 }
 return <form className="mt-3 space-y-2" onSubmit={e => { e.preventDefault(); void save(false); }}>
  <fieldset disabled={busy || failed} className="space-y-2"><label>{t.day}<select className={field} value={kind} onChange={e => setKind(e.target.value as 'HALF_DAY' | 'FULL_DAY')}><option value="HALF_DAY">{t.half}</option><option value="FULL_DAY">{t.full}</option></select></label>
  <label className="block">{t.note}<input className={field} maxLength={1000} value={note} onChange={e => setNote(e.target.value)} /></label>
  {entry && <label className="block">{t.reason}<input className={field} required maxLength={1000} value={reason} onChange={e => setReason(e.target.value)} /></label>}
  <div className="flex flex-wrap gap-2"><button className={button} disabled={!!entry && !reason.trim()}>{entry ? t.correct : t.save}</button>
   {entry && !entry.voided && <button className={button} type="button" disabled={!reason.trim()} onClick={() => void save(true)}>{t.void}</button>}</div></fieldset>
  {failed && <><p role="alert">{t.error}</p><button className={button} type="button" onClick={onRefresh}>{t.refresh}</button></>}
 </form>;
}
function MonthPanel({ userId, companyId, role, month, context, t }: { userId: string; companyId: string; role: string; month: string; context: AttendanceContext; t: AttendanceLabels }) {
 const [loaded, setLoaded] = useState<{ revision: number; data: MonthSnapshot } | null>(null); const [revision, setRevision] = useState(0); const [errorRevision, setErrorRevision] = useState<number | null>(null);
 const snapshot = loaded?.revision === revision ? loaded.data : null; const error = errorRevision === revision;
 const [confirmedRevision, setConfirmedRevision] = useState<number | null>(null); const confirmed = confirmedRevision === revision; const [busy, setBusy] = useState(false); const mounted = useRef(true); const sending = useRef(false);
 useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
 const refresh = () => { if (mounted.current) setRevision(v => v + 1); };
 useEffect(() => { let current = true;
  attendanceRequest(getSupabaseClient(), userId, 'attendance_month', { target_company_id: companyId, target_month: month }, () => current)
   .then(data => { if (current) setLoaded({ revision, data: data as unknown as MonthSnapshot }); }).catch(() => { if (current) setErrorRevision(revision); });
  return () => { current = false; };
 }, [userId, companyId, month, revision]);
 async function confirm() {
  if (!snapshot || !confirmed || sending.current) return; sending.current = true; setBusy(true);
  try { await attendanceRequest(getSupabaseClient(), userId, 'confirm_attendance_review', { target_company_id: companyId, target_month: month, target_revision: snapshot.period.revision }, () => mounted.current); refresh(); }
  catch { if (mounted.current) setErrorRevision(revision); }
  finally { sending.current = false; if (mounted.current) { setBusy(false); } }
 }
 return <section className="space-y-4"><p>{t.reviewScope}</p><button className={button} onClick={refresh}>{t.refresh}</button>
  {error && <p role="alert">{t.error}</p>}{!snapshot && !error && <p role="status">{t.loading}</p>}
  {snapshot && <><p role="status">{snapshot.period.locked_at ? t.locked : snapshot.period.reviewed_revision === snapshot.period.revision ? t.reviewed : t.unreviewed}</p>
   {snapshot.period.reviewed_by && <p className="break-all">{snapshot.period.reviewed_by} · {snapshot.period.reviewed_at}</p>}
   <h2 className="font-semibold">{t.assignments}</h2><p>{t.assignmentHint}</p>
   {!snapshot.assignments.length && <p>{t.noAssignments}</p>}
   <ul className="space-y-3">{snapshot.assignments.map(a => <li key={`${a.id}:${a.version}`} className="rounded border p-3"><p><bdi>{a.employee_name} · {a.project_name} · {a.starts_on} — {a.ends_on ?? '…'}</bdi></p>
    <p>{t.days}: {absenceHalfUnits(snapshot.exceptions.filter(e => e.employee_id === a.employee_id && e.project_id === a.project_id && e.absence_date >= a.starts_on && (!a.ends_on || e.absence_date <= a.ends_on))) / 2}</p>
    {role === 'ACCOUNTING_ADMIN' && !snapshot.period.locked_at && <AssignmentForm userId={userId} companyId={companyId} projects={context.projects} employees={context.employees} assignment={a} t={t} onRefresh={refresh} />}
   </li>)}</ul>
   {role === 'ACCOUNTING_ADMIN' && !snapshot.period.locked_at && <AssignmentForm userId={userId} companyId={companyId} projects={context.projects} employees={context.employees} t={t} onRefresh={refresh} />}
   <h2 className="font-semibold">{t.day}</h2>{!snapshot.exceptions.length && <p>{t.noExceptions}</p>}
   <ul className="space-y-2">{snapshot.exceptions.map(e => <li key={e.id} className="rounded border p-3"><p><bdi>{e.employee_name} · {e.project_name} · {e.absence_date}</bdi> · {e.voided ? t.voided : e.kind === 'HALF_DAY' ? t.half : t.full}</p><p>{e.note}</p><p>{e.correction_reason}</p><p className="break-all">{t.recorded}: {e.created_by} · {t.updated}: {e.updated_by}</p></li>)}</ul>
   {!snapshot.period.locked_at && <><label className="flex gap-2"><input type="checkbox" checked={confirmed} onChange={e => setConfirmedRevision(e.target.checked ? revision : null)} />{t.confirm}</label>
    <button className={button} disabled={!confirmed || busy || error} onClick={() => void confirm()}>{t.confirmButton}</button></>}
  </>}
 </section>;
}
function AssignmentForm({ userId, companyId, projects, employees, assignment, t, onRefresh }: {
 userId: string; companyId: string; projects: Named[]; employees: Named[]; assignment?: SiteAssignment; t: AttendanceLabels; onRefresh: () => void;
}) {
 const [busy, setBusy] = useState(false); const [failed, setFailed] = useState(false); const mounted = useRef(true); const sending = useRef(false);
 useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
 async function save(form: HTMLFormElement) {
  if (sending.current || failed) return; const values = new FormData(form); sending.current = true; setBusy(true);
  try { await attendanceRequest(getSupabaseClient(), userId, 'save_employee_site_assignment', {
   target_company_id: companyId, target_employee_id: assignment?.employee_id ?? String(values.get('employee')),
   target_project_id: assignment?.project_id ?? String(values.get('project')), target_starts_on: assignment?.starts_on ?? String(values.get('start')),
   target_ends_on: String(values.get('end')) || null, target_assignment_id: assignment?.id ?? null, target_version: assignment?.version ?? 0,
   target_reason: String(values.get('reason') ?? '') || null,
  }, () => mounted.current); if (mounted.current) onRefresh(); }
  catch { if (mounted.current) setFailed(true); }
  finally { sending.current = false; if (mounted.current) setBusy(false); }
 }
 return <details className="mt-3"><summary>{assignment ? t.endEdit : t.assign}</summary><form className="mt-3" onSubmit={e => { e.preventDefault(); void save(e.currentTarget); }}>
  <fieldset disabled={busy || failed} className="grid gap-3 sm:grid-cols-2">
   {!assignment && <><label>{t.employee}<select className={field} name="employee" required><option value="">{t.select}</option>{employees.map(e => <option key={e.id} value={e.id}>{e.name}</option>)}</select>{!employees.length && <span>{t.noEmployees}</span>}</label>
    <label>{t.project}<select className={field} name="project" required><option value="">{t.select}</option>{projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label><label>{t.start}<input dir="ltr" className={field} type="date" name="start" required /></label></>}
   <label>{t.end}<input dir="ltr" className={field} type="date" name="end" defaultValue={assignment?.ends_on ?? ''} min={assignment?.starts_on} /></label>
   {assignment && <label>{t.reason}<input className={field} name="reason" required maxLength={1000} /></label>}<button className={button}>{assignment ? t.endEdit : t.assign}</button>
  </fieldset>{failed && <><p role="alert">{t.error}</p><button type="button" className={button} onClick={onRefresh}>{t.refresh}</button></>}
 </form></details>;
}
