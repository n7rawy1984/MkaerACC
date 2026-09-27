import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../types/database.generated';
export type AbsenceKind = 'HALF_DAY' | 'FULL_DAY';
export interface AttendanceEntry {
 id: string; company_id: string; employee_id: string; project_id: string; absence_date: string;
 kind: AbsenceKind; note: string | null; voided: boolean; version: number;
 created_by: string; created_at: string; updated_by: string; updated_at: string; correction_reason: string | null;
}
export interface Named { id: string; name: string }
export interface AttendanceContext { today: string; projects: Named[]; employees: Named[] }
export interface DaySnapshot { locked: boolean; rows: { employee_id: string; employee_name: string; entry: AttendanceEntry | null }[] }
export interface SiteAssignment {
 id: string; employee_id: string; project_id: string; starts_on: string; ends_on: string | null; version: number;
 employee_name: string; project_name: string;
}
export interface MonthSnapshot {
 period: { revision: number; reviewed_revision: number | null; reviewed_by?: string; reviewed_at?: string; locked_at: string | null };
 assignments: SiteAssignment[];
 exceptions: (AttendanceEntry & { employee_name: string; project_name: string })[];
}
export const attendanceRole = (role: string) => ['FOREMAN', 'ACCOUNTANT', 'ACCOUNTING_ADMIN'].includes(role);
export const attendanceStaff = (role: string) => ['ACCOUNTANT', 'ACCOUNTING_ADMIN'].includes(role);
export const canCorrectAttendance = (role: string, userId: string, entry: AttendanceEntry | null, locked: boolean) =>
 !locked && (role === 'ACCOUNTING_ADMIN' || (role === 'FOREMAN' && (!entry || entry.created_by === userId)));
export function absenceHalfUnits(entries: AttendanceEntry[]): number {
 return entries.reduce((total, entry) => total + (entry.voided ? 0 : entry.kind === 'HALF_DAY' ? 1 : 2), 0);
}
export function validDate(value: string): boolean {
 return /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
}
export function exceptionInput(companyId: string, projectId: string, employeeId: string, date: string, kind: AbsenceKind,
 note: string, entry: AttendanceEntry | null, voided: boolean, reason: string) {
 if (!validDate(date) || !['HALF_DAY', 'FULL_DAY'].includes(kind) || note.trim().length > 1000 || reason.trim().length > 1000 ||
  (entry && !reason.trim()) || (!entry && voided)) throw new Error('Invalid attendance input');
 return { target_company_id: companyId, target_project_id: projectId, target_employee_id: employeeId, target_date: date,
  target_kind: kind, target_note: note.trim() || null, target_version: entry?.version ?? 0, target_void: voided, target_reason: reason.trim() || null };
}
// Auth lifetime is checked before every request. Component scope keys discard old responses.
type AttendanceRPC = 'attendance_context' | 'attendance_day' | 'attendance_month' | 'save_attendance_exception' | 'save_employee_site_assignment' | 'confirm_attendance_review';
type NullableArgs<T> = { [K in keyof T]: K extends 'target_note' | 'target_reason' | 'target_assignment_id' | 'target_ends_on' ? T[K] | null : T[K] };
export async function attendanceRequest<N extends AttendanceRPC>(client: SupabaseClient<Database>, userId: string,
 name: N, args: NullableArgs<Database['public']['Functions'][N]['Args']>, isCurrent: () => boolean = () => true) {
 const { data: session, error: sessionError } = await client.auth.getSession();
 if (!isCurrent() || sessionError || session.session?.user.id !== userId) throw new Error('Attendance session changed');
 const { data, error } = await client.rpc(name, args as Database['public']['Functions'][N]['Args']);
 if (error) throw new Error('Attendance request failed');
 const after = await client.auth.getSession();
 if (!isCurrent() || after.error || after.data.session?.user.id !== userId) throw new Error('Attendance session changed');
 return data;
}
