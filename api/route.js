export default async function handler(req,res){
  res.setHeader('Cache-Control','no-store');
  const from=String(req.query?.from||'');
  const to=String(req.query?.to||'');
  const mode=String(req.query?.mode||'driving');
  const profiles={driving:'driving',walking:'foot',cycling:'bike'};
  if(!profiles[mode])return res.status(400).json({error:'Invalid route mode'});
  const parse=p=>{const a=p.split(',').map(Number);return a.length===2&&a.every(Number.isFinite)&&a[0]>=-180&&a[0]<=180&&a[1]>=-90&&a[1]<=90?a:null};
  const a=parse(from),b=parse(to);
  if(!a||!b)return res.status(400).json({error:'Invalid coordinates'});
  const url='https://router.project-osrm.org/route/v1/'+profiles[mode]+'/'+a.join(',')+';'+b.join(',')+'?overview=full&geometries=geojson&steps=true&alternatives=true';
  try{
    const r=await fetch(url,{headers:{'User-Agent':'TrailNavigatorUSA/1.0 (+https://github.com/Roberevan224/park-locator)'}});
    if(!r.ok)throw new Error('Router unavailable');
    const data=await r.json();
    res.status(200).json(data);
  }catch(e){res.status(502).json({error:'Routing service unavailable'})}
}
