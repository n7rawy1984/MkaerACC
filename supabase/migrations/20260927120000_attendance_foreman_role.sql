-- PostgreSQL requires a committed enum addition before the next migration uses it.
alter type public.company_role add value 'FOREMAN';
