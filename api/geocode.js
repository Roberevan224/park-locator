export default async function handler(req,res){
  res.setHeader('Cache-Control','public, max-age=300, s-maxage=300');
  const q=String(req.query?.q||'').trim();
  if(q.length<3||q.length>200)return res.status(400).json({error:'Invalid search query'});
  try{
    const url='https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&countrycodes=us&addressdetails=1&q='+encodeURIComponent(q);
    const r=await fetch(url,{headers:{
      'User-Agent':'TrailNavigatorUSA/1.0 (+https://github.com/Roberevan224/park-locator)',
      'Accept':'application/json'
    }});
    if(!r.ok)throw new Error('Geocoder unavailable');
    const data=await r.json();
    res.status(200).json({results:(data||[]).map(x=>({
      lat:x.lat,lon:x.lon,display_name:x.display_name,
      type:x.type,category:x.category
    }))});
  }catch(e){res.status(502).json({error:'Geocoder unavailable'})}
}
