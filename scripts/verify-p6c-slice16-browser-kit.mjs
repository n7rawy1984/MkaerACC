import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const dir=new URL('../docs/verification/p6c-slice16/',import.meta.url);
const names=['README.md','preflight.sql','browser-setup.sql','browser-role.sql','browser-authority.sql','browser-cleanup.sql','verify.sql'];
const files=Object.fromEntries(names.map(name=>[name,readFileSync(new URL(name,dir),'utf8')]));
const setup=files['browser-setup.sql'],cleanup=files['browser-cleanup.sql'];
for(const suffix of ['a1','a2','b1','b2','b3','c1','c2','d1','d2','d3']) {const id=`86200000-0000-4000-8000-0000000000${suffix}`;assert(setup.includes(id),`setup missing ${id}`);assert(cleanup.includes(id),`cleanup missing ${id}`);}
for(const value of ["'ACTIVE'","'CLOSED'",'12345','23456','34567','500','525',"'0001'","'0002'","'0003'"]) {assert(setup.includes(value),`setup missing ${value}`);assert(cleanup.includes(value),`cleanup missing ${value}`);}
assert.equal((setup.match(/set_config\('makeracc\.fixture_user',''/g)||[]).length,1);
for(const name of ['browser-role.sql','browser-authority.sql','browser-cleanup.sql']) assert.equal((files[name].match(/set_config\('makeracc\.fixture_user',''/g)||[]).length,1,`${name} UUID placeholder`);
assert(!Object.values(files).some(text=>/password\s*[:=]/i.test(text)),'kit must contain no password assignment');
assert(setup.includes("'ACTIVE'),('86200000-0000-4000-8000-0000000000c2'") && cleanup.includes("id='86200000-0000-4000-8000-0000000000c2' and status='ACTIVE'"),'Project status manifest mismatch');
console.log('Slice 16 browser kit PASS: seven files, exact UUID manifest, explicit Project/Subcontract statuses and protected economics agree, one UUID placeholder per execution helper, no password assignment.');
