const ENDPOINTS=['https://overpass-api.de/api/interpreter','https://overpass.kumi.systems/api/interpreter'];
function bbox(v){const a=String(v||'').split(',').map(Number);if(a.length!==4||a.some(n=>!Number.isFinite(n)))return null;const [s,w,n,e]=a;if(s>=n||w>=e||(n-s)*(e-w)>0.16)return null;return a}
export default async function handler(req,res){
 try{
  const b=bbox(req.query?.bbox);
  if(!b)return res.status(400).json({error:'A smaller map area is required.'});
  const [s,w,n,e]=b;
  const q='[out:json][timeout:20];(nwr[leisure~"^(park|nature_reserve)$"]('+s+','+w+','+n+','+e+');nwr[boundary="protected_area"]('+s+','+w+','+n+','+e+'););out center tags;';
  for(const endpoint of ENDPOINTS){
   try{
    const r=await fetch(endpoint+'?data='+encodeURIComponent(q),{headers:{Accept:'application/json','User-Agent':'TrailNavigatorUSA/1.0 (+https://github.com/Roberevan224/park-locator)'}});
    if(!r.ok)continue;
    const d=await r.json();
    const features=(d.elements||[]).map(x=>{const c=x.center||{lat:x.lat,lon:x.lon};return{type:'Feature',properties:{id:x.id,name:x.tags?.name||'Protected area',type:x.tags?.leisure||x.tags?.boundary||'park'},geometry:{type:'Point',coordinates:[c.lon,c.lat]}}}).filter(f=>Number.isFinite(f.geometry.coordinates[0])&&Number.isFinite(f.geometry.coordinates[1]));
    res.setHeader('Content-Type','application/geo+json');res.setHeader('Cache-Control','public,s-maxage=300,stale-while-revalidate=900');return res.status(200).json({type:'FeatureCollection',features});
   }catch(e){}
  }
  return res.status(502).json({error:'Park data service unavailable'});
 }catch(e){return res.status(500).json({error:'Park request failed'})}
}