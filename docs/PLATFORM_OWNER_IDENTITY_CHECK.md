**Owner correction APPLIED/VERIFIED (2026-10-29):** explicit approved Development transfer complete. Existing ebcf7115 Auth identity is sole ACTIVE PLATFORM_OWNER; old e1ef565b registry retained INACTIVE, epoch advanced. One audit event; all10 Auth/MFA/session/profile/membership/financial preservation checks pass. MFA factors unchanged; target still needs real enrollment/verification before Overview. See [actual execution record](PLATFORM_OWNER_TRANSFER.md). Older pending/old-owner-current statements below are historical; do not reapply the operation.

**Owner intent confirmed; execution approval pending (2026-10-29):** intended existing Auth identity is ebcf7115-6cd9-49be-af25-8e57b5befd75. The guarded single-active-owner transfer is prepared and20 isolated checks pass; no hosted changes. See [exact transfer review](PLATFORM_OWNER_TRANSFER.md). Earlier identity-confirmation pending statements are historical; execution approval remains required.

# Existing owner identity link — targeted read-only check, 2026-10-29

Target verified: MakerACC-Development (`eqnzueginpkskbnqvgoc`), ACTIVE_HEALTHY. Snapshot17:01:31UTC /21:01:31Dubai. No hosted data/privilege/Auth/configuration change. No password reset, account recreation, general audit, backup, migration rehearsal, SMTP test or financial operation.

## Verified existing identities

| Check | Previously approved owner | Account signed in today |
| --- | --- | --- |
| Auth UUID | `e1ef565b-c54d-4b52-bba3-360a03da7aa3` | `ebcf7115-6cd9-49be-af25-8e57b5befd75` |
| Auth creation |8October2026|29October2026,08:43:46UTC|
| Auth/profile ID equality |Yes|Yes|
| Profile ACTIVE |Yes|Yes|
| Confirmed, not banned |Yes|Yes|
| Email-provider identity present |Yes|Yes|
| Profile email matches Auth email |Yes|Yes|
| Registry entry |Same Auth UUID|Absent|
| Registry status/role |ACTIVE / PLATFORM_OWNER|None|
| Registry creation |8October2026,06:11:39UTC|Not applicable|
| Passes owner/profile predicate |Yes|No|
| Successful sign-in recorded |No (`last_sign_in_at` null)|29October2026,16:43:57UTC|
| Current recent session |None|AAL1, not expired|
| Verified TOTP factors |0|0|
| Company membership count |0|0|

These Auth accounts have different email values; no address is printed. The29October account was previously acknowledged as an intentional/approved new identity; that acknowledgment did not grant platform authority. The8October owner is the exact UUID explicitly approved in [the original bootstrap record](DEVELOPMENT_PLATFORM_ADMIN_BOOTSTRAP.md). Account age, inbox possession, successful password recovery and an ACTIVE profile do not select a Platform Owner.

The recorded Auth-to-profile-to-registry link is internally CORRECT. No dangling FK, mismatched profile key, missing platform_role or inactive owner was found. The newer account is also internally linked correctly to its own profile, but it is a different principal without registry authorization. Do not claim that an internally correct registry is automatically the product owner's presently intended identity; intent confirmation is pending.

## Exact rejection condition

Fresh hosted definitions confirm `get_platform_context()` calls `private.platform_actor(false)` before attempting the MFA step-up branch. That function derives actor from `auth.uid()` and evaluates:

```sql
from private.system_administrators a
join public.profiles p on p.user_id=a.user_id
where a.user_id=actor
  and a.status='ACTIVE'
  and a.platform_role='PLATFORM_OWNER'
  and p.status='ACTIVE'
```

No row for the29October UUID means `IF NOT FOUND THEN RAISE EXCEPTION 'Denied' USING ERRCODE='42501'`. The read-only check evaluated this same predicate directly for both UUIDs: true for the8October owner, false for the29October identity. This is before live-session and MFA checks. Missing/stale MFA on an otherwise authorized live owner session produces `step_up_required:true` through the public context RPC; it is not a reason to grant another identity or bypass MFA. Other precise branches remain null actor/malformed session UUID→Denied; missing/revoked live session→Session revoked.

The RPC has authenticated EXECUTE and fixed empty search_path; the private helper is not directly executable by authenticated clients. Existing request evidence records get_platform_context403/42501 Denied. This check did not extract a browser JWT or replay/fabricate authenticated claims; there is no new claim of a browser trace-to-UUID correlation. The only successful sign-in recorded today among inspected principals belongs to the29October account.

## Smallest correction, conditional on owner intent

1. If the8October UUID remains intended: **no hosted privilege correction** is required. Do not recreate/merge/rekey Auth/profile records or rerun bootstrap. Actual owner sign-in and real MFA remain application acceptance, not registry repair.
2. If the product owner designates the existing29October UUID instead: propose a **Development-only authority transfer**, not another active owner. In one guarded protected transaction, retain the old registry row as INACTIVE and register the existing target as ACTIVE/PLATFORM_OWNER, with truthful protected-operator provenance/audit. Preserve Auth IDs, passwords, verified factors, profiles, Company memberships and all financial history. Preserve exactly one active owner and the original registry history. Existing status-epoch trigger must revoke old authority; MFA must remain required on the target.

Before executing case2, obtain explicit confirmation of the intended target UUID and separate approval of the exact transfer. Freshly assert exact project, unchanged source/target registry state, existing confirmed/nonbanned ACTIVE target profile, one active source owner, and unchanged Company membership state. Use the existing platform authorization lock and row locks; abort on drift. Never choose the most recent login as owner automatically, update user IDs, delete/recreate an account, add accounting memberships, or turn off MFA. No executable grant script is supplied/executed before the business identity decision, because the existing link is not technically broken and a transfer changes who owns the platform.

## Verification and status

VERIFIED: targeted hosted identity, FK-key equality, role/status, provider/session/MFA metadata and exact function predicate. Existing bootstrap decision checked. Initial session candidate selection included retained historical sessions; the retained diagnostic was minimized locally to the registered owner and identities used today. No emails, credentials, token material or financial rows retained in the report.

DEFERRED: product-owner confirmation of which existing UUID is intended; any privilege transfer and its exact reviewed SQL/approval; real owner/MFA/Overview acceptance. This report authorizes no hosted change.

NOT APPLICABLE: application code changes, new migrations, accounting behavior, deployments or broad test reruns. Only documentation changes; `git diff --check` is the appropriate local check. No commit/push.

Private safe evidence: `/tmp/narvo-owner-link-check/targeted-summary.json`, `identity-evidence.json` (two relevant principals and function definitions). No recovery artifacts accessed. Product owner was asked which UUID is intended; selecting intent alone is not execution approval.
