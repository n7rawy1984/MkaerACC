// Computed rendered-color measurements; inactive/complex cases are labeled explicitly.
export async function measureText(page){return page.evaluate(()=>{
 const colorCache=new Map(),canvas=document.createElement('canvas');canvas.width=canvas.height=1;const ctx=canvas.getContext('2d',{willReadFrequently:true});
 const rgb=v=>{if(colorCache.has(v))return colorCache.get(v);let value;if(/^rgba?\(/.test(v)){const m=v.match(/[\d.]+/g).map(Number);value=[m[0],m[1],m[2],m[3]??1];}else{ctx.clearRect(0,0,1,1);ctx.fillStyle=v;ctx.fillRect(0,0,1,1);const d=ctx.getImageData(0,0,1,1).data;value=[d[0],d[1],d[2],d[3]/255];}colorCache.set(v,value);return value;};
 const mix=(f,b)=>[f[0]*f[3]+b[0]*(1-f[3]),f[1]*f[3]+b[1]*(1-f[3]),f[2]*f[3]+b[2]*(1-f[3]),1];
 const lum=c=>c.slice(0,3).map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;}).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);
 const ratio=(a,b)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
 const pairs=new Map();let nodes=0;const manual=[];
 for(const el of document.querySelectorAll('body *')){
  if(el.closest('details:not([open])')&&!el.closest('summary'))continue;
  if(![...el.childNodes].some(n=>n.nodeType===Node.TEXT_NODE&&n.textContent.trim()))continue;
  const r=el.getBoundingClientRect(),st=getComputedStyle(el);if(!r.width||!r.height||st.visibility!=='visible'||el.closest('[hidden]'))continue;
  let bg=[255,255,255,1];const stack=[];let a=el,complex=false;
  while(a){const s=getComputedStyle(a);if(Number(s.opacity)<1||s.backgroundImage!=='none')complex=true;stack.unshift(rgb(s.backgroundColor));a=a.parentElement;}
  for(const c of stack)bg=mix(c,bg);
  if(complex){manual.push({selector:el.tagName+'.'+String(el.className).slice(0,90),text:el.textContent.trim().slice(0,55),reason:'opacity/background image'});continue;}
  const fg=mix(rgb(st.color),bg),value=ratio(fg,bg),large=parseFloat(st.fontSize)>=24||(parseFloat(st.fontSize)>=18.6667&&Number(st.fontWeight)>=700),threshold=large?3:4.5;
  const disabled=!!el.closest(':disabled,[aria-disabled=true]'),key=fg.join(',')+'|'+bg.join(',')+'|'+threshold+'|'+disabled;nodes++;
  if(!pairs.has(key))pairs.set(key,{foreground:st.color,background:bg.slice(0,3).map(Math.round),ratio:value,threshold,disabled,pass:value>=threshold,examples:[]});
  const p=pairs.get(key);if(p.examples.length<3)p.examples.push({selector:el.tagName.toLowerCase()+(el.className?'.'+String(el.className).trim().replaceAll(' ','.'):''),text:el.textContent.trim().slice(0,90)});
 }
 return {nodes,pairs:[...pairs.values()],manual,failures:[...pairs.values()].filter(p=>!p.pass&&!p.disabled)};
 });}
export async function probeStates(page){
 const pair=async(selector,kind='text')=>page.locator(selector).first().evaluate((el,kind)=>{
  const rgb=v=>v.match(/[\d.]+/g).slice(0,3).map(Number),l=c=>c.map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;}).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0),ratio=(a,b)=>(Math.max(l(a),l(b))+.05)/(Math.min(l(a),l(b))+.05);
  const s=getComputedStyle(el);let p=kind==='focus'&&parseFloat(s.outlineOffset)>0?el.parentElement:el,bg=getComputedStyle(p).backgroundColor;while(bg==='rgba(0, 0, 0, 0)'&&p.parentElement){p=p.parentElement;bg=getComputedStyle(p).backgroundColor;}
  const fg=kind==='border'?s.borderTopColor:kind==='focus'?s.outlineColor:s.color;return {foreground:fg,background:bg,ratio:ratio(rgb(fg),rgb(bg)),threshold:kind==='text'?4.5:3,outline:s.outlineStyle,outlineWidth:s.outlineWidth};
 },kind);
 const results=[];
 for(const [selector,kind,label] of [['#probe-primary','text','primary default'],['#probe-danger','text','danger default'],['#probe-secondary','text','secondary default'],['#probe-input','border','input boundary'],['#probe-input-error','border','error boundary'],['#probe-warning','text','warning message'],['#probe-error','text','error message'],['#probe-info','text','information message'],['#probe-muted','text','muted copy'],['#probe-nav','text','selected navigation'],['#probe-disabled','text','disabled (voluntary text target)']])results.push({label,...await pair(selector,kind)});
 for(const [selector,label] of [['#probe-primary','primary hover'],['#probe-danger','danger hover'],['#probe-secondary','secondary hover'],['#probe-nav','navigation hover'],['#probe-row','table hover']]){await page.locator(selector).hover();results.push({label,...await pair(selector==='#probe-row'?'#probe-row td':selector)});}
 await page.mouse.move(0,0);await page.keyboard.press('Tab');
 for(const [selector,label] of [['#probe-input','input focus'],['#probe-primary','primary focus'],['#probe-nav','inverse navigation focus']]){await page.locator(selector).focus();const q=await pair(selector,'focus');results.push({label,...q,visible:q.outline!=='none'&&parseFloat(q.outlineWidth)>=3});}
 return results;
}
