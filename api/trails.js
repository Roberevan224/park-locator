const ENDPOINTS=['https://overpass-api.de/api/interpreter','https://overpass.kumi.systems/api/interpreter'];
function validBBox(b){
 const a=String(b||'').split(',').map(Number);
 if(a.length!==4||a.some(n=>!Number.isFinite(n)))return null;
 const [south,west,north,east]=a;
 if(south<-90||north>90||west<-180||east>180||south>=north||west>=east)return null;
 if((north-south)*(east-west)>0.16)return null;
 return [south,west,north,east];
}
export default async function handler(req,res){
 try{
  const bbox=validBBox(req.query?.bbox);
  if(!bbox)return res.status(400).json({error:'A smaller map area is required for trail loading.'});
  const [s,w,n,e]=bbox;
  const q='[out:json][timeout:20];way[highway~"^(path|footway|track|bridleway|steps|pedestrian|cycleway)$"]('+s+','+w+','+n+','+e+');out tags geom;';
  for(const endpoint of ENDPOINTS){
   try{
    const r=await fetch(endpoint+'?data='+encodeURIComponent(q),{headers:{Accept:'application/json','User-Agent':'TrailNavigatorUSA/1.0 (+https://github.com/Roberevan224/park-locator)'}});
    if(!r.ok)continue;
    const d=await r.json();
    const features=(d.elements||[]).map(x=>({type:'Feature',properties:{id:x.id,name:x.tags?.name||'Unnamed trail',highway:x.tags?.highway||'trail',surface:x.tags?.surface||'',access:x.tags?.access||''},geometry:{type:'LineString',coordinates:(x.geometry||[]).map(p=>[p.lon,p.lat])}})).filter(f=>f.geometry.coordinates.length>1);
    res.setHeader('Content-Type','application/geo+json');
    res.setHeader('Cache-Control','public,s-maxage=300,stale-while-revalidate=900');
    return res.status(200).json({type:'FeatureCollection',features});
   }catch(e){}
  }
  return res.status(502).json({error:'Trail data service unavailable'});
 }catch(e){return res.status(500).json({error:'Trail request failed'})}
}