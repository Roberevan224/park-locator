const DNR='https://gis.dnr.mo.gov/server/rest/services/parks/Missouri_State_Parks_Boundaries/FeatureServer/4/query';

export default async function handler(req,res){
  const key=process.env.ADMIN_KEY;
  const header=req.headers.authorization||'';
  const auth=header.startsWith('Bearer ') ? header.slice(7) : '';
  if(!key) return res.status(500).json({error:'ADMIN_KEY is not configured'});
  if(auth!==key) return res.status(401).json({error:'Unauthorized'});

  if(req.method==='POST'){
    try{
      const u=new URL(DNR);
      u.search=new URLSearchParams({
        where:'1=1',
        outFields:'OBJECTID',
        returnGeometry:'false',
        f:'json'
      });
      const r=await fetch(u);
      return res.status(r.ok?200:502).json({ok:r.ok});
    }catch(e){
      return res.status(502).json({ok:false,error:'DNR source check failed'});
    }
  }

  return res.status(200).json({ok:true});
}