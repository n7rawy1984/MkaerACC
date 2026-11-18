import{PGlite}from'@electric-sql/pglite';import{pgcrypto}from'@electric-sql/pglite/contrib/pgcrypto';import{readFileSync,writeFileSync}from'node:fs';
const dir='/tmp/narvo-commercial-readiness';
export async function durableCommercialFixture(){const meta=JSON.parse(readFileSync(dir+'/continuation-meta.json','utf8')),db=new PGlite({loadDataDir:new Blob([readFileSync(dir+'/continuation.pglite')]),extensions:{pgcrypto}});await db.waitReady;
const sql=(q,args=[],actor=meta.admin)=>db.transaction(async t=>{await t.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await t.exec('set local role authenticated');return(await t.query(q,args)).rows;});
const call=async(name,args,actor=meta.admin)=>(await sql('select public.'+name+'('+Object.keys(args).map((k,i)=>k+'=>$'+(i+1)).join(',')+')r',Object.values(args),actor))[0].r;
return{...meta,db,sql,call,async save(){writeFileSync(dir+'/continuation-meta.json',JSON.stringify(meta));writeFileSync(dir+'/continuation.pglite',Buffer.from(await(await db.dumpDataDir()).arrayBuffer()));},async close(){await db.close();}};}
