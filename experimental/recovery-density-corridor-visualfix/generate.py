"""Derive text-only external fixture from the preserved compiled corridor01."""
from pathlib import Path
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-density-corridor-drivers-01'
MANIFEST = '4aea5b4182948f6687e89160b52711d569d9a9e46a8b21ef75ba61b2f81832cf'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


VISUAL_METHODS = '''      // drawAllObjs replaces every layer, but Unit.addVisual immediately
      // returns for disabled actors. Restore the exact native chain order once,
      // then the local player (the same order as Grafon.drawAllObjs). Never
      // attach a MirrorHitUnit: it borrows the actual body's visual. The mine
      // gate is intentionally invisible and must remain so.
      private static function displayUnits(mod:Object,actors:Array):Array {
         var out:Array=[],o:Object=mod.game.loc.firstObj,n:int=0;
         while(o!=null && n++<10000) {
            if(actors.indexOf(o)>=0 || cls(o)=="rconnect.game::RemoteDamageUnit") {
               if(out.indexOf(o)>=0)throw new Error("corridor duplicate display unit");
               out.push(o);
            }
            o=o.nobj;
         }
         if(o!=null)throw new Error("corridor display chain too long");
         for each(o in actors)if(out.indexOf(o)<0)throw new Error("corridor actor left native chain");
         if(out.indexOf(mod.game.gg)<0)out.push(mod.game.gg);
         return out;
      }
      private static function restoreVisuals(mod:Object,actors:Array):void {
         for each(var u:Object in displayUnits(mod,actors)) {
            var wasDisabled:Boolean=Boolean(u.disabled),wasTrigger:Boolean=Boolean(u.trigDis);
            try {u.disabled=false;u.addVisual();}
            finally {u.disabled=wasDisabled;}
            if(Boolean(u.trigDis)!=wasTrigger)throw new Error("corridor addVisual changed native trigger eligibility");
         }
      }
      private static function viewRow(mod:Object,v:DisplayObject,expected:Object,label:String,visible:Boolean,owner:DisplayObject=null):Object {
         var attached:Boolean=v!=null && v.stage===mod.stage && v.parent===expected;
         if(owner!=null)attached=v!=null && v.stage===mod.stage && owner is flash.display.DisplayObjectContainer
            && flash.display.DisplayObjectContainer(owner).contains(v);
         var shown:Boolean=v!=null && v.width>0 && v.height>0,p:DisplayObject=v;
         while(p!=null){shown=shown && p.visible && p.alpha>0;p=p.parent;}
         return {label:label,attached:attached,shown:shown,requiredVisible:visible,
            ok:attached && (!visible || shown),cls:cls(v),parent:v==null?"null":cls(v.parent),
            stage:v!=null && v.stage===mod.stage,visible:v!=null && v.visible,alpha:v==null?0:v.alpha};
      }
      private static function visualStatus(mod:Object,actors:Array):Object {
         var rows:Array=[],bad:Array=[],counts:Object={actors:0,actorWeapons:0,localPlayer:0,remotePlayer:0},
            layers:Object=mod.game.world.grafon.visObjs;
         for each(var u:Object in displayUnits(mod,actors)) {
            var actor:Boolean=actors.indexOf(u)>=0,local:Boolean=u===mod.game.gg;
            var label:String=actor?"actor:"+actors.indexOf(u):(local?"local-player":"remote-player");
            counts[actor?"actors":(local?"localPlayer":"remotePlayer")]++;
            var v:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
            rows.push(viewRow(mod,v,layers[int(u.sloy)],label,true));
            var part:DisplayObject=GameBridge.probe(u,"visBmp") as DisplayObject;
            if(part==null)part=GameBridge.probe(v,"osn") as DisplayObject;
            if(part!=null)rows.push(viewRow(mod,part,null,label+":body-part",true,v));
            var bar:DisplayObject=GameBridge.probe(u,"hpbar") as DisplayObject;
            // Native hidden health bars need correct attachment, not visibility.
            if(bar!=null)rows.push(viewRow(mod,bar,layers[3],label+":health-bar",false));
            if(actor || local) {
               var guns:Array=[],current:Object=GameBridge.probe(u,"currentWeapon"),child:Object;
               if(current!=null)guns.push(current);
               if(u.childObjs is Array)for each(child in u.childObjs)
                  if(child!=null && guns.indexOf(child)<0 && GameBridge.probe(child,"vis")!=null)guns.push(child);
               for each(var gun:Object in guns) {
                  var wv:DisplayObject=GameBridge.probe(gun,"vis") as DisplayObject;
                  rows.push(viewRow(mod,wv,layers[int(gun.sloy)],label+":weapon:"+String(gun.id),true));
                  part=GameBridge.probe(wv,"kor") as DisplayObject;
                  if(part!=null)rows.push(viewRow(mod,part,null,label+":weapon-body",true,wv));
               }
               if(actor && current!=null)counts.actorWeapons++;
            } else {
               // RConnect's real peer weapon is a child of visualPlayer, not
               // a native independent object-layer weapon.
               current=GameBridge.probe(u,"currentWeapon");
               wv=GameBridge.probe(current,"vis") as DisplayObject;
               if(current!=null && wv!=null)rows.push(viewRow(mod,wv,null,label+":peer-weapon",true,v));
            }
         }
         for each(var row:Object in rows)if(!row.ok)bad.push(["visual",row.label,row]);
         if(counts.actors!=80 || counts.actorWeapons!=39 || counts.localPlayer!=1 || counts.remotePlayer!=1)
            bad.push(["visual-counts",counts]);
         return {counts:counts,rows:rows,bad:bad,ok:bad.length==0};
      }
'''


