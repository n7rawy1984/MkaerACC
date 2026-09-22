// Isolated browser transport fixture. Never connects to Supabase or uses Auth credentials.
// Actual route shell, list, form, provider, readers and mutation repository are mounted.
import { useSyncExternalStore } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import TenantReadyApplication from '../../src/app/TenantReadyApplication';
import { ProductionMasterDataProvider } from '../../src/master/ProductionMasterDataProvider';
import '/src/index.css';

const audit = { created_at: '2026-09-13T00:00:00.123456+00:00', updated_at: '2026-09-13T00:00:00.123456+00:00', created_by: 'user-a', updated_by: 'user-a' };
const makeParty = (id, type = 'SUPPLIER') => ({ ...audit, id, company_id: 'company-a', type, name: id, code: id, trn: '001234', contact_person: 'Contact', phone: '+001', email: null, address: null, notes: null, status: 'ACTIVE' });
const rows = Array.from({ length: 20 }, (_, i) => makeParty(`Supplier-${i.toString().padStart(2, '0')}`));
rows[0].name='A'.repeat(200);
rows[1].name='ع'.repeat(200);
rows.push(makeParty('Other-row', 'OTHER'));
let serial = 0;
let scope = { userId: 'user-a', companyId: 'company-a', role: 'ACCOUNTING_ADMIN', signedIn: true };
let fault = null;
let gate = null;
let release = null;
const log = [];
const client = {
  auth: { getSession: async () => ({ data: { session: scope.signedIn ? { user: { id: scope.userId } } : null }, error: null }) },
  from(table) {
    let kind = 'read', payload, single = false;
    const filters = [];
    const query = {
      select() { return query; }, order() { return query; },
      maybeSingle() { single = true; return query; },
      eq(key, value) { filters.push([key, value]); return query; },
      insert(value) { kind = 'insert'; payload = value; return query; },
      update(value) { kind = 'update'; payload = value; return query; },
      then(done, failed) { return (async () => {
        log.push({ table, kind, payload, filters: structuredClone(filters) });
        if (gate === kind) { gate = null; await new Promise(resolve => { release = resolve; }); }
        if (fault === kind) { fault = null; return { data: null, error: { code: 'network', message: 'simulated transport failure' } }; }
        if (table === 'companies') return { data: { ...audit, id: filters[0][1], name: filters[0][1], legal_name: null, code: 'COMP', status: 'ACTIVE' }, error: null };
        if (table !== 'parties') return { data: single ? null : [], error: null };
        let matches = rows.filter(row => filters.every(([key, value]) => row[key] === value));
        if (kind === 'insert') {
          const row = { ...makeParty(`Created-${++serial}`), ...payload };
          rows.push(row); matches = [row];
        }
        if (kind === 'update') for (const row of matches) Object.assign(row, payload, { updated_at: `2026-09-14T00:00:00.${String(++serial).padStart(6, '0')}+00:00` });
        return { data: structuredClone(matches), error: null };
      })().then(done, failed); },
    };
    return query;
  },
};
// Test controls are an external store, installed before React renders mocked authority.
const listeners = new Set<() => void>();
const subscribe = (listener: () => void) => { listeners.add(listener); return () => { listeners.delete(listener); }; };
const getSnapshot = () => scope;
window.slice6 = {
  scope: getSnapshot, log, rows,
  change(patch) { scope = { ...scope, ...patch }; listeners.forEach(listener => listener()); },
  fail(kind) { fault = kind; }, hold(kind) { gate = kind; }, release() { release?.(); release = null; },
  concurrentEdit(id) { rows.find(row => row.id === id).updated_at = '2026-09-14T10:00:00.999999+00:00'; },
};
export function App() {
  const current = useSyncExternalStore(subscribe, getSnapshot);
  if (!current.signedIn) return <p>signed-out</p>;
  return <BrowserRouter><ProductionMasterDataProvider key={`${current.userId}:${current.companyId}:${current.role}`} client={client} userId={current.userId} activeCompanyId={current.companyId} role={current.role}>
    <TenantReadyApplication view="parties" />
  </ProductionMasterDataProvider></BrowserRouter>;
}
createRoot(document.getElementById('root')).render(<App />);
