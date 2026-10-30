import { startPlatformFixtureServer } from './platform-fixture-server.mjs';
const {server,db,base}=await startPlatformFixtureServer(4178);
console.log(`Isolated synthetic NARVO console: ${base}/platform\nFixture MFA code: 123456\nIn-memory data only; no Supabase connection or email. Ctrl+C stops the preview.`);
let closing=false;
const close=async()=>{if(closing)return;closing=true;await server.close();await db.close();process.exit(0);};
process.on('SIGINT',()=>void close());process.on('SIGTERM',()=>void close());
