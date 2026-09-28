const C='trail-usa-v1';
const S=['/','/index.html','/manifest.webmanifest','/logo.svg'];
self.addEventListener('install',e=>e.waitUntil(caches.open(C).then(c=>c.addAll(S)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==C).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{
 if(e.request.method!=='GET')return;
 const u=new URL(e.request.url);
 if(u.origin!==location.origin)return;
 if(u.pathname==='/'||u.pathname==='/index.html'){
  e.respondWith(fetch(e.request,{cache:'no-store'}).then(r=>{caches.open(C).then(c=>c.put(e.request,r.clone()));return r}).catch(()=>caches.match(e.request)));
  return;
 }
 e.respondWith(caches.match(e.request).then(x=>x||fetch(e.request).then(r=>{caches.open(C).then(c=>c.put(e.request,r.clone()));return r})));
});