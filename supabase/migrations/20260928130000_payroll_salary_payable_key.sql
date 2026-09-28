-- Separate transaction: PostgreSQL requires a new enum value to commit before use.
alter type public.system_account_key add value 'SALARY_PAYABLE';
