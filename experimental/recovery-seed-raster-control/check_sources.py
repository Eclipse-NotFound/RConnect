"""Source equality and explicit ticket-evidence counterexamples; no AIR/JVM."""
import ast,copy,hashlib,json,re,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
from generate import BASE,PREVIOUS,REPLACED,REPLACEMENT,method
from control_inputs import audit,host_input,validate_gate_result,HOST
sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 labels=[]
 def check(ok,label):assert ok,label;labels.append(label)
 for p in sorted(HERE.glob('*.py')):ast.parse(p.read_text(encoding='utf-8-sig'));labels.append('Python syntax '+p.name)
 old=(BASE/'src/rconnect/core/RoomSync.as').read_text(encoding='utf-8-sig');off=(HERE/'src/rconnect/core/RoomSync.as').read_text(encoding='utf-8')
 check(off.replace(REPLACEMENT,REPLACED,1)==old,'production is exactly one seed return replacement')
 for n in ('commit','finishFirstRaster','startPreparedMap','cancelSeedRaster','applySeal'):
  check(method(old,n)==method(off,n),'production method unchanged '+n)
 ondir=HERE/'components/on';offdir=HERE/'components/off'
 onfiles={p.relative_to(ondir).as_posix():sha(p) for p in ondir.rglob('*.as')};offfiles={p.relative_to(offdir).as_posix():sha(p) for p in offdir.rglob('*.as')}
 check(set(onfiles)==set(offfiles),'paired component closure is identical')
 check({n for n in onfiles if onfiles[n]!=offfiles[n]}=={'SeedGateCaseMode.as','rconnect/core/RoomSync.as'},'only production method and explicit expectation differ between components')
 oldfixture=(ROOT/'experimental/recovery-seed-first-raster/components/room/NativeTravelRoomChecks.as').read_text(encoding='utf-8-sig')
 fixture=(ondir/'NativeTravelRoomChecks.as').read_text(encoding='utf-8')
 for n in ('run','rasterCases'):check(method(fixture,n)==method(oldfixture,n),'all prior non-seed cases unchanged '+n)
 previous=(PREVIOUS/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8')
 current=(HERE/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8')
 for n in ('stable','result','compare','inputSample','inputError','baselineInput','releaseKey','completeInput','completeRelease'):
  check(method(previous,n)==method(current,n),'native route/input check retained '+n)
 for text in ('phase=="boot"?240000:95000','MAP_SEED:uint=1380142925','dx*dx+dy*dy<=80*80'):
  check(text in current and text in previous,'original limit retained '+text)
 check('SceneRasterBuildConfig' not in current and 'SeedGateNativeIntent.read()' in current,'same driver reads explicit intent rather than compiled mode')
 common=(ROOT/'tools/run_coop_regression.py').read_text(encoding='utf-8-sig');derived=(HERE/'native_runner.py').read_text(encoding='utf-8')
 derived=derived.split('"""Unique AIR',1)[1];derived='"""Unique AIR'+derived
 derived=derived.replace('ROOT = Path(__file__).resolve().parents[2]','ROOT = Path(__file__).resolve().parents[1]',1)
 for text in ("        gate_intent=json.loads((args.effects_driver/'seed-gate-intent.json').read_text(encoding='utf-8'))\n",
  "        assert gate_intent['schema']==1 and type(gate_intent['expectSeedTicket']) is bool and gate_intent['candidateSha']==candidate_hash\n",
  "        shutil.copy2(args.effects_driver/'seed-gate-intent.json',driver_dir/'seed-gate-intent.json')\n",
  "                inputs[role]['seed_gate_intent']=hashlib.sha256((folder/'tests/seed-gate-intent.json').read_bytes()).hexdigest()\n"):
  assert derived.count(text)==1;derived=derived.replace(text,'',1)
 check(derived==common,'removing intent asset copying and root adaptation recovers common runtime exactly')
 audit(BASE,'on');host_input(HOST,installation());labels.append('actual recovery13/FD92 source and 22 installation audit')
 # Offline JSON fixtures exercise only the independent evidence parser. They
 # do not manufacture or qualify native ticket observations.
 cases=[('on-valid',True,None,True),('off-valid',False,None,True),
  ('on-missing',True,'missing',False),('off-extra',False,'extra',False),('on-unpainted',True,'unpainted',False),
  ('off-no-callback',False,'callback',False),('on-wrong-declaration',True,'declaration',False),
  ('on-wrong-intent-hash',True,'hash',False),('off-wrong-expected',False,'expected',False)]
 for name,on,mutation,want in cases:
  path=HERE/'offline-cases'/name;run=path/'run';binding=path/'binding';run.mkdir(parents=True,exist_ok=True);binding.mkdir(exist_ok=True)
  intent={'schema':1,'expectSeedTicket':on,'candidateSha':'1'*64}
  (binding/'seed-gate-intent.json').write_text(json.dumps(intent),encoding='utf-8')
  digest=sha(binding/'seed-gate-intent.json')
  (run/'run.json').write_text(json.dumps({'inputs':{'join':{'seed_gate_intent':'0'*64 if mutation=='hash' else digest}}}),encoding='utf-8')
  declared=copy.deepcopy(intent)
  if mutation=='declaration':declared['expectSeedTicket']=not on
  (run/'join.log').write_text('SEED GATE INTENT '+json.dumps(declared)+'\n',encoding='utf-8')
  rows=[]
  for i in range(3):
   expected=on and i!=1;ticket={'at':1,'initialWaiting':True,'initialUnpainted':True,'firstReleased':2,'firstPainted':3}
   rows.append({'round':i,'target':'rbl' if i==1 else 'random_mane','solo':False,'seedGateIntent':intent,
    'rasterEvidence':{'expected':expected,'callbackAvailable':True,'passed':True,'tickets':[ticket] if expected else []}})
  proof=rows[0]['rasterEvidence']
  if mutation=='missing':proof['tickets']=[]
  elif mutation=='extra':proof['tickets']=[ticket]
  elif mutation=='unpainted':proof['tickets'][0]['firstPainted']=-1
  elif mutation=='callback':proof['callbackAvailable']=False
  elif mutation=='expected':proof['expected']=True
  result={'passed':True,'roles':{'join':{'errors':[],'rows':rows}}};validate_gate_result(result,intent,run,binding)
  check(result['passed']==want,'offline parser counterexample '+name)
 receipt={'kind':'seed-gate-control-static-and-parser','passed':len(labels),'failed':0,'labels':labels,'compiled':False,'air_started':False}
 (HERE/'source-checks.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({k:v for k,v in receipt.items() if k!='labels'}))
if __name__=='__main__':main()
