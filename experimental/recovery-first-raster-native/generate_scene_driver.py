"""Keep scene12's original checks/path, add cold03 native keyboard evidence."""
from pathlib import Path
import hashlib,json,re,difflib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/room-travel-driver-12';COLD=ROOT/'build/m52/recovery-cold-travel-driver-03'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def change(s,old,new):assert s.count(old)==1,old[:130];return s.replace(old,new,1)
def put(name,s):
    p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def method(s,name):
    start=re.search(r'^      private function '+name+r'\(',s,re.M).start();opening=s.index('{',start);i=opening+1;depth=1
    while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]
def main():
    m=json.loads((BASE/'prepared.json').read_text(encoding='utf-8-sig'))
    for name,h in m['files'].items():assert sha(BASE/name)==h,name
    cm=json.loads((COLD/'prepared.json').read_text(encoding='utf-8-sig'))
    coldPath=COLD/'tests/ColdFixedTravelTestDoc.as';assert sha(coldPath)==cm['files']['tests/ColdFixedTravelTestDoc.as']
    cold=coldPath.read_text(encoding='utf-8-sig')
    old=s=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8-sig')
    s=change(s,'   import flash.events.MouseEvent;','   import flash.events.MouseEvent;\n   import flash.events.KeyboardEvent;')
    s=change(s,'      private var localResult:Object;', '''      private var localResult:Object;
      private var rasterProbe:FirstRasterSceneProbe,livingPrepared:Boolean=false;
      private var requestedWall:Number=0,keyCode:int=0,inputAt:int=0,inputX:Number=0,inputDirection:int=1;
      private var inputActor:Object,inputCtr:Object,inputEvidence:Object;
      private var baselineAt:int=0,baselineX:Number=0,baselineFrames:int=0;''')
    s=change(s,'private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"travel-timing "+label+" round="+round);}',
        'private function check(ok:Boolean,label:String):Boolean {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"travel-timing "+label+" round="+round);return ok;}')
    s=change(s,'target=String(p.target);begin();','target=String(p.target);begin(Number(p.requestedWall));')
    s=change(s,'if(host && p.op=="ready" && phase=="boot"){depart();return;}',
        'if(host && p.op=="ready" && phase=="boot"){if(livingPrepared)depart();return;}')
    s=change(s,'      private function begin():void {','''      private function begin(wall:Number=0):void {
         requestedWall=wall>0?wall:new Date().time;
         rasterProbe.begin(SceneRasterBuildConfig.REQUIRE_SEED_TICKET && !solo && !host && target=="random_mane");''')
    s=change(s,'         send("depart",{target:target});begin();',
        '         var wall:Number=new Date().time;send("depart",{target:target,requestedWall:wall});begin(wall);')
    s=change(s,'         if(localResult==null || (!solo && peer==null))return;',
        '         if(localResult==null || phase!="wait" || (!solo && peer==null))return;')
    s=change(s,'            Log.d("TRAVEL CONFIG "+JSON.stringify({host:host,solo:solo,merged:merged()}));',
        '            rasterProbe=new FirstRasterSceneProbe(mod);\n            Log.d("TRAVEL CONFIG "+JSON.stringify({host:host,solo:solo,merged:merged()}));')
    s=change(s,'         var w:Object=mod.game.world,now:int=getTimer();mod.game.gg.invulner=true;',
        '         rasterProbe.sample();\n         var w:Object=mod.game.world,now:int=getTimer();mod.game.gg.invulner=true;')
    s=change(s,'         if(phase=="boot" && stable("rbl")) {','''         if(phase=="boot" && stable("rbl")) {
            if(!livingPrepared) {
               livingPrepared=true;var actor:Object=mod.game.gg;
               Log.d("SCENE INPUT BOOT "+JSON.stringify({animOff:actor.animOff,hp:actor.hp,sost:actor.sost,t_die:w.t_die,dead:actor.pers.dead,work:actor.work,t_work:actor.t_work}));
               if(actor.animOff===true&&actor.hp>0&&actor.sost==1&&!actor.pers.dead&&actor.work==""&&actor.t_work<=0)actor.anim();
               if(!check(!actor.animOff&&actor.hp>0&&actor.sost==1&&!actor.pers.dead,"living native source is ready before input measurement")){abort();return;}
            }''')
    s=change(s,'               reported=true;localResult=result();Log.d("TRAVEL RESULT "+JSON.stringify(localResult));\n               check(true,"native travel and input restoration finished");\n               if(host)compare();else {send("result",{value:localResult});phase="wait";at=now;}',
        '               reported=true;localResult=result();startInputCheck();')
    s=change(s,'         }\n      }\n      private function finish():void {','''         }else if(phase=="input-baseline")baselineInput();
         else if(phase=="input") {
            var row:Object=inputSample("input-native-frame");inputEvidence.pressed.push(row);
            if(!row.sameActor||!row.sameCtr||row.keyLeft!==(inputDirection<0)||row.keyRight!==(inputDirection>0)) {
               inputError("native pressed key state or player identity changed before movement");return;
            }
            if((row.x-inputX)*inputDirection>.1&&row.walk==inputDirection&&row.dx*inputDirection>0)completeInput();
            else if(now-inputAt>1000)inputError("native key produced no matching directional movement within original 1000ms window");
         }else if(phase=="input-release")completeRelease();
      }
      private function finish():void {''')
    s=change(s,'if(phase=="done")return;phase="done";removeEventListener(Event.ENTER_FRAME,tick);',
        'if(phase=="done")return;phase="done";releaseKey();if(rasterProbe!=null)rasterProbe.dispose();removeEventListener(Event.ENTER_FRAME,tick);')
    start='''      private function startInputCheck():void {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         localResult.flagsReadyWall=new Date().time;localResult.requestedWall=requestedWall;
         localResult.rasterEvidence=rasterProbe.finish();
         if(!check(localResult.rasterEvidence.passed,"expected production first-raster ticket was observed and really finished")){abort();return;}
'''+method(cold,'startInputCheck').split('         inputDirection=1;',1)[1]
    start=start.replace('\n         if(w.loc.getAbsTile','\n         if(w.loc.getAbsTile',1)
    # Keep the original cold03 stationary/input windows and evidence, with the
    # scene12 result already captured before movement for entrance comparison.
    start=start.replace('         if(w.loc.getAbsTile','         inputDirection=1;\n         if(w.loc.getAbsTile',1)
    helpers=[start]+[method(cold,n).replace('COLD TRAVEL INPUT','SCENE TRAVEL INPUT') for n in
        ('inputSample','inputError','baselineInput','releaseKey','completeInput','completeRelease')]
    helpers[-1]=change(helpers[-1],'         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));',
        '         check(true,"native travel and input restoration finished");\n         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));')
    # The scene12 receiver's original peer result field is named peer, not peerResult.
    helpers.append('      private function abort():void {send("done");finish();}')
    s=change(s,'      private function finish():void {','\n'.join(helpers)+'\n      private function finish():void {')
    put('tests/RoomTravelTimingTestDoc.as',s)
    for name in ('RoomTravelSceneTestDoc.as','A22RoomMetrics.as'):put('tests/'+name,(BASE/'tests'/name).read_text(encoding='utf-8-sig'))
    put('scene-driver.patch',''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='scene12/RoomTravelTimingTestDoc.as',tofile='scene-input/RoomTravelTimingTestDoc.as')))
    put('driver-inputs.json',json.dumps(dict(base_manifest=sha(BASE/'prepared.json'),cold_manifest=sha(COLD/'prepared.json'),
        cold_source_sha256=sha(coldPath),sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))},
        compiled=False,runtime_tested=False,original_scene_checks_retained=True),indent=2)+'\n')
    print('Scene12 path plus cold03 input evidence generated; source only')
if __name__=='__main__':main()
