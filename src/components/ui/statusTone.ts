/** Presentation only: lifecycle labels supplement color; never determines access/readiness. */
export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'pending' | 'neutral';
export function statusTone(status: string): StatusTone {
  if (['COMPLETE','COMPLETED','POSTED','REVIEWED','ACCEPTED','DELIVERED','PAID','ADMIN_ASSIGNED'].includes(status)) return 'success';
  if (['ACTIVE','FULL','TRIAL'].includes(status)) return 'info';
  if (['EXPIRED','LIMITED','UNPAID'].includes(status)) return 'warning';
  if (['FAILED','SUSPENDED','REVOKED'].includes(status)) return 'danger';
  if (['DRAFT','PENDING','PENDING_ADMIN','INCOMPLETE','QUEUED','DELIVERING','SCHEDULED'].includes(status)) return 'pending';
  return 'neutral';
}