def main():
    assert sha(BASE / 'prepared.json') == MANIFEST
    meta = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
    for path in sorted((BASE / 'tests').rglob('*.as')):
        name = path.relative_to(BASE).as_posix()
        assert sha(path) == meta['files'][name]
        target = HERE / name
        target.parent.mkdir(parents=True, exist_ok=True)
        assert not target.exists(), 'Never overwrite delivered source'
        shutil.copyfile(path, target)
    for name in ('prepare.py', 'run.py', 'audit.py', 'check.py', 'edits.json', 'geometry-proof.json'):
        path = BASE / 'recipe' / name
        assert sha(path) == meta['files']['recipe/' + name]
        assert not (HERE / name).exists()
        shutil.copyfile(path, HERE / name)
    # Explicit AS3 import: qualified flash.display type expressions can be
    # parsed as dynamic property access by this toolchain.
    methods = VISUAL_METHODS.replace('flash.display.DisplayObjectContainer', 'DisplayObjectContainer')
    changes = [
        ('   import flash.display.DisplayObject;', '   import flash.display.DisplayObject;\n   import flash.display.DisplayObjectContainer;'),
        ('mod.game.world.redrawLoc();DensityFixture.place(mod);', 'mod.game.world.redrawLoc();restoreVisuals(mod,actors);DensityFixture.place(mod);'),
        ('      private static function inspectGuns(guns:Array):Array {', methods + '      private static function inspectGuns(guns:Array):Array {'),
        ('         return {ok:applied && bad.length==0,common:{fixture:ID,tileHash:DensityFixture.hash(cells),',
         '         var views:Object=applied?visualStatus(mod,actors):null;\n         if(views!=null)bad=bad.concat(views.bad);\n         return {ok:applied && bad.length==0,visuals:views,common:{fixture:ID,tileHash:DensityFixture.hash(cells),'),
        ('applied:applied,prepareMs:end-start,common:s.common,bad:s.bad,cells:s.cells,removed:removed,geometry:geometry,',
         'applied:applied,prepareMs:end-start,common:s.common,bad:s.bad,cells:s.cells,removed:removed,geometry:geometry,\n            visuals:s.visuals,nativeVisualRestore:true,')]
    target = HERE / 'tests/CorridorFixture.as'
    source = target.read_text(encoding='utf-8-sig')
    for old, new in changes:
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    target.write_text(source, encoding='utf-8', newline='\n')
    (HERE / 'visual-edits.json').write_text(json.dumps(changes, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(dict(derived_from=str(BASE), source_manifest=MANIFEST, compiled=False, air_started=False)))


if __name__ == '__main__':
    main()
