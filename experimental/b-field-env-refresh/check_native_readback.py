"""Read-only semantic seam checks against retained native021 exports."""
from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent;JOB=HERE/'injury-native-sources-02/native-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before=JOB/'host/scripts';after=JOB/'verified/scripts';rows=[]
for p in sorted(before.rglob('*.as')):
 name=p.relative_to(before);q=after/name;a=p.read_text(encoding='utf-8-sig');b=q.read_text(encoding='utf-8-sig')
 old=set(re.findall(r'\brconnect\w*',a));new=set(re.findall(r'\brconnect\w*',b))
 if not old.issubset(new):raise ValueError('Lost B native seam '+str(name)+': '+str(old-new))
 rows.append({'class':name.as_posix(),'base_sha256':sha(p),'readback_sha256':sha(q),'B_symbols':sorted(old)})
def has(path,pattern):
 text=(after/path).read_text(encoding='utf-8-sig')
 if not re.search(pattern,text,re.S):raise ValueError('Readback semantic check failed: '+pattern)
has('fe/unit/Pers.as',r'public function piEvent\(key:String, arg:\* = null\) : \*')
has('fe/unit/Pers.as',r'public function piFactor\(key:String\) : Number')
has('fe/unit/Pers.as',r'rconnectXmlFind\(AllData.d.skill,"id",piXmlKey\)')
has('fe/unit/Pers.as',r'if\(param1 && param1.hasOwnProperty\("piPermanent"\)\)')
has('fe/unit/Pers.as',r'_loc1_.piPermanent = piSaved')
has('fe/weapon/Bullet.as',r'public var piShot:Number = 0')
has('fe/weapon/Weapon.as',r'piShotId = Number\(World.w.pers.piEvent\("shot"\)\).*this.b.piShot = piShotId')
has('fe/unit/UnitPlayer.as',r'Unit.rconnectDeferDamage.*rconnectDamage.*piEvent\("begin".*pers.damage.*pers.bloodDamage.*finally.*piEvent\("end"')
world=(after/'fe/World.as').read_text(encoding='utf-8-sig')
if world.count('this.pers != null && Land.rconnectRoomStep == null')!=2:raise ValueError('B native clock must yield tick and flush')
result={'kind':'pi-native021-readback-seams','passed':True,'class_count':len(rows),'rows':rows,
 'checks':['all original rconnect symbol references retained','typed optional new helper signatures','B E4X helper calls retained','Pers save/load state','Bullet public slot','real damage and deferred B damage ordering','both native PI clock calls yield to B'],
 'compiled_candidate_sha256':sha(JOB/'candidate/pfe.swf'),'runtime_tested':False}
path=HERE/'native-readback-review.json'
with path.open('x',encoding='utf-8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
print(json.dumps({k:v for k,v in result.items() if k!='rows'},ensure_ascii=False,indent=2))
